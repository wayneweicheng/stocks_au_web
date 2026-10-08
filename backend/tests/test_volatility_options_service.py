from __future__ import annotations

from datetime import date, timedelta
import unittest
from unittest.mock import patch

from app.services import volatility_options_service as service


class FakeModel:
    def execute_read_query(self, _sql, params):
        self.params = params
        start = date(2026, 1, 1)
        return [
            {
                "ObservationDate": start + timedelta(days=index),
                "Open": 100 + index,
                "High": 101 + index,
                "Low": 99 + index,
                "Close": 100.5 + index,
                "Volume": 1_000_000,
            }
            for index in reversed(range(30))
        ]


class VolatilityOptionsServiceTests(unittest.TestCase):
    def test_normalize_symbols_deduplicates_and_removes_us_suffix(self):
        self.assertEqual(service.normalize_symbols(" qqq.us, SPY,qqq "), ["QQQ", "SPY"])

    def test_select_expirations_spans_requested_window(self):
        payload = {
            "expirations": [
                {"expiry": f"202610{day:02d}", "dte": dte}
                for day, dte in enumerate((30, 35, 40, 45, 50, 55), start=1)
            ]
        }
        selected = service.select_expirations(payload, 30, 55, maximum=4)
        self.assertEqual(len(selected), 4)
        self.assertEqual(selected[0], "20261001")
        self.assertEqual(selected[-1], "20261006")

    @patch.object(service, "get_option_chain")
    @patch.object(service, "get_option_expirations")
    @patch.object(service, "get_sql_model")
    def test_build_underlying_snapshot_uses_existing_data_paths(self, model, expirations, chain):
        model.return_value = FakeModel()
        expirations.return_value = {
            "underlying": {"reference_price": 130.0},
            "expirations": [{"expiry": "20260320", "dte": 40}],
        }
        chain.return_value = {
            "chain_source": "database",
            "rows": [
                {
                    "option_symbol": "QQQ260320P00120000",
                    "expiry": "20260320",
                    "expiry_date": "2026-03-20",
                    "strike": 120,
                    "right": "P",
                    "quote": {
                        "bid": 2.0,
                        "ask": 2.2,
                        "iv": 0.30,
                        "delta": -0.2,
                        "volume": 25,
                        "source": "database",
                        "observation_date": "2026-01-25",
                    },
                }
            ],
        }

        result = service.build_underlying_snapshot("QQQ", 30, 55, {"QQQ"})

        self.assertEqual(result["event_status"], "clear")
        self.assertEqual(result["asset_type"], "ETF")
        self.assertEqual(result["spot"], 124.5)
        self.assertEqual(len(result["price_history"]), 25)
        self.assertEqual(result["source"]["evidence_cutoff"], "2026-01-25")
        self.assertEqual(result["options"][0]["iv"], 0.30)
        self.assertEqual(model.return_value.params, ("QQQ.US",))
        chain.assert_called_once_with(
            symbol="QQQ", right="P", max_expiries=1, strike_window_pct=0.40, expiry="20260320"
        )

    def test_too_many_symbols_are_rejected(self):
        with self.assertRaises(ValueError):
            service.normalize_symbols(",".join(f"S{index}" for index in range(service.MAX_SYMBOLS + 1)))


if __name__ == "__main__":
    unittest.main()
