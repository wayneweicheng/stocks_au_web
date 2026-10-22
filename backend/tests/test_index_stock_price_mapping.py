import unittest
from datetime import date, datetime
from unittest.mock import patch

from app.routers import index_stock_price_mapping


class IndexStockPriceMappingTests(unittest.TestCase):
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

    def test_snapshot_closes_use_indexed_5m_bounded_date_lookup(self):
        calls = []

        class FakeModel:
            def execute_read_query(self, query, params):
                calls.append((query, params))
                return []

        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()):
            self.assertEqual(index_stock_price_mapping._load_snapshot_closes(date(2026, 10, 20)), {})
        self.assertEqual(len(calls), 7)
        self.assertIn("NQMain.US", [params[0] for _, params in calls])
        for query, params in calls:
            self.assertIn("TimeFrame = '5M'", query)
            self.assertIn("TimeIntervalStart >=", query)
            self.assertIn("TimeIntervalStart <", query)
            self.assertIn("ORDER BY TimeIntervalStart DESC", query)
            self.assertEqual(params[-3], "2026-10-06")
            self.assertEqual(params[-2], "2026-10-20")
            self.assertIn(params[-1], {"14:55:00", "15:55:00"})

    def test_snapshot_tracks_each_close_date_for_live_ratio_safety(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                if params[0] == "NQMain.US":
                    return [{"Close": 25000, "ObservationDate": date(2026, 10, 19)}]
                if params[0] == "SPY.US":
                    return [{"Close": 700, "ObservationDate": date(2026, 10, 20)}]
                return []

        dates = {}
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=FakeModel()):
            closes = index_stock_price_mapping._load_snapshot_closes(date(2026, 10, 20), dates)
        self.assertEqual(closes, {"SPY": 700, "NQMain": 25000})
        self.assertEqual(dates, {"SPY": "2026-10-20", "NQMain": "2026-10-19"})

    def test_dated_spx_mapping_does_not_wait_for_optional_live_ib(self):
        historical = {"SPX": 7655.0, "SPY": 765.5, "ESMain": 7670.0}
        with patch.object(index_stock_price_mapping, "_load_snapshot_closes", return_value=historical), patch.object(
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
                    {"ASXCode": "SPCX.US", "Close": None, "TimeIntervalStart": datetime(2026, 10, 21, 15, 30)},
                    {"ASXCode": "OTHER.US", "Close": 5, "TimeIntervalStart": datetime(2026, 10, 21, 15, 30)},
                ]

        model = FakeModel()
        with patch.object(index_stock_price_mapping, "SQLServerModel", return_value=model):
            response = index_stock_price_mapping.get_spx_map_extra_prices(date(2026, 10, 21), username="test-user")
        self.assertEqual(response["historical_closes"], {"NVDA": 210.25, "MSFT": 530.0})
        self.assertIn("SOXX.US", model.params)
        self.assertNotIn("SOXL.US", model.params)
        self.assertEqual(response["historical_close_dates"], {"NVDA": "2026-10-21", "MSFT": "2026-10-20"})
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

    def test_extra_ib_quotes_are_partial_not_historical_fallback(self):
        with patch.object(index_stock_price_mapping, "get_live_stock_prices", return_value={
            "NVDA": {"price": 208.5, "source": "ib_live"}, "SPCX": {"price": float("nan")},
        }) as quotes:
            response = index_stock_price_mapping.get_spx_map_live_extra_prices(username="test-user")
        self.assertEqual(response["live_prices"], {"NVDA": 208.5})
        self.assertEqual(response["status"], "partial")
        quotes.assert_called_once_with(
            index_stock_price_mapping.SPX_MAP_EXTRA_STOCKS,
            wait_seconds=2.0,
            connect_timeout=index_stock_price_mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
            allow_close_fallback=False,
            quote_only=True,
        )

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
