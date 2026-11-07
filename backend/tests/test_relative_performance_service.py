import unittest
from datetime import date, datetime
from unittest.mock import Mock, patch

from app.services import relative_performance_service as service


class RelativePerformanceServiceTests(unittest.TestCase):
    def test_bulk_history_maps_esmain_alias_and_returns_requested_symbols(self):
        class FakeModel:
            def __init__(self):
                self.calls = []

            def execute_read_query(self, query, params):
                self.calls.append((query, params))
                if "MAX(TimeIntervalStart)" in query:
                    return [{"LatestTime": datetime(2026, 11, 3, 15, 0)}]
                return [
                    {"ASXCode": "ESMain.US", "TimeIntervalStart": datetime(2026, 11, 3, 14, 55), "Open": 100, "High": 101, "Low": 99, "Close": 100.5, "Volume": 20, "TimeFrame": "5M"},
                    {"ASXCode": "SPY.US", "TimeIntervalStart": datetime(2026, 11, 3, 14, 55), "Open": 500, "High": 501, "Low": 499, "Close": 500.5, "Volume": 30, "TimeFrame": "5M"},
                    {"ASXCode": "DIA.US", "TimeIntervalStart": datetime(2026, 11, 3, 14, 55), "Open": 450, "High": 451, "Low": 449, "Close": 450.5, "Volume": 40, "TimeFrame": "5M"},
                ]

            def close(self):
                pass

        fake = FakeModel()
        with patch.object(service, "_open_saved_price_levels_model", return_value=fake), patch.object(service, "_close_saved_price_levels_model"):
            result = service.get_relative_performance_bars(["ESMain", "SPY", "DJI"], timeframe="5M", lookback_days=3)

        self.assertEqual(result["symbols"], ["ESMain", "SPY", "DJI"])
        self.assertEqual(result["bars_by_symbol"]["ESMain"][0]["close"], 100.5)
        self.assertEqual(result["bars_by_symbol"]["SPY"][0]["close"], 500.5)
        self.assertEqual(result["bars_by_symbol"]["DJI"][0]["close"], 450.5)
        self.assertEqual(len(fake.calls), 2)
        self.assertIn("ESMain.US", fake.calls[0][1])
        self.assertIn("DIA.US", fake.calls[0][1])

    def test_live_quotes_use_common_stock_policy_and_keep_special_instruments(self):
        snapshot = Mock(prices={"SPY": 600.25, "DIA": 450.0, "QQQ": None},
                        price_sources={"SPY": "ib_live", "DIA": "database_30m"},
                        price_times={"DIA": "2026-11-06T16:00:00"}, fetched_at_utc="2026-11-07T12:00:00+00:00")
        with patch.object(service.market_aware_stock_prices, "get_prices", return_value=snapshot) as stock_prices, patch.object(
            service, "get_live_futures_prices", return_value={"ES": {"price": 6200.5, "source": "ib_delayed"}}
        ) as futures_quotes:
            result = service.get_relative_performance_live_quotes(["ESMain", "SPY", "QQQ", "DJI"])

        self.assertEqual(result["quotes"]["SPY"]["price"], 600.25)
        self.assertEqual(result["quotes"]["ESMain"]["price"], 6200.5)
        self.assertEqual(result["quotes"]["DJI"]["price"], 450.0)
        self.assertEqual(result["quotes"]["DJI"]["price_time"], "2026-11-06T16:00:00")
        self.assertEqual(result["quotes"]["DJI"]["fetched_at_utc"], "2026-11-07T12:00:00+00:00")
        self.assertIn("database_30m (DIA ETF proxy)", result["quotes"]["DJI"]["source"])
        self.assertEqual(result["unavailable"], ["QQQ"])
        stock_prices.assert_called_once_with(["SPY", "QQQ", "DIA"])
        futures_quotes.assert_called_once()

    def test_explicit_date_range_queries_full_inclusive_calendar_days_without_latest_lookup(self):
        calls = []
        def execute(model, query, params):
            calls.append((query, params))
            return [{"ASXCode": "SPY.US", "TimeIntervalStart": datetime(2026, 11, 6, 23, 55),
                     "Open": 100, "High": 101, "Low": 99, "Close": 100.5, "Volume": 50}]

        with patch.object(service, "_open_saved_price_levels_model", return_value=object()), patch.object(
            service, "_execute_saved_price_levels_query", side_effect=execute
        ), patch.object(service, "_close_saved_price_levels_model"):
            result = service.get_relative_performance_bars(
                ["SPY"], start_date=date(2026, 11, 3), end_date=date(2026, 11, 6),
            )
        self.assertEqual(len(calls), 1)
        self.assertIn("TimeIntervalStart < ?", calls[0][0])
        self.assertEqual(calls[0][1][-2:], (datetime(2026, 11, 3), datetime(2026, 11, 7)))
        self.assertEqual(result["bars_by_symbol"]["SPY"][0]["close"], 100.5)

    def test_date_range_validation(self):
        cases = [
            (date(2026, 11, 2), None),
            (None, date(2026, 11, 2)),
            (date(2026, 11, 5), date(2026, 11, 2)),
            (date(2026, 10, 1), date(2026, 11, 2)),
        ]
        for start, end in cases:
            with self.subTest(start=start, end=end), self.assertRaises(ValueError):
                service.get_relative_performance_bars(["SPY"], start_date=start, end_date=end)


if __name__ == "__main__":
    unittest.main()
