"""Overview prompt uses current rolling time or a selected Sydney 16:00 window."""

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

    def test_selected_window_query_converts_sydney_clock_to_sql_datetimeoffset(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query, self.params = query, params
                return [{"MessageId": 1}]

        model = FakeModel()
        tz = ZoneInfo("Australia/Sydney")
        with patch.object(gex_data_service, "get_sql_model", return_value=model):
            rows = gex_data_service.GEXDataService().get_discord_messages_between(
                datetime(2026, 10, 20, 16, tzinfo=tz), datetime(2026, 10, 21, 16, tzinfo=tz)
            )
        self.assertEqual(len(rows), 1)
        self.assertEqual(model.params, (datetime(2026, 10, 20, 16), datetime(2026, 10, 21, 16)))
        self.assertIn("AT TIME ZONE 'AUS Eastern Standard Time'", model.query)
        self.assertIn("TimeStamp >=", model.query)
        self.assertIn("TimeStamp <", model.query)

    def test_historical_observation_date_uses_prior_16_to_selected_16_sydney(self):
        class FixedDatetime(datetime):
            @classmethod
            def now(cls, tz=None):
                return datetime(2026, 10, 22, 10, tzinfo=ZoneInfo("Australia/Sydney")).astimezone(tz)

        class FakeGex:
            def get_discord_messages_last_24_hours(self):
                raise AssertionError("Historical dates must not query current messages")

            def get_discord_messages_between(self, start, end):
                self.start, self.end = start, end
                return [{"MessageId": 1, "Content": "SPY bullish"}]

            def format_discord_messages_as_pipe_delimited(self, rows):
                return "MessageId|Content\n1|SPY bullish"

        gex = FakeGex()
        with patch.object(discord_summary, "datetime", FixedDatetime), patch.object(
            discord_summary, "DiscordMarketIntelligenceService", return_value=type("Fake", (), {"gex_service": gex})()
        ):
            response = discord_summary.get_discord_summary_prompt(
                observation_date=date(2026, 10, 21), username="test-user"
            )
        start = datetime.fromisoformat(response["window_start"])
        end = datetime.fromisoformat(response["window_end"])
        self.assertEqual(response["window_mode"], "selected_sydney_16_window")
        self.assertEqual(response["requested_observation_date"], "2026-10-21")
        self.assertEqual(response["observation_date"], "2026-10-21")
        self.assertEqual(start.isoformat(), "2026-10-20T16:00:00+11:00")
        self.assertEqual(end.isoformat(), "2026-10-21T16:00:00+11:00")
        self.assertEqual((gex.start, gex.end), (start, end))
        self.assertIn("SPY bullish", response["prompt"])
        self.assertIn("2026-10-21", response["prompt"])

    def test_sydney_dst_change_uses_calendar_dates_not_fixed_utc_hours(self):
        class FixedDatetime(datetime):
            @classmethod
            def now(cls, tz=None):
                return datetime(2026, 10, 22, 10, tzinfo=ZoneInfo("Australia/Sydney")).astimezone(tz)

        class FakeGex:
            def get_discord_messages_between(self, start, end):
                return [{"MessageId": 1, "Content": "test"}]

            def format_discord_messages_as_pipe_delimited(self, rows):
                return "test"

        with patch.object(discord_summary, "datetime", FixedDatetime), patch.object(
            discord_summary, "DiscordMarketIntelligenceService", return_value=type("Fake", (), {"gex_service": FakeGex()})()
        ):
            response = discord_summary.get_discord_summary_prompt(date(2026, 10, 4), username="test-user")
        start = datetime.fromisoformat(response["window_start"])
        end = datetime.fromisoformat(response["window_end"])
        self.assertEqual(start.isoformat(), "2026-10-03T16:00:00+10:00")
        self.assertEqual(end.isoformat(), "2026-10-04T16:00:00+11:00")
        self.assertEqual(end.astimezone(timezone.utc) - start.astimezone(timezone.utc), timedelta(hours=23))

    def test_today_date_still_queries_current_rolling_24h(self):
        class FixedDatetime(datetime):
            @classmethod
            def now(cls, tz=None):
                return datetime(2026, 10, 22, 10, tzinfo=ZoneInfo("Australia/Sydney")).astimezone(tz)

        class FakeGex:
            def get_discord_messages_last_24_hours(self):
                return [{"MessageId": 1, "Content": "live"}]

            def get_discord_messages_between(self, start, end):
                raise AssertionError("Today's date must remain current rolling 24h")

            def format_discord_messages_as_pipe_delimited(self, rows):
                return "live"

        with patch.object(discord_summary, "datetime", FixedDatetime), patch.object(
            discord_summary, "DiscordMarketIntelligenceService", return_value=type("Fake", (), {"gex_service": FakeGex()})()
        ):
            response = discord_summary.get_discord_summary_prompt(date(2026, 10, 22), username="test-user")
        self.assertEqual(response["window_mode"], "current_rolling_24h")
        self.assertEqual(response["requested_observation_date"], "2026-10-22")

    def test_http_selected_date_filters_historical_sydney_window(self):
        from fastapi.testclient import TestClient
        from app.main import app

        class FixedDatetime(datetime):
            @classmethod
            def now(cls, tz=None):
                return datetime(2026, 10, 22, 10, tzinfo=ZoneInfo("Australia/Sydney")).astimezone(tz)

        class FakeGex:
            def get_discord_messages_last_24_hours(self):
                raise AssertionError("HTTP selected date must not use live rows")

            def get_discord_messages_between(self, start, end):
                return [{"MessageId": 1, "Content": "historical"}]

            def format_discord_messages_as_pipe_delimited(self, rows):
                return "historical"

        app.dependency_overrides[discord_summary.verify_credentials] = lambda: "test-user"
        try:
            with patch.object(discord_summary, "datetime", FixedDatetime), patch.object(
                discord_summary, "DiscordMarketIntelligenceService",
                return_value=type("Fake", (), {"gex_service": FakeGex()})(),
            ):
                response = TestClient(app).get("/api/discord-summary-prompt?observation_date=2026-10-21")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["window_mode"], "selected_sydney_16_window")
            self.assertEqual(response.json()["window_start"], "2026-10-20T16:00:00+11:00")
            self.assertEqual(response.json()["window_end"], "2026-10-21T16:00:00+11:00")
        finally:
            app.dependency_overrides.pop(discord_summary.verify_credentials, None)

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
