import unittest

from app.services.market_command_service import (
    analyze_us_breadth,
    rank_option_strategies,
    score_regime_components,
    score_vix_regime,
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

    def test_low_vix_supports_bull_market_grind(self):
        score, phase = score_vix_regime(16, bullish_structure=True)

        self.assertGreaterEqual(score, 70)
        self.assertEqual(phase, "bull-market grind")

    def test_high_vix_in_bullish_structure_reflects_bottoming(self):
        early_bottom_score, _ = score_vix_regime(26, bullish_structure=True)
        capitulation_score, phase = score_vix_regime(32, bullish_structure=True)

        self.assertGreater(capitulation_score, early_bottom_score)
        self.assertGreater(capitulation_score, 65)
        self.assertEqual(phase, "capitulation / bottoming")

    def test_high_vix_without_bullish_structure_remains_risk_off(self):
        score, phase = score_vix_regime(32, bullish_structure=False)

        self.assertLess(score, 25)
        self.assertEqual(phase, "elevated risk")

    def test_vix_curve_clamps_to_supported_12_to_40_range(self):
        below_range, _ = score_vix_regime(8, bullish_structure=True)
        lower_bound, _ = score_vix_regime(12, bullish_structure=True)
        above_range, _ = score_vix_regime(50, bullish_structure=True)
        upper_bound, _ = score_vix_regime(40, bullish_structure=True)

        self.assertEqual(below_range, lower_bound)
        self.assertEqual(above_range, upper_bound)

    def test_breadth_flags_narrow_spx_advance(self):
        score, detail, diagnostics = analyze_us_breadth(
            {
                "TodayAverageChange": -0.20,
                "TodayChange": 0.80,
                "NumAdv": 150,
                "NumDec": 350,
            }
        )

        self.assertLess(score, 40)
        self.assertIn("NARROW ADVANCE", detail)
        self.assertEqual(diagnostics["advance_percentage"], 30.0)
        self.assertEqual(diagnostics["leadership_gap"], -1.0)

    def test_breadth_rewards_broad_advance(self):
        score, detail, diagnostics = analyze_us_breadth(
            {
                "TodayAverageChange": 0.70,
                "TodayChange": 0.50,
                "NumAdv": 350,
                "NumDec": 150,
            }
        )

        self.assertGreater(score, 65)
        self.assertIn("BROAD ADVANCE", detail)
        self.assertEqual(diagnostics["advance_percentage"], 70.0)

    def test_breadth_detects_average_stock_strength_under_red_spx(self):
        score, detail, diagnostics = analyze_us_breadth(
            {
                "TodayAverageChange": 0.25,
                "TodayChange": -0.30,
                "NumAdv": 275,
                "NumDec": 225,
            }
        )

        self.assertGreater(score, 55)
        self.assertIn("RESILIENT BREADTH", detail)
        self.assertEqual(diagnostics["leadership_gap"], 0.55)

    def test_breadth_includes_medium_and_long_term_participation(self):
        strong_score, _, strong = analyze_us_breadth(
            {
                "TodayAverageChange": 0.20,
                "TodayChange": 0.20,
                "NumAdv": 275,
                "NumDec": 225,
                "PercentageAboveSMA50": 75,
                "PercentageAboveSMA200": 80,
            }
        )
        weak_score, _, weak = analyze_us_breadth(
            {
                "TodayAverageChange": 0.20,
                "TodayChange": 0.20,
                "NumAdv": 275,
                "NumDec": 225,
                "PercentageAboveSMA50": 25,
                "PercentageAboveSMA200": 20,
            }
        )

        self.assertGreater(strong_score, weak_score)
        self.assertEqual(strong["percentage_above_sma50"], 75.0)
        self.assertEqual(weak["percentage_above_sma200"], 20.0)


if __name__ == "__main__":
    unittest.main()
