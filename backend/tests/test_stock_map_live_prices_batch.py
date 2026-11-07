import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.routers import index_stock_price_mapping as mapping


class StockMapLivePricesBatchTests(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides[mapping.verify_credentials] = lambda: "test-user"
        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides.pop(mapping.verify_credentials, None)

    def test_only_real_time_ib_stock_prices_are_returned(self):
        with patch.object(mapping, "get_live_stock_prices", return_value={
            "SPXL": {"price": 248.75, "source": "ib_live"},
            "QQQ": {"price": 400.0, "source": "ib_delayed"},
            "AAPL": {"price": 0, "source": "ib_live"},
        }) as quotes:
            response = self.client.post("/api/stock-map-live-prices", json={"symbols": ["spxl", "qqq", "AAPL", "SPXL"]})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["prices"], {"SPXL": 248.75})
        self.assertIn("fetched_at_utc", response.json())
        quotes.assert_called_once_with(
            ["SPXL", "QQQ", "AAPL"], wait_seconds=2.0,
            connect_timeout=mapping.QUOTE_CONNECT_TIMEOUT_SECONDS,
            allow_close_fallback=False, quote_only=True,
        )

    def test_ib_failure_and_invalid_requests_do_not_create_prices(self):
        with patch.object(mapping, "get_live_stock_prices", side_effect=RuntimeError("IB offline")):
            response = self.client.post("/api/stock-map-live-prices", json={"symbols": ["SPXL"]})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["prices"], {})
        with patch.object(mapping, "get_live_stock_prices") as quotes:
            self.assertEqual(self.client.post("/api/stock-map-live-prices", json={"symbols": ["SPXL;DROP"]}).status_code, 400)
            self.assertEqual(self.client.post("/api/stock-map-live-prices", json={"symbols": []}).status_code, 422)
            self.assertEqual(self.client.post("/api/stock-map-live-prices", json={"symbols": ["SPXL"] * 41}).status_code, 422)
            quotes.assert_not_called()


if __name__ == "__main__":
    unittest.main()
