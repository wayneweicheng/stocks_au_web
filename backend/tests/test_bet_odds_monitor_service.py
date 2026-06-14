from decimal import Decimal
import unittest

from app.services.bet_odds_monitor_service import (
    automatic_expiry_from_start_time,
    compare_odds,
    extract_market_options,
    parse_tab_match_url,
)


SOURCE_URL = (
    "https://www.tab.com.au/sports/betting/Soccer/competitions/"
    "2026%20World%20Cup%20Matches/matches/Netherlands%20v%20Japan"
)


class BetOddsMonitorServiceTests(unittest.TestCase):
    def test_parse_tab_match_url(self):
        result = parse_tab_match_url(SOURCE_URL)

        self.assertEqual(result.sport_name, "Soccer")
        self.assertEqual(result.competition_name, "2026 World Cup Matches")
        self.assertEqual(result.match_name, "Netherlands v Japan")
        self.assertIsNone(result.tournament_name)
        self.assertTrue(
            result.api_path().endswith(
                "/Soccer/competitions/2026%20World%20Cup%20Matches/"
                "matches/Netherlands%20v%20Japan"
            )
        )

    def test_parse_tab_match_url_rejects_external_host(self):
        with self.assertRaisesRegex(ValueError, "Only HTTPS TAB"):
            parse_tab_match_url("https://example.com/sports/betting/Soccer")

    def test_extract_market_options_supports_tab_fields(self):
        match_data = {
            "markets": [
                {
                    "betOption": "Line",
                    "propositions": [
                        {
                            "id": "japan-line",
                            "name": "Japan",
                            "line": 0.5,
                            "returnWin": 2.02,
                            "isOpen": True,
                        }
                    ],
                },
                {
                    "marketName": "Netherlands Total Goals",
                    "selections": [
                        {
                            "selectionId": "netherlands-under",
                            "selectionName": "Under 1.5",
                            "fixedOdds": {"win": "2.10"},
                            "bettingStatus": "Open",
                        }
                    ],
                },
            ]
        }

        options = extract_market_options(match_data)

        self.assertEqual(
            options,
            [
                {
                    "market_name": "Line",
                    "selection_name": "Japan +0.5",
                    "raw_selection_name": "Japan",
                    "display_name": "Japan +0.5",
                    "proposition_id": "japan-line",
                    "odds": 2.02,
                    "line": 0.5,
                    "is_open": True,
                },
                {
                    "market_name": "Netherlands Total Goals",
                    "selection_name": "Under 1.5",
                    "raw_selection_name": "Under 1.5",
                    "display_name": "Under 1.5",
                    "proposition_id": "netherlands-under",
                    "odds": 2.1,
                    "line": None,
                    "is_open": True,
                },
            ],
        )

    def test_compare_odds(self):
        examples = [
            ("2.02", ">=", "2.02", True),
            ("2.01", ">=", "2.02", False),
            ("1.99", "<=", "2.00", True),
            ("2.00", "=", "2.00", True),
        ]
        for observed, comparison_operator, target, expected in examples:
            with self.subTest(
                observed=observed,
                comparison_operator=comparison_operator,
                target=target,
            ):
                self.assertIs(
                    compare_odds(
                        Decimal(observed),
                        comparison_operator,
                        Decimal(target),
                    ),
                    expected,
                )

    def test_automatic_expiry_is_thirty_minutes_before_sydney_start(self):
        expiry = automatic_expiry_from_start_time("2026-06-14T20:00:00.000Z")

        self.assertEqual(expiry.isoformat(), "2026-06-15T05:30:00+10:00")


if __name__ == "__main__":
    unittest.main()
