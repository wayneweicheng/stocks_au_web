"""The overview prompt is a live 24-hour extract; other summaries keep their date windows."""

import unittest
from datetime import date, datetime, timedelta, timezone
from unittest.mock import patch
from zoneinfo import ZoneInfo

from app.routers import discord_summary
from app.services import gex_data_service


class DiscordSummaryPromptTests(unittest.TestCase):
    def test_live_prompt_extract_uses_offset_aware_clock_and_sydney_display(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query = query
                self.params = params
                return [{"MessageId": 1, "Content": "SPY"}]

        model = FakeModel()
        with patch.object(gex_data_service, "get_sql_model", return_value=model):
            rows = gex_data_service.GEXDataService().get_discord_messages_last_24_hours()

        self.assertEqual(len(rows), 1)
        self.assertEqual(model.params, ())
        self.assertIn("TimeStamp > DATEADD(hour, -24, SYSDATETIMEOFFSET())", model.query)
        self.assertIn("TimeStamp AT TIME ZONE 'AUS Eastern Standard Time'", model.query)
        self.assertNotIn("GETDATE()", model.query)
        self.assertNotIn("CAST(TimeStamp AS datetime) >", model.query)
        self.assertNotIn("UserName IN", model.query)

    def test_overview_prompt_ignores_legacy_date_and_discloses_current_window(self):
        class FakeGex:
            def get_discord_messages_last_24_hours(self):
                return [{"MessageId": 1, "Content": "SPY bullish"}]

            def get_discord_messages_between(self, start, end):
                raise AssertionError("Selected-date extraction must not run")

            def format_discord_messages_as_pipe_delimited(self, rows):
                return "MessageId|Content\n1|SPY bullish"

        class FakeService:
            gex_service = FakeGex()

        with patch.object(discord_summary, "DiscordMarketIntelligenceService", return_value=FakeService()):
            response = discord_summary.get_discord_summary_prompt(
                observation_date=date(2020, 1, 1), username="test-user"
            )

        start = datetime.fromisoformat(response["window_start"])
        end = datetime.fromisoformat(response["window_end"])
        self.assertEqual(response["window_mode"], "current_rolling_24h")
        self.assertEqual(response["requested_observation_date"], "2020-01-01")
        self.assertEqual(start.utcoffset(), start.astimezone(ZoneInfo("Australia/Sydney")).utcoffset())
        self.assertEqual(end.astimezone(timezone.utc) - start.astimezone(timezone.utc), timedelta(hours=24))
        self.assertEqual(response["observation_date"], end.date().isoformat())
        self.assertIn("SPY bullish", response["prompt"])
        self.assertNotIn("2020-01-01", response["prompt"])

    def test_http_prompt_needs_no_observation_date(self):
        from fastapi.testclient import TestClient
        from app.main import app

        class FakeGex:
            def get_discord_messages_last_24_hours(self):
                return [{"MessageId": 1, "Content": "SPY bullish"}]

            def format_discord_messages_as_pipe_delimited(self, rows):
                return "MessageId|Content\n1|SPY bullish"

        class FakeService:
            gex_service = FakeGex()

        app.dependency_overrides[discord_summary.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(discord_summary, "DiscordMarketIntelligenceService", return_value=FakeService()):
                response = TestClient(app).get("/api/discord-summary-prompt")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["window_mode"], "current_rolling_24h")
        finally:
            app.dependency_overrides.pop(discord_summary.verify_credentials, None)


if __name__ == "__main__":
    unittest.main()
