import unittest
from datetime import date
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.routers import auth
from app.routers import support_resistance


AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


class RelativePerformanceApiTests(unittest.TestCase):
    def test_multi_symbol_request_returns_bar_series_for_requested_interval(self):
        expected = {
            "timeframe": "5M", "lookback_days": 3, "symbols": ["SPY", "QQQ"],
            "bars_by_symbol": {"SPY": [{"time": "2026-11-03T15:00:00", "close": 100.0}],
                               "QQQ": [{"time": "2026-11-03T15:00:00", "close": 200.0}]},
        }
        with patch.object(auth, "get_credentials", return_value={"username": "admin", "password": "password123"}), patch.object(
            support_resistance, "get_relative_performance_bars", return_value=expected
        ) as loader:
            response = TestClient(app).get(
                "/api/support-resistance/relative-performance?symbols=SPY&symbols=QQQ&timeframe=5M&lookback_days=3",
                headers=AUTH,
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), expected)
        loader.assert_called_once_with(["SPY", "QQQ"], timeframe="5M", lookback_days=3,
                                       start_date=None, end_date=None)

    def test_date_range_passed_to_history_query(self):
        with patch.object(auth, "get_credentials", return_value={"username": "admin", "password": "password123"}), patch.object(
            support_resistance, "get_relative_performance_bars", return_value={"bars_by_symbol": {"SPY": []}}
        ) as loader:
            response = TestClient(app).get(
                "/api/support-resistance/relative-performance?symbols=SPY&start_date=2026-11-03&end_date=2026-11-06",
                headers=AUTH,
            )
        self.assertEqual(response.status_code, 200)
        loader.assert_called_once_with(["SPY"], timeframe="5M", lookback_days=5,
                                       start_date=date(2026, 11, 3), end_date=date(2026, 11, 6))

    def test_rejects_reversed_date_range(self):
        with patch.object(auth, "get_credentials", return_value={"username": "admin", "password": "password123"}):
            response = TestClient(app).get(
                "/api/support-resistance/relative-performance?symbols=SPY&start_date=2026-11-06&end_date=2026-11-03",
                headers=AUTH,
            )
        self.assertEqual(response.status_code, 422)
        self.assertIn("End date", response.json()["detail"])

    def test_live_quote_batch_returns_partial_quotes_and_unavailable_symbols(self):
        expected = {
            "quotes": {"SPY": {"price": 600.25, "source": "ib_live"}},
            "unavailable": ["QQQ"], "fetched_at_utc": "2026-11-03T15:00:00+00:00",
        }
        with patch.object(auth, "get_credentials", return_value={"username": "admin", "password": "password123"}), patch.object(
            support_resistance, "get_relative_performance_live_quotes", return_value=expected
        ) as loader:
            response = TestClient(app).post(
                "/api/support-resistance/relative-performance/live-quotes",
                headers=AUTH, json={"symbols": ["SPY", "QQQ"]},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), expected)
        loader.assert_called_once_with(["SPY", "QQQ"])

    def test_rejects_unsupported_timeframe(self):
        with patch.object(auth, "get_credentials", return_value={"username": "admin", "password": "password123"}):
            response = TestClient(app).get(
                "/api/support-resistance/relative-performance?symbols=SPY&timeframe=1M",
                headers=AUTH,
            )
        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()
