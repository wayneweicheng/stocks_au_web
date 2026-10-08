from __future__ import annotations

from datetime import date, timedelta
import unittest

from app.services.volatility_options_historical import build_historical_dataset


class FakeModel:
    def execute_read_query(self, sql, params):
        if "v_PriceHistory" in sql:
            return [
                {
                    "ASXCode": "QQQ.US",
                    "ObservationDate": date(2026, 1, 1) + timedelta(days=index),
                    "Open": 100 + index,
                    "High": 101 + index,
                    "Low": 99 + index,
                    "Close": 100 + index,
                    "Volume": 1000000,
                }
                for index in range(100)
            ]
        return [
            {
                "ASXCode": "QQQ.US",
                "ObservationDate": date(2026, 3, 20),
                "OptionSymbol": "QQQ260425P00095000",
                "ExpiryDate": date(2026, 4, 25),
                "Strike": 95,
                "PorC": "P",
                "Bid": 1.5,
                "Ask": 1.7,
                "IV": 0.30,
                "OpenInterest": 100,
                "Volume": 50,
                "Delta": -0.2,
            }
        ]


class HistoricalDatasetTests(unittest.TestCase):
    def test_builds_point_in_time_dataset_with_forward_prices(self):
        result = build_historical_dataset(
            symbols="QQQ",
            start_date="2026-03-20",
            end_date="2026-03-20",
            account_equity=100000,
            event_clear_symbols="QQQ",
            model=FakeModel(),
        )
        self.assertEqual(len(result["snapshots"]), 1)
        snapshot = result["snapshots"][0]
        self.assertEqual(snapshot["underlyings"][0]["spot"], 178)
        self.assertEqual(snapshot["underlyings"][0]["event_status"], "clear")
        self.assertTrue(snapshot["forward_market"])
        self.assertTrue(result["source"]["point_in_time"])


if __name__ == "__main__":
    unittest.main()
