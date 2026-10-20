import unittest
from datetime import date
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
        self.assertEqual(len(calls), 6)
        for query, params in calls:
            self.assertIn("TimeFrame = '5M'", query)
            self.assertIn("TimeIntervalStart >=", query)
            self.assertIn("TimeIntervalStart <", query)
            self.assertIn("ORDER BY TimeIntervalStart DESC", query)
            self.assertEqual(params[-3], "2026-10-06")
            self.assertEqual(params[-2], "2026-10-20")
            self.assertIn(params[-1], {"14:55:00", "15:55:00"})

    def test_dated_spx_mapping_does_not_wait_for_optional_live_ib(self):
        historical = {"SPX": 7655.0, "SPY": 765.5, "ESMain": 7670.0}
        with patch.object(index_stock_price_mapping, "_load_snapshot_closes", return_value=historical), patch.object(
            index_stock_price_mapping, "_load_mapped_live_prices", side_effect=RuntimeError("IB sync stalled")
        ) as live:
            response = index_stock_price_mapping.get_spx_map_prices(
                observation_date=date(2026, 10, 20), username="test-user"
            )
        self.assertEqual(response["historical_close_date"], date(2026, 10, 20))
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
                index_stock_price_mapping, "_load_mapped_live_prices", side_effect=RuntimeError("IB unavailable")
            ) as live:
                response = TestClient(app).get("/api/spx-map-prices?observation_date=2026-10-20")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["historical_closes"], {"SPX": 7691.92})
            self.assertEqual(response.json()["live_prices_status"], "not_requested_for_historical_mapping")
            live.assert_not_called()
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
