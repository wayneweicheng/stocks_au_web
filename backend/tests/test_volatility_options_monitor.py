from __future__ import annotations

import unittest

from app.services.volatility_options_monitor import portfolio_risk_snapshot


class FakeStore:
    model = object()

    def get_schedule(self):
        return {
            "AccountEquity": 100000,
            "MaxAssignmentExposurePct": 0.75,
            "RiskBudgetPct": 0.02,
        }

    def list_manual_positions(self, status):
        return [
            {
                "Symbol": "QQQ",
                "Strategy": "short_put",
                "ShortStrike": 500,
                "EntryCredit": 5,
                "Quantity": 1,
                "CurrentDelta": 0.2,
                "CurrentGamma": -0.01,
                "CurrentTheta": 0.1,
                "CurrentVega": -0.4,
            },
            {
                "Symbol": "SPY",
                "Strategy": "bull_put_spread",
                "ShortStrike": 500,
                "LongStrike": 490,
                "EntryCredit": 2,
                "Quantity": 2,
                "CurrentDelta": 0.1,
                "CurrentGamma": -0.002,
                "CurrentTheta": 0.03,
                "CurrentVega": -0.1,
            },
        ]


class VolatilityMonitorTests(unittest.TestCase):
    def test_portfolio_risk_aggregates_manual_positions_without_broker_calls(self):
        risk = portfolio_risk_snapshot(store=FakeStore())
        self.assertEqual(risk["open_positions"], 2)
        self.assertEqual(risk["assignment_exposure"], 50000)
        self.assertAlmostEqual(risk["portfolio_delta"], 40)
        self.assertIn("QQQ", risk["symbol_exposure"])
        self.assertIn("aggregate manual-position stress budget exceeded", risk["breaches"])


if __name__ == "__main__":
    unittest.main()
