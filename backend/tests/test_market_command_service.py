import unittest

from app.services.market_command_service import (
    rank_option_strategies,
    score_regime_components,
)


class MarketCommandScoringTests(unittest.TestCase):
    def test_regime_score_renormalizes_available_components(self):
        score, confidence = score_regime_components(
            [
                {"available": True, "score": 80, "weight": 25},
                {"available": True, "score": 60, "weight": 25},
                {"available": False, "score": None, "weight": 50},
            ]
        )

        self.assertEqual(score, 70.0)
        self.assertGreater(confidence, 0)
        self.assertLess(confidence, 50)

    def test_missing_regime_data_is_neutral_with_zero_confidence(self):
        score, confidence = score_regime_components(
            [{"available": False, "score": None, "weight": 100}]
        )

        self.assertEqual(score, 50.0)
        self.assertEqual(confidence, 0.0)

    def test_bullish_opportunity_prefers_defined_risk_bullish_strategies(self):
        strategies = rank_option_strategies(
            direction="BULLISH",
            opportunity_score=86,
            regime_label="BULLISH",
            market="US",
            gex_regime="POSITIVE",
        )

        names = [item["strategy"] for item in strategies]
        self.assertIn("BULL_CALL_SPREAD", names)
        self.assertTrue(all(item["requires_chain_validation"] for item in strategies))

    def test_neutral_positive_gex_prefers_iron_condor(self):
        strategies = rank_option_strategies(
            direction="NEUTRAL",
            opportunity_score=55,
            regime_label="NEUTRAL",
            market="US",
            gex_regime="POSITIVE",
        )

        self.assertEqual(strategies[0]["strategy"], "IRON_CONDOR")

    def test_asx_does_not_offer_us_option_strategies(self):
        strategies = rank_option_strategies(
            direction="BULLISH",
            opportunity_score=80,
            regime_label="BULLISH",
            market="ASX",
        )

        self.assertEqual(strategies, [])


if __name__ == "__main__":
    unittest.main()
