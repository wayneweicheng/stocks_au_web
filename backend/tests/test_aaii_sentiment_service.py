import unittest
from datetime import date

from app.services.aaii_sentiment_service import (
    AAIISentimentService,
    parse_latest_aaii_reading,
)


SAMPLE_HTML = """
<html><body>
<h1>Sentiment Survey Historical Data</h1>
<table>
<tr><th>Reported Date</th><th>Bullish</th><th>Neutral</th><th>Bearish</th></tr>
<tr><td>Jun 11</td><td>30.4%</td><td>22.0%</td><td>47.6%</td></tr>
</table>
</body></html>
"""


class AAIISentimentServiceTests(unittest.TestCase):
    def test_parses_latest_public_page_row(self):
        reading = parse_latest_aaii_reading(SAMPLE_HTML, date(2026, 6, 13))

        self.assertEqual(reading["reading_date"], "2026-06-11")
        self.assertAlmostEqual(reading["bullish"], 0.304, places=3)
        self.assertAlmostEqual(reading["bearish"], 0.476, places=3)

    def test_live_reading_generates_contrarian_spx_insight(self):
        service = AAIISentimentService(fetcher=lambda: SAMPLE_HTML)
        insight = service.get_insight(date(2026, 6, 13))

        self.assertEqual(insight["reading_date"], "2026-06-11")
        self.assertIn("CONTRARIAN POSITIVE", insight["regime"])
        self.assertEqual(len(insight["predictions"]), 4)
        self.assertEqual(insight["preferred_horizon_weeks"], 13)

    def test_fetch_failure_uses_local_researched_data(self):
        def fail():
            raise OSError("offline")

        insight = AAIISentimentService(fetcher=fail).get_insight(date(2026, 6, 13))

        self.assertEqual(insight["reading_date"], "2026-06-11")
        self.assertEqual(insight["source_status"], "local AAII workbook fallback")
        self.assertEqual(insight["fetch_error"], "offline")

    def test_date_before_available_research_does_not_use_future_sentiment(self):
        insight = AAIISentimentService(fetcher=lambda: SAMPLE_HTML).get_insight(
            date(2026, 6, 1)
        )

        self.assertFalse(insight["available"])
        self.assertIsNone(insight["reading_date"])


if __name__ == "__main__":
    unittest.main()
