import unittest
from datetime import date

from app.services.fear_greed_service import (
    FearGreedService,
    classify_fear_greed,
    parse_cnn_fear_greed,
)


SAMPLE_PAYLOAD = {
    "fear_and_greed": {
        "score": 18,
        "rating": "extreme fear",
        "timestamp": "2026-06-13T23:59:56+00:00",
        "previous_close": 22,
        "previous_1_week": 35,
        "previous_1_month": 60,
        "previous_1_year": 55,
    }
}


class FearGreedServiceTests(unittest.TestCase):
    def test_classifies_score(self):
        self.assertEqual(classify_fear_greed(18), "extreme fear")
        self.assertEqual(classify_fear_greed(34), "fear")
        self.assertEqual(classify_fear_greed(50), "neutral")
        self.assertEqual(classify_fear_greed(65), "greed")
        self.assertEqual(classify_fear_greed(80), "extreme greed")

    def test_parses_cnn_payload(self):
        reading = parse_cnn_fear_greed(SAMPLE_PAYLOAD)

        self.assertEqual(reading["reading_date"], "2026-06-13")
        self.assertEqual(reading["score"], 18)
        self.assertEqual(reading["previous_1_week"], 35)

    def test_extreme_fear_is_contrarian_positive_context(self):
        insight = FearGreedService(fetcher=lambda: SAMPLE_PAYLOAD).get_insight(
            date(2026, 6, 13)
        )

        self.assertEqual(insight["rating"], "extreme fear")
        self.assertGreater(insight["contrarian_score"], 65)
        self.assertEqual(len(insight["predictions"]), 5)

    def test_fetch_failure_uses_local_research(self):
        def fail():
            raise OSError("offline")

        insight = FearGreedService(fetcher=fail).get_insight(date(2026, 6, 13))

        self.assertEqual(insight["reading_date"], "2026-06-12")
        self.assertEqual(insight["source_status"], "local CNN research fallback")
        self.assertEqual(insight["fetch_error"], "offline")

    def test_live_reading_wins_same_date_tie(self):
        payload = {
            "fear_and_greed": {
                "score": 34,
                "rating": "fear",
                "timestamp": "2026-06-12T23:59:56+00:00",
                "previous_close": 29,
                "previous_1_week": 42,
                "previous_1_month": 65,
                "previous_1_year": 64,
            }
        }

        insight = FearGreedService(fetcher=lambda: payload).get_insight(
            date(2026, 6, 13)
        )

        self.assertEqual(insight["source_status"], "live CNN data")
        self.assertEqual(insight["previous_close"], 29)


if __name__ == "__main__":
    unittest.main()
