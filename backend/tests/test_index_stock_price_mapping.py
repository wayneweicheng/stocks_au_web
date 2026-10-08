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
