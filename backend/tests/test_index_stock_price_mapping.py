import unittest
from datetime import date, datetime
from unittest.mock import patch

from app.routers import index_stock_price_mapping


class IndexStockPriceMappingTests(unittest.TestCase):
    def test_live_spx_price_uses_es_live_quote_minus_matched_cash_basis(self):
        def snapshot_closes(observation_date, close_dates):
            close_dates.update({"SPX": "2026-11-03", "ESMain": "2026-11-03"})
            return {"SPX": 7700.0, "ESMain": 7725.0}

        with patch.object(index_stock_price_mapping, "get_live_futures_prices", return_value={"ES": {"price": 7740.0, "source": "ib_live"}}) as futures, patch.object(
            index_stock_price_mapping, "_load_latest_snapshot_date", return_value=date(2026, 11, 3)
        ), patch.object(index_stock_price_mapping, "_load_snapshot_closes", side_effect=snapshot_closes):
            response = index_stock_price_mapping.get_stock_map_live_price("SPX", username="test-user")

        self.assertEqual(response["live_price"], 7715.0)
        self.assertEqual(response["es_live_price"], 7740.0)
        self.assertEqual(response["es_spx_basis"], 25.0)
        self.assertEqual(response["basis_date"], "2026-11-03")
        futures.assert_called_once_with(
            ["ES"], wait_seconds=5.0, connect_timeout=3.0, quote_only=True,
        )

    def test_live_derived_instrument_uses_shared_market_aware_price_service(self):
        from app.services.market_aware_stock_price_service import StockPriceSnapshot

        snapshot = StockPriceSnapshot(
            prices={"SOXX": 210.5}, price_sources={"SOXX": "database_30m"},
            price_times={"SOXX": "2026-11-06T19:30:00"}, market_mode="weekend_30m",
            exchange=None, fetched_at_utc="2026-11-07T12:00:00+00:00",
        )
        with patch.object(index_stock_price_mapping.market_aware_stock_prices, "get_prices", return_value=snapshot) as quote:
            response = index_stock_price_mapping.get_stock_map_live_price("SOXX_D", username="test-user")

        self.assertEqual(response["live_price"], 210.5)
        self.assertEqual(response["source"], "database_30m")
        self.assertEqual(response["price_time"], "2026-11-06T19:30:00")
        quote.assert_called_once_with(["SOXX"], wait_seconds=5.0, connect_timeout=3.0)

    def test_load_latest_closes_returns_prices_without_requiring_model_close(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query = query
                self.params = params
                return [
                    {"ASXCode": "SPY.US", "Close": 600.25},
                    {"ASXCode": "MES.US", "Close": 6001.5},
                ]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(index_stock_price_mapping, "get_live_futures_closes", return_value={}):
            closes = index_stock_price_mapping._load_latest_closes()

        self.assertEqual(closes, {"SPY": 600.25, "MES": 6001.5})

    def test_mapped_live_prices_skips_individual_retries_after_batch_failure(self):
        with patch.object(index_stock_price_mapping, "get_live_index_price", return_value=None), patch.object(
            index_stock_price_mapping,
            "get_live_stock_prices",
            side_effect=RuntimeError("IB unavailable"),
        ) as stock_prices, patch.object(
            index_stock_price_mapping,
            "get_live_futures_closes",
            return_value={},
        ):
            live_prices = index_stock_price_mapping._load_mapped_live_prices()

        self.assertEqual(live_prices, {})
        stock_prices.assert_called_once_with(
            ["SPY", "QQQ", "SPXL", "TQQQ"],
            connect_timeout=index_stock_price_mapping.LIVE_CONNECT_TIMEOUT_SECONDS,
        )

    def test_spx_map_prices_without_date_uses_latest_snapshot_date(self):
        class FakeModel:
            def execute_read_query(self, query, values):
                if "MAX(ObservationDate)" in query:
                    return [{"ObservationDate": date(2026, 9, 15)}]
                return []

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping, "_load_mapped_live_prices", return_value={}
        ):
            response = index_stock_price_mapping.get_spx_map_prices(
                observation_date=None,
                username="test-user",
            )

        self.assertEqual(response["historical_close_date"], date(2026, 9, 15))

    def test_snapshot_closes_use_matched_30m_spx_es_cash_close_bars(self):
        calls = []

        class FakeModel:
            def execute_read_query(self, query, params):
                calls.append((query, params))
                return []

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()):
            self.assertEqual(index_stock_price_mapping._load_snapshot_closes(date(2026, 10, 20)), {})
        self.assertEqual(len(calls), 7)
        by_code = {params[1]: params for _, params in calls}
        self.assertEqual(by_code["SPXW.US"], ("30M", "SPXW.US", "2026-10-06", "2026-10-20", "14:30:00"))
        self.assertEqual(by_code["ESMain.US"], ("30M", "ESMain.US", "2026-10-06", "2026-10-20", "15:30:00"))
        self.assertEqual(by_code["NQMain.US"][0], "5M")
        for query, params in calls:
            self.assertIn("TimeFrame = CONVERT(varchar(10), ?)", query)
            self.assertIn("TimeIntervalStart >=", query)
            self.assertIn("TimeIntervalStart <", query)
            self.assertIn("ORDER BY TimeIntervalStart DESC", query)
            self.assertEqual(params[-3], "2026-10-06")
            self.assertEqual(params[-2], "2026-10-20")
            self.assertIn(params[-1], {"14:30:00", "15:30:00", "15:55:00"})

    def test_report_asof_before_cash_close_uses_previous_session_close_anchors(self):
        captured = {}
        def closes(anchor_date, close_dates, close_times=None):
            captured["anchor_date"] = anchor_date
            close_dates.update({symbol: "2026-10-29" for symbol in ("SPX", "SPY", "ESMain")})
            return {"SPX": 7700.0, "SPY": 770.0, "ESMain": 7720.0}

        with patch.object(index_stock_price_mapping, "_load_snapshot_closes", side_effect=closes), patch.object(
            index_stock_price_mapping, "_load_latest_snapshot_date", return_value=date(2026, 10, 30)
        ), patch.object(index_stock_price_mapping, "_load_effective_spx_prices", return_value={
            "effective_prices": {"SPX": 7644.2, "SPY": 762.03, "ESMain": 7676.0},
            "effective_price_source": "as-of history", "effective_price_timestamp": "2026-10-30T06:00:00",
        }):
            response = index_stock_price_mapping.get_spx_map_prices(
                observation_date=date(2026, 10, 30),
                as_of_et=datetime.fromisoformat("2026-10-30T06:05:00-04:00"),
                username="test-user",
            )

        self.assertEqual(captured["anchor_date"], date(2026, 10, 29))
        self.assertEqual(response["historical_close_date"], date(2026, 10, 29))

    def test_effective_market_bar_prefers_only_completed_five_minute_bar(self):
        as_of = datetime.fromisoformat("2026-11-11T03:25:00-05:00")
        with patch.object(index_stock_price_mapping, "_load_effective_intraday_bar", return_value={"timeframe": "5M"}) as load_bar:
            selected = index_stock_price_mapping._load_effective_market_bar(as_of, "ESMain.US")
        self.assertEqual(selected["timeframe"], "5M")
        load_bar.assert_called_once_with(as_of, "ESMain.US", "5M")

    def test_effective_intraday_bar_uses_last_fully_closed_bar_not_future_start(self):
        captured = {}

        class FakeModel:
            def execute_read_query(self, query, params):
                captured["query"] = query
                captured["params"] = params
                return [{"Open": 7720.0, "High": 7722.0, "Low": 7719.0, "Price": 7721.5,
                         "TimeIntervalStart": datetime(2026, 11, 11, 3, 20), "BarCloseTime": datetime(2026, 11, 11, 3, 25)}]

        as_of = datetime.fromisoformat("2026-11-11T03:25:00-05:00")
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 0
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(as_of, "ESMain.US", "5M")

        self.assertEqual(bar["price"], 7721.5)
        self.assertEqual(bar["raw_time_interval_start"], "2026-11-11T03:20:00")
        self.assertEqual(bar["bar_end_et"], "2026-11-11T03:25:00-05:00")
        self.assertFalse(bar["point_in_time_availability_validated"])
        self.assertEqual(captured["params"], (5, "ESMain.US", "5M", date(2026, 11, 11), 5, datetime(2026, 11, 11, 3, 25)))
        self.assertIn("TimeIntervalStart <= DATEADD(minute, -?, CONVERT(datetime, ?))", captured["query"])
        self.assertIn("TOP (1000)", captured["query"])

    def test_trusted_ingestion_timestamp_after_asof_rejects_completed_bar(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self_query = query
                self.self_query = self_query
                return [
                    {"Open": 7722.0, "High": 7724.0, "Low": 7721.0, "Price": 7723.0,
                     "TimeIntervalStart": datetime(2026, 11, 11, 3, 20), "IngestedAtUtc": datetime(2026, 11, 11, 8, 25, 10)},
                    {"Open": 7719.0, "High": 7721.0, "Low": 7718.0, "Price": 7720.0,
                     "TimeIntervalStart": datetime(2026, 11, 11, 3, 15), "IngestedAtUtc": datetime(2026, 11, 11, 8, 20)},
                ]

        model = FakeModel()
        as_of = datetime.fromisoformat("2026-11-11T03:25:00-05:00")
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=model), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 0
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(as_of, "ESMain.US", "5M")

        self.assertEqual(bar["raw_time_interval_start"], "2026-11-11T03:15:00")
        self.assertTrue(bar["point_in_time_availability_validated"])
        self.assertEqual(bar["source_available_at_et"], "2026-11-11T03:20:00-05:00")
        self.assertEqual(bar["source_available_at_field"], "IngestedAtUtc")
        self.assertIn("p.*", model.self_query)

    def test_trusted_available_at_at_asof_allows_exact_boundary_bar_despite_grace(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                return [{"Open": 7722.0, "High": 7724.0, "Low": 7721.0, "Close": 7723.0,
                         "TimeIntervalStart": datetime(2026, 11, 11, 3, 20),
                         "AvailableAtUtc": datetime(2026, 11, 11, 8, 25)}]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 30
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(
                datetime.fromisoformat("2026-11-11T03:25:00-05:00"), "ESMain.US", "5M"
            )
        self.assertEqual(bar["raw_time_interval_start"], "2026-11-11T03:20:00")
        self.assertTrue(bar["point_in_time_availability_validated"])

    def test_d2_0505_et_accepts_only_the_0500_five_minute_candle_when_delay_is_zero(self):
        captured = {}
        class FakeModel:
            def execute_read_query(self, query, params):
                captured["params"] = params
                return [{"Open": 7722.0, "High": 7724.0, "Low": 7721.0, "Price": 7723.0,
                         "TimeIntervalStart": datetime(2026, 11, 10, 5, 0)}]

        as_of = datetime.fromisoformat("2026-11-10T05:05:00-05:00")
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 0
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(as_of, "ESMain.US", "5M")

        self.assertEqual(bar["corrected_bar_start_et"], "2026-11-10T05:00:00-05:00")
        self.assertEqual(bar["bar_end_et"], "2026-11-10T05:05:00-05:00")
        self.assertEqual(captured["params"][-1], datetime(2026, 11, 10, 5, 5))

    def test_effective_intraday_bar_skips_invalid_latest_ohlc_and_uses_prior_completed_bar(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                return [
                    {"Open": 7722.0, "High": 7721.0, "Low": 7720.0, "Close": 7720.5,
                     "TimeIntervalStart": datetime(2026, 11, 11, 3, 20)},
                    {"Open": 7718.0, "High": 7720.0, "Low": 7717.0, "Close": 7719.0,
                     "TimeIntervalStart": datetime(2026, 11, 11, 3, 15)},
                ]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 0
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(
                datetime.fromisoformat("2026-11-11T03:25:00-05:00"), "ESMain.US", "5M"
            )
        self.assertEqual(bar["raw_time_interval_start"], "2026-11-11T03:15:00")
        self.assertEqual(bar["price"], 7719.0)

    def test_effective_intraday_bar_normalizes_eastern_daylight_time(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                return [{"Open": 7720.0, "High": 7722.0, "Low": 7719.0, "Close": 7721.5,
                         "TimeIntervalStart": datetime(2026, 7, 6, 3, 20)}]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 0
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(
                datetime.fromisoformat("2026-07-06T03:25:00-04:00"), "ESMain.US", "5M"
            )
        self.assertEqual(bar["corrected_bar_start_et"], "2026-07-06T03:20:00-04:00")
        self.assertEqual(bar["bar_end_et"], "2026-07-06T03:25:00-04:00")

    def test_effective_intraday_bar_applies_configured_finalization_delay_and_skips_bad_ohlc(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                return [
                    {"Open": 7722.0, "High": 7721.0, "Low": 7720.0, "Price": 7720.5,
                     "TimeIntervalStart": datetime(2026, 11, 11, 3, 20)},
                    {"Open": 7718.0, "High": 7720.0, "Low": 7717.0, "Price": 7719.0,
                     "TimeIntervalStart": datetime(2026, 11, 11, 3, 15)},
                ]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping.settings, "spx_effective_bar_finalization_delay_seconds", 30
        ):
            bar = index_stock_price_mapping._load_effective_intraday_bar(
                datetime.fromisoformat("2026-11-11T03:25:00-05:00"), "ESMain.US", "5M"
            )

        self.assertEqual(bar["raw_time_interval_start"], "2026-11-11T03:15:00")
        self.assertEqual(bar["bar_end_et"], "2026-11-11T03:20:00-05:00")
        self.assertEqual(bar["finalization_delay_seconds"], 30)
        self.assertFalse(bar["point_in_time_availability_validated"])

    def test_stock_map_prices_returns_daily_close_before_report_asof(self):
        captured = {}
        class FakeModel:
            def execute_read_query(self, query, params):
                captured["query"] = query
                captured["params"] = params
                return [{"ASXCode": "QQQ.US", "LastClose": 690.49, "LastCloseObservationDate": date(2026, 10, 30)}]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping, "_load_stock_atr_14d", return_value=10.0
        ) as atr, patch.object(index_stock_price_mapping, "get_live_stock_prices", return_value={"QQQ": {"price": 696.37, "source": "ib_live"}}):
            result = index_stock_price_mapping.get_stock_map_prices(
                stock_code="QQQ", observation_date=date(2026, 11, 2),
                as_of_et=datetime.fromisoformat("2026-11-02T02:25:00-05:00"), username="test-user",
            )

        self.assertIn("StockData].[PriceHistory]", captured["query"])
        self.assertEqual(captured["params"][-1], "2026-10-30")
        self.assertEqual(result["last_close"], 690.49)
        self.assertEqual(result["last_close_source"], "last_completed_daily_close")
        self.assertEqual(result["last_close_observation_date"], "2026-10-30")
        self.assertEqual(result["live_price"], 696.37)
        atr.assert_called_once()
        self.assertEqual(atr.call_args.args[2], date(2026, 10, 30))

    def test_stock_map_prior_close_cutoff_uses_last_completed_session_at_report_asof(self):
        cutoff = index_stock_price_mapping._stock_map_prior_close_cutoff(
            date(2026, 11, 2), datetime.fromisoformat("2026-11-02T02:25:00-05:00")
        )
        self.assertEqual(cutoff, date(2026, 10, 30))
        self.assertEqual(
            index_stock_price_mapping._stock_map_prior_close_cutoff(
                date(2026, 10, 29), datetime.fromisoformat("2026-11-02T02:25:00-05:00")
            ),
            date(2026, 10, 30),
        )
        self.assertEqual(
            index_stock_price_mapping._stock_map_prior_close_cutoff(
                date(2026, 10, 30), datetime.fromisoformat("2026-10-30T16:10:00-04:00")
            ),
            date(2026, 10, 30),
        )
        self.assertEqual(index_stock_price_mapping._stock_map_prior_close_cutoff(date(2026, 11, 2), None), date(2026, 10, 30))

    def test_effective_spx_prices_translate_es_price_with_cash_basis(self):
        bars = {
            ("ESMain.US", "5M"): {"price": 7721.5, "bar_close_at": datetime(2026, 10, 30, 21, 0), "timestamp": datetime(2026, 10, 30, 20, 55)},
            ("SPY.US", "5M"): {"price": 769.0, "bar_close_at": datetime(2026, 10, 30, 21, 0), "timestamp": datetime(2026, 10, 30, 20, 55)},
        }
        with patch.object(index_stock_price_mapping, "_load_effective_intraday_bar", side_effect=lambda _as_of, symbol, timeframe: bars.get((symbol, timeframe))):
            result = index_stock_price_mapping._load_effective_spx_prices(
                datetime.fromisoformat("2026-10-30T21:20:00-04:00"),
                {"SPX": 7700.0, "ESMain": 7720.0, "SPY": 770.0},
                {"SPX": "2026-10-30", "ESMain": "2026-10-30", "SPY": "2026-10-30"},
            )

        self.assertEqual(result["effective_prices"], {"SPX": 7701.5, "SPY": 770.15, "ESMain": 7721.5, "QQQ": None, "TQQQ": None, "NQMain": None, "SPXL": None, "SOXL": None, "SOXX": None})
        self.assertFalse(result["effective_price_fallback"])

    def test_effective_spx_prices_include_same_as_of_qqq_tqqq_and_esmain_prices(self):
        as_of = datetime.fromisoformat("2026-10-30T21:20:00-04:00")
        expected_bar = {"bar_close_at": datetime(2026, 10, 30, 21, 0), "timestamp": datetime(2026, 10, 30, 20, 30)}
        bars = {
            ("ESMain.US", "5M"): {**expected_bar, "price": 7676.0},
            ("SPY.US", "5M"): {**expected_bar, "price": 762.03},
            ("QQQ.US", "5M"): {**expected_bar, "price": 720.5},
            ("TQQQ.US", "5M"): {**expected_bar, "price": 58.25},
            ("NQMain.US", "5M"): {**expected_bar, "price": 30001.25},
            ("SPXL.US", "5M"): {**expected_bar, "price": 283.2},
            ("SOXL.US", "5M"): {**expected_bar, "price": 34.5},
            ("SOXX.US", "5M"): {**expected_bar, "price": 214.2},
        }
        calls = []

        def load_bar(timestamp, symbol, timeframe):
            calls.append((timestamp, symbol, timeframe))
            return bars.get((symbol, timeframe))

        with patch.object(index_stock_price_mapping, "_load_effective_intraday_bar", side_effect=load_bar):
            result = index_stock_price_mapping._load_effective_spx_prices(
                as_of,
                {"SPX": 7644.2, "SPY": 762.03, "ESMain": 7676.0},
                {"SPX": "2026-10-30", "SPY": "2026-10-30", "ESMain": "2026-10-30"},
            )

        self.assertEqual(result["effective_prices"]["QQQ"], 720.5)
        self.assertEqual(result["effective_prices"]["TQQQ"], 58.25)
        self.assertEqual(result["effective_prices"]["NQMain"], 30001.25)
        self.assertEqual(result["effective_prices"]["SPXL"], 283.2)
        self.assertEqual(result["effective_prices"]["SOXL"], 34.5)
        self.assertEqual(result["effective_prices"]["SOXX"], 214.2)
        for symbol in ("QQQ.US", "TQQQ.US", "NQMain.US", "SPXL.US", "SOXL.US", "SOXX.US"):
            self.assertTrue(any(call[1] == symbol for call in calls))

    def test_effective_price_translation_refuses_mismatched_close_dates(self):
        with patch.object(index_stock_price_mapping, "_load_effective_intraday_bar", return_value={"price": 7721.5, "timestamp": datetime(2026, 10, 30, 20, 30), "bar_close_at": datetime(2026, 10, 30, 21, 0), "timeframe": "30M"}):
            result = index_stock_price_mapping._load_effective_spx_prices(
                datetime.fromisoformat("2026-10-30T21:20:00-04:00"),
                {"SPX": 7700.0, "ESMain": 7720.0, "SPY": 770.0},
                {"SPX": "2026-10-30", "ESMain": "2026-10-29", "SPY": "2026-10-29"},
            )

        self.assertIsNone(result["effective_prices"]["SPX"])
        self.assertEqual(result["effective_prices"]["SPY"], 7721.5)

    def test_effective_spy_fallback_derives_spx_when_es_bar_is_missing(self):
        spy_bar = {"price": 771.0, "timeframe": "5M", "bar_close_at": datetime(2026, 10, 30, 21, 0), "timestamp": datetime(2026, 10, 30, 20, 55)}
        def load_bar(_as_of, symbol, timeframe):
            return spy_bar if symbol == "SPY.US" and timeframe == "5M" else None

        with patch.object(index_stock_price_mapping, "_load_effective_intraday_bar", side_effect=load_bar):
            result = index_stock_price_mapping._load_effective_spx_prices(
                datetime.fromisoformat("2026-10-30T21:20:00-04:00"),
                {"SPX": 7700.0, "ESMain": 7720.0, "SPY": 770.0},
                {"SPX": "2026-10-30", "ESMain": "2026-10-30", "SPY": "2026-10-30"},
            )

        self.assertEqual(result["effective_prices"], {"SPX": 7710.0, "SPY": 771.0, "ESMain": None, "QQQ": None, "TQQQ": None, "NQMain": None, "SPXL": None, "SOXL": None, "SOXX": None})
        self.assertTrue(result["effective_price_fallback"])

    def test_snapshot_tracks_each_close_date_for_live_ratio_safety(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                if params[1] == "NQMain.US":
                    return [{"Close": 25000, "ObservationDate": date(2026, 10, 19)}]
                if params[1] == "SPY.US":
                    return [{"Close": 700, "ObservationDate": date(2026, 10, 20)}]
                return []

        dates = {}
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()):
            closes = index_stock_price_mapping._load_snapshot_closes(date(2026, 10, 20), dates)
        self.assertEqual(closes, {"SPY": 700, "NQMain": 25000})
        self.assertEqual(dates, {"SPY": "2026-10-20", "NQMain": "2026-10-19"})

    def test_dated_spx_mapping_does_not_wait_for_optional_live_ib(self):
        historical = {"SPX": 7655.0, "SPY": 765.5, "ESMain": 7670.0}
        def closes(_date, close_dates, close_times=None):
            close_dates.update({symbol: "2026-10-20" for symbol in historical})
            return historical
        with patch.object(index_stock_price_mapping, "_load_snapshot_closes", side_effect=closes), patch.object(
            index_stock_price_mapping, "_load_latest_snapshot_date", return_value=date(2026, 10, 21)
        ), patch.object(index_stock_price_mapping, "_load_mapped_live_prices", side_effect=RuntimeError("IB sync stalled")) as live:
            response = index_stock_price_mapping.get_spx_map_prices(
                observation_date=date(2026, 10, 20), username="test-user"
            )
        self.assertEqual(response["historical_close_date"], date(2026, 10, 20))
        self.assertFalse(response["calibration_eligible"])
        self.assertEqual(response["historical_closes"], historical)
        self.assertEqual(response["price_differences"], {"SPY": -6889.5, "ESMain": 15.0})
        self.assertEqual(response["live_prices"], {})
        live.assert_not_called()

    def test_es_basis_unavailable_when_es_close_is_from_different_session(self):
        def closes(_date, close_dates, close_times=None):
            close_dates.update({"SPX": "2026-10-20", "ESMain": "2026-10-19"})
            return {"SPX": 7655.0, "ESMain": 7670.0}
        with patch.object(index_stock_price_mapping, "_load_snapshot_closes", side_effect=closes), patch.object(
            index_stock_price_mapping, "_load_latest_snapshot_date", return_value=date(2026, 10, 20)
        ):
            response = index_stock_price_mapping.get_spx_map_prices(date(2026, 10, 20), username="test-user")
        self.assertNotIn("ESMain", response["price_differences"])
        self.assertEqual(response["historical_close_dates"]["ESMain"], "2026-10-19")

    def test_spx_map_prices_endpoint_accepts_report_as_of_and_returns_effective_proxy(self):
        from fastapi.testclient import TestClient
        from app.main import app

        app.dependency_overrides[index_stock_price_mapping.verify_credentials] = lambda: "test-user"
        effective = {
            "effective_prices": {"SPX": 7701.5, "SPY": 770.15, "ESMain": 7721.5},
            "effective_price_source": "ESMain completed 5M bar",
            "effective_price_timestamp": "2026-10-30T21:00:00",
            "effective_price_bar_start": "2026-10-30T20:30:00",
            "effective_price_basis": 20.0,
            "effective_price_fallback": False,
        }
        try:
            with patch.object(index_stock_price_mapping, "_load_snapshot_closes", return_value={"SPX": 7700.0, "SPY": 770.0, "ESMain": 7720.0}), patch.object(
                index_stock_price_mapping, "_load_latest_snapshot_date", return_value=date(2026, 10, 30)
            ), patch.object(index_stock_price_mapping, "_load_effective_spx_prices", return_value=effective) as proxy:
                response = TestClient(app).get("/api/spx-map-prices?observation_date=2026-10-30&as_of_et=2026-10-30T21:20:00-04:00")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["effective_prices"], effective["effective_prices"])
            self.assertEqual(response.json()["report_as_of_et"], "2026-10-30T21:20:00-04:00")
            proxy.assert_called_once()
        finally:
            app.dependency_overrides.pop(index_stock_price_mapping.verify_credentials, None)

    def test_dated_spx_prices_http_response_survives_unavailable_ib(self):
        from fastapi.testclient import TestClient
        from app.main import app

        app.dependency_overrides[index_stock_price_mapping.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(index_stock_price_mapping, "_load_snapshot_closes", return_value={"SPX": 7691.92}), patch.object(
                index_stock_price_mapping, "_load_latest_snapshot_date", return_value=date(2026, 10, 20)
            ), patch.object(index_stock_price_mapping, "_load_mapped_live_prices", side_effect=RuntimeError("IB unavailable")) as live:
                response = TestClient(app).get("/api/spx-map-prices?observation_date=2026-10-20")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["historical_closes"], {"SPX": 7691.92})
            self.assertEqual(response.json()["live_prices_status"], "not_requested_for_historical_mapping")
            self.assertTrue(response.json()["calibration_eligible"])
            live.assert_not_called()
        finally:
            app.dependency_overrides.pop(index_stock_price_mapping.verify_credentials, None)

    def test_spx_live_quotes_are_separate_from_historical_mapping(self):
        from fastapi.testclient import TestClient
        from app.main import app

        app.dependency_overrides[index_stock_price_mapping.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(
                index_stock_price_mapping,
                "get_live_stock_prices",
                return_value={
                    "SPY": {"price": 770.25, "source": "ib_live"},
                    "QQQ": {"price": 720.5, "source": "ib_delayed"},
                },
            ) as quotes, patch.object(
                index_stock_price_mapping, "_load_snapshot_closes", side_effect=AssertionError("historical lookup must be separate")
            ):
                response = TestClient(app).get("/api/spx-map-live-prices")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["live_prices"], {"SPY": 770.25, "QQQ": 720.5})
            self.assertEqual(response.json()["sources"], {"SPY": "ib_live", "QQQ": "ib_delayed"})
            self.assertEqual(response.json()["status"], "partial")
            quotes.assert_called_once_with(
                ["SPY", "QQQ", "SPXL", "TQQQ"],
                wait_seconds=2.0,
                connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
                allow_close_fallback=False,
                quote_only=True,
            )
        finally:
            app.dependency_overrides.pop(index_stock_price_mapping.verify_credentials, None)

    def test_spx_live_quotes_do_not_mislabel_ib_prior_close_as_live(self):
        from types import SimpleNamespace
        from app.services.live_stock_price_service import _ticker_price

        prior_close_only = SimpleNamespace(last=None, bid=None, ask=None, close=769.1)
        self.assertEqual(_ticker_price(prior_close_only), 769.1)
        self.assertIsNone(_ticker_price(prior_close_only, allow_close_fallback=False))

    def test_spx_live_futures_are_a_separate_ib_request(self):
        from fastapi.testclient import TestClient
        from app.main import app

        app.dependency_overrides[index_stock_price_mapping.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(
                index_stock_price_mapping, "get_live_futures_prices",
                return_value={"ES": {"price": 7760.25, "source": "ib_delayed"}, "NQ": {"price": 25700, "source": "ib_delayed"}},
            ) as quotes:
                response = TestClient(app).get("/api/spx-map-live-futures")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["live_prices"], {"ESMain": 7760.25, "NQMain": 25700})
            self.assertEqual(response.json()["sources"], {"ESMain": "ib_delayed", "NQMain": "ib_delayed"})
            quotes.assert_called_once_with(
                ["ES", "NQ"], wait_seconds=2.0,
                connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
                quote_only=True,
            )
        finally:
            app.dependency_overrides.pop(index_stock_price_mapping.verify_credentials, None)

    def test_partial_nq_futures_response(self):
        with patch.object(index_stock_price_mapping, "get_live_futures_prices", return_value={"NQ": {"price": 25700, "source": "ib_live"}}):
            response = index_stock_price_mapping.get_spx_map_live_futures(username="test-user")
        self.assertEqual(response["status"], "partial")
        self.assertEqual(response["live_prices"], {"NQMain": 25700.0})

    def test_stock_map_live_prices_route_uses_shared_market_aware_price_service(self):
        from app.services.market_aware_stock_price_service import StockPriceSnapshot

        payload = index_stock_price_mapping.StockMapLivePricesRequest(symbols=["SPY"])
        snapshot = StockPriceSnapshot(
            prices={"SPY": 700.25}, price_sources={"SPY": "database_30m"},
            price_times={"SPY": "2026-01-02T15:30:00"}, market_mode="weekend_30m",
            exchange=None, fetched_at_utc="2026-01-03T12:00:00+00:00",
        )
        with patch.object(index_stock_price_mapping.market_aware_stock_prices, "get_prices", return_value=snapshot) as prices:
            response = index_stock_price_mapping.get_stock_map_live_prices(payload, username="test-user")
        self.assertEqual(response["prices"], {"SPY": 700.25})
        self.assertEqual(response["market_mode"], "weekend_30m")
        self.assertEqual(response["price_times"], {"SPY": "2026-01-02T15:30:00"})
        prices.assert_called_once_with(["SPY"])

    def test_quote_only_stock_request_uses_price_ticks_without_optional_subscriptions(self):
        from types import SimpleNamespace
        from app.services import live_stock_price_service

        class FakeIB:
            def qualifyContracts(self, *contracts):
                self.exchange = contracts[0].exchange
                return [SimpleNamespace(symbol="SPY")]

            def reqMarketDataType(self, kind):
                pass

            def reqMktData(self, contract, generic_ticks, snapshot, regulatory):
                self.generic_ticks = generic_ticks
                return SimpleNamespace(last=700.0, bid=None, ask=None, close=None, marketDataType=1)

            def cancelMktData(self, contract):
                pass

            def disconnect(self):
                pass

        fake_ib = FakeIB()
        with patch.object(live_stock_price_service, "_connect_ib", return_value=fake_ib), patch.object(
            live_stock_price_service, "Stock", return_value=SimpleNamespace(exchange="OVERNIGHT")
        ):
            quotes = live_stock_price_service.get_live_stock_prices(
                ["SPY"], wait_seconds=0, allow_close_fallback=False, quote_only=True, exchange="OVERNIGHT",
            )
        self.assertEqual(fake_ib.exchange, "OVERNIGHT")
        self.assertEqual(fake_ib.generic_ticks, "")
        self.assertEqual(quotes["SPY"]["price"], 700.0)

    def test_quote_only_connection_does_not_synchronize_account(self):
        from app.services import live_stock_price_service

        class FakeClient:
            def connect(self, host, port, clientId, timeout):
                self.connected = (host, port, clientId, timeout)

        class FakeIB:
            def __init__(self):
                self.client = FakeClient()
                self.wrapper = type("Wrapper", (), {})()

            def connect(self, *args, **kwargs):
                raise AssertionError("account sync must not run for quotes")

        with patch.object(live_stock_price_service, "IB", FakeIB):
            ib = live_stock_price_service._connect_ib(0.5, quote_only=True)
        self.assertEqual(ib.client.connected[1], live_stock_price_service.settings.ibg_api_port)
        self.assertEqual(ib.client.connected[3], 0.5)
        self.assertEqual(ib.wrapper.clientId, ib.client.connected[2])

    def test_spx_futures_ignores_settlement_close_without_a_tick(self):
        from types import SimpleNamespace
        from app.services import live_stock_price_service

        class FakeIB:
            def reqContractDetails(self, contract):
                return [SimpleNamespace(contract=SimpleNamespace(lastTradeDateOrContractMonth="99991231"))]

            def reqMarketDataType(self, kind):
                pass

            def reqMktData(self, contract, generic_ticks, snapshot, regulatory):
                return SimpleNamespace(last=None, bid=None, ask=None, close=7700.0, marketDataType=3)

            def cancelMktData(self, contract):
                pass

            def disconnect(self):
                pass

        with patch.object(live_stock_price_service, "_connect_ib", return_value=FakeIB()), patch.object(
            live_stock_price_service, "Future", return_value=object()
        ):
            quotes = live_stock_price_service.get_live_futures_prices(["ES"], wait_seconds=0)
        self.assertEqual(quotes, {})

    def test_spx_live_quotes_report_unavailable_without_breaking_map(self):
        with patch.object(index_stock_price_mapping, "get_live_stock_prices", side_effect=RuntimeError("IB unavailable")):
            response = index_stock_price_mapping.get_spx_map_live_prices(username="test-user")
        self.assertEqual(response["status"], "unavailable")
        self.assertEqual(response["live_prices"], {})

    def test_extra_stock_closes_use_latest_completed_30m_session_not_daily_price_history(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query, self.params = query, params
                return [
                    {"ASXCode": "NVDA.US", "Close": 210.25, "TimeIntervalStart": datetime(2026, 10, 21, 15, 30)},
                    {"ASXCode": "MSFT.US", "Close": 530.0, "TimeIntervalStart": datetime(2026, 10, 20, 15, 30)},
                    {"ASXCode": "SOXL.US", "Close": 44.5, "TimeIntervalStart": datetime(2026, 10, 21, 15, 30)},
                    {"ASXCode": "SPCX.US", "Close": None, "TimeIntervalStart": datetime(2026, 10, 21, 15, 30)},
                    {"ASXCode": "OTHER.US", "Close": 5, "TimeIntervalStart": datetime(2026, 10, 21, 15, 30)},
                ]

        model = FakeModel()
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=model):
            response = index_stock_price_mapping.get_spx_map_extra_prices(date(2026, 10, 21), username="test-user")
        self.assertEqual(response["historical_closes"], {"NVDA": 210.25, "MSFT": 530.0, "SOXL": 44.5})
        self.assertIn("SOXX.US", model.params)
        self.assertIn("SOXL.US", model.params)
        self.assertEqual(response["historical_close_dates"], {"NVDA": "2026-10-21", "MSFT": "2026-10-20", "SOXL": "2026-10-21"})
        self.assertEqual(response["historical_close_source"], "30m_regular_session")
        self.assertEqual(model.params[-2:], ("2026-10-07", "2026-10-21"))
        self.assertEqual(len(model.params), len(index_stock_price_mapping.SPX_MAP_EXTRA_STOCKS) + 2)
        self.assertIn("PriceHistoryTimeFrame", model.query)
        self.assertIn("TimeFrame = '30M'", model.query)
        self.assertIn("TimeIntervalStart >=", model.query)
        self.assertIn("TimeIntervalStart < DATEADD(day, 1", model.query)
        self.assertIn("ROW_NUMBER() OVER (PARTITION BY ASXCode ORDER BY TimeIntervalStart DESC)", model.query)
        self.assertIn("15:30:00", model.query)
        self.assertNotIn("[StockData].[PriceHistory]", model.query)
        self.assertEqual(response["historical_close_date"], "2026-10-21")

    def test_extra_ib_quotes_request_only_the_clicked_symbol(self):
        with patch.object(index_stock_price_mapping, "get_live_stock_prices", return_value={
            "NVDA": {"price": 208.5, "source": "ib_live"},
        }) as quotes:
            response = index_stock_price_mapping.get_spx_map_live_extra_prices(symbol="nvda", username="test-user")
        self.assertEqual(response["live_prices"], {"NVDA": 208.5})
        self.assertEqual(response["status"], "available")
        quotes.assert_called_once_with(
            ["NVDA"], wait_seconds=2.0,
            connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
            allow_close_fallback=False, quote_only=True,
        )

    def test_semiconductor_extra_quotes_require_actual_quote_only_ib_prices(self):
        for symbol in ("SOXL", "SOXX"):
            with patch.object(index_stock_price_mapping, "get_live_stock_prices", return_value={
                symbol: {"price": 100.5, "source": "ib_delayed"},
            }) as quotes:
                response = index_stock_price_mapping.get_spx_map_live_extra_prices(symbol=symbol.lower(), username="test-user")
            self.assertEqual(response["live_prices"], {symbol: 100.5})
            quotes.assert_called_once_with(
                [symbol], wait_seconds=2.0,
                connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
                allow_close_fallback=False, quote_only=True,
            )

    def test_manual_symbol_quote_routes_reject_unknown_symbols_without_contacting_ib(self):
        from fastapi.testclient import TestClient
        from app.main import app

        app.dependency_overrides[index_stock_price_mapping.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(index_stock_price_mapping, "get_live_stock_prices") as stocks, patch.object(
                index_stock_price_mapping, "get_live_futures_prices"
            ) as futures:
                client = TestClient(app)
                self.assertEqual(client.get("/api/spx-map-live-extra-prices").status_code, 422)
                for url in (
                    "/api/spx-map-live-extra-prices?symbol=XYZ",
                    "/api/spx-map-live-prices?symbol=NVDA",
                    "/api/spx-map-live-futures?symbol=MNQ",
                ):
                    self.assertEqual(client.get(url).status_code, 400)
                stocks.assert_not_called()
                futures.assert_not_called()
        finally:
            app.dependency_overrides.pop(index_stock_price_mapping.verify_credentials, None)

    def test_manual_symbol_quote_routes_request_only_one_contract(self):
        from fastapi.testclient import TestClient
        from app.main import app

        app.dependency_overrides[index_stock_price_mapping.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(index_stock_price_mapping, "get_live_stock_prices", return_value={"QQQ": {"price": 720.25}}) as stocks, patch.object(
                index_stock_price_mapping, "get_live_futures_prices", return_value={"NQ": {"price": 25000.5}}
            ) as futures:
                client = TestClient(app)
                self.assertEqual(client.get("/api/spx-map-live-prices?symbol=qqq").json()["live_prices"], {"QQQ": 720.25})
                self.assertEqual(client.get("/api/spx-map-live-futures?symbol=NQMain").json()["live_prices"], {"NQMain": 25000.5})
                stocks.assert_called_once_with(
                    ["QQQ"], wait_seconds=2.0, connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
                    allow_close_fallback=False, quote_only=True,
                )
                futures.assert_called_once_with(
                    ["NQ"], wait_seconds=2.0, connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
                    quote_only=True,
                )
        finally:
            app.dependency_overrides.pop(index_stock_price_mapping.verify_credentials, None)

    def test_load_latest_closes_falls_back_to_futures_for_missing_mes_and_mnq(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                return [{"ASXCode": "SPY.US", "Close": 600.25}]

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()), patch.object(
            index_stock_price_mapping,
            "get_live_futures_closes",
            return_value={"MES": {"price": 6001.5}, "MNQ": {"price": 21000.0}},
        ):
            closes = index_stock_price_mapping._load_latest_closes()

        self.assertEqual(closes, {"SPY": 600.25, "MES": 6001.5, "MNQ": 21000.0})


if __name__ == "__main__":
    unittest.main()
