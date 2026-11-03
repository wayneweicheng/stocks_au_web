import unittest
from datetime import date, datetime
from unittest.mock import patch
from zoneinfo import ZoneInfo

from app.routers import discord_summary
from app.services import gex_data_service


class DiscordMessageExtractorTests(unittest.TestCase):
    def test_daily_counts_query_groups_by_sydney_16_to_16_observation_date(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query, self.params = query, params
                return [{"ChannelId": 7, "ChannelName": "Index", "ObservationDate": date(2026, 10, 21), "MessageCount": 3}]

        model = FakeModel()
        start = datetime(2026, 10, 19, 16, tzinfo=ZoneInfo("Australia/Sydney"))
        end = datetime(2026, 10, 22, 16, tzinfo=ZoneInfo("Australia/Sydney"))
        with patch.object(gex_data_service, "get_sql_model", return_value=model):
            rows = gex_data_service.GEXDataService().get_discord_channel_daily_counts(start, end)

        self.assertEqual(len(rows), 1)
        self.assertEqual(model.params, (datetime(2026, 10, 19, 16), datetime(2026, 10, 22, 16)))
        self.assertIn("DiscordChannels", model.query)
        self.assertIn("DATEADD(hour, -16", model.query)
        self.assertIn("AT TIME ZONE 'AUS Eastern Standard Time'", model.query)

    def test_selected_channel_messages_use_exact_half_open_sydney_window(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query, self.params = query, params
                return [{"MessageId": 12, "ChannelId": 7, "Content": "QQQ level"}]

        model = FakeModel()
        start = datetime(2026, 10, 20, 16, tzinfo=ZoneInfo("Australia/Sydney"))
        end = datetime(2026, 10, 21, 16, tzinfo=ZoneInfo("Australia/Sydney"))
        with patch.object(gex_data_service, "get_sql_model", return_value=model):
            rows = gex_data_service.GEXDataService().get_discord_messages_for_channel(7, start, end)

        self.assertEqual(rows[0]["MessageId"], 12)
        self.assertEqual(model.params, (7, datetime(2026, 10, 20, 16), datetime(2026, 10, 21, 16)))
        self.assertIn("m.ChannelId = ?", model.query)
        self.assertIn("ORDER BY m.TimeStamp ASC", model.query)

    def test_multiple_selected_observation_days_are_read_in_one_channel_query(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query, self.params = query, params
                return [{"MessageId": 4, "ChannelId": 7, "Content": "selected"}]

        model = FakeModel()
        with patch.object(gex_data_service, "get_sql_model", return_value=model):
            rows = gex_data_service.GEXDataService().get_discord_messages_for_channel_days(
                7, [date(2026, 10, 21), date(2026, 10, 19), date(2026, 10, 21)]
            )

        self.assertEqual(rows[0]["Content"], "selected")
        self.assertEqual(model.params, (
            7,
            datetime(2026, 10, 18, 16), datetime(2026, 10, 19, 16),
            datetime(2026, 10, 20, 16), datetime(2026, 10, 21, 16),
        ))
        self.assertEqual(model.query.count("m.TimeStamp >="), 2)
        self.assertIn(" OR ", model.query)

    def test_index_returns_all_channels_and_zero_filled_daily_counts(self):
        class FixedDatetime(datetime):
            @classmethod
            def now(cls, tz=None):
                return datetime(2026, 10, 22, 10, tzinfo=ZoneInfo("Australia/Sydney")).astimezone(tz)

        class FakeGex:
            def get_discord_channels(self):
                return [
                    {"ChannelId": 7, "ChannelName": "Index", "IsActive": True},
                    {"ChannelId": 8, "ChannelName": "Options", "IsActive": False},
                ]

            def get_discord_channel_daily_counts(self, start, end):
                self.start, self.end = start, end
                return [{"ChannelId": 7, "ObservationDate": date(2026, 10, 21), "MessageCount": 4}]

            def get_discord_earliest_observation_date(self):
                return date(2026, 10, 1)

        gex = FakeGex()
        fake_service = type("FakeService", (), {"gex_service": gex})()
        with patch.object(discord_summary, "datetime", FixedDatetime), patch.object(
            discord_summary, "DiscordMarketIntelligenceService", return_value=fake_service
        ):
            result = discord_summary.get_discord_message_extract_index(days=3, end_observation_date=None, username="tester")

        self.assertEqual(result["dates"], ["2026-10-20", "2026-10-21", "2026-10-22"])
        self.assertEqual(result["channels"][0]["daily_counts"], {"2026-10-20": 0, "2026-10-21": 4, "2026-10-22": 0})
        self.assertFalse(result["channels"][1]["is_active"])
        self.assertTrue(result["has_earlier"])
        self.assertEqual(result["earliest_observation_date"], "2026-10-01")
        self.assertEqual(gex.start, datetime(2026, 10, 19, 16, tzinfo=ZoneInfo("Australia/Sydney")))
        self.assertEqual(gex.end, datetime(2026, 10, 22, 16, tzinfo=ZoneInfo("Australia/Sydney")))

    def test_http_prompt_accepts_repeated_selected_observation_dates(self):
        from fastapi.testclient import TestClient
        from app.main import app

        class FakeGex:
            def get_discord_messages_for_channel_days(self, channel_id, observation_dates):
                self.args = (channel_id, observation_dates)
                return [
                    {"MessageId": 21, "ChannelName": "Index", "TimeStamp_Sydney": datetime(2026, 10, 20, 9), "Content": "one"},
                    {"MessageId": 22, "ChannelName": "Index", "TimeStamp_Sydney": datetime(2026, 10, 21, 9), "Content": "two"},
                ]

        gex = FakeGex()
        fake_service = type("FakeService", (), {"gex_service": gex})()
        app.dependency_overrides[discord_summary.verify_credentials] = lambda: "tester"
        try:
            with patch.object(discord_summary, "DiscordMarketIntelligenceService", return_value=fake_service):
                response = TestClient(app).get("/api/discord-message-extract/prompt", params=[
                    ("channel_id", "7"),
                    ("observation_dates", "2026-10-21"),
                    ("observation_dates", "2026-10-20"),
                ])
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["observation_dates"], ["2026-10-20", "2026-10-21"])
            self.assertEqual(gex.args, (7, [date(2026, 10, 20), date(2026, 10, 21)]))
        finally:
            app.dependency_overrides.pop(discord_summary.verify_credentials, None)

    def test_get_prompt_includes_messages_from_multiple_selected_dates(self):
        class FakeGex:
            def get_discord_messages_for_channel_days(self, channel_id, observation_dates):
                self.args = (channel_id, observation_dates)
                return [
                    {"MessageId": 101, "ChannelName": "Index", "TimeStamp_Sydney": datetime(2026, 10, 20, 17), "UserName": "A", "Content": "first day"},
                    {"MessageId": 102, "ChannelName": "Index", "TimeStamp_Sydney": datetime(2026, 10, 21, 17), "UserName": "B", "Content": "second day"},
                ]

        gex = FakeGex()
        fake_service = type("FakeService", (), {"gex_service": gex})()
        with patch.object(discord_summary, "DiscordMarketIntelligenceService", return_value=fake_service):
            result = discord_summary.get_discord_channel_day_prompt(
                7, None, "tester", observation_dates=[date(2026, 10, 21), date(2026, 10, 20)]
            )

        self.assertEqual(gex.args, (7, [date(2026, 10, 20), date(2026, 10, 21)]))
        self.assertEqual(result["message_count"], 2)
        self.assertEqual(result["observation_dates"], ["2026-10-20", "2026-10-21"])
        self.assertIn('"observation_date": "2026-10-20"', result["prompt"])
        self.assertIn('"observation_date": "2026-10-21"', result["prompt"])
        self.assertIn("first day", result["prompt"])
        self.assertIn("second day", result["prompt"])

    def test_get_prompt_embeds_only_selected_channel_day_messages(self):
        class FakeGex:
            def get_discord_messages_for_channel_days(self, channel_id, observation_dates):
                self.args = (channel_id, observation_dates)
                return [
                    {"MessageId": 99, "ChannelName": "Index", "TimeStamp_Sydney": datetime(2026, 10, 21, 9, 30), "UserName": "TraderA", "Content": "QQQ may retest 500"},
                    {"MessageId": 100, "ChannelName": "Index", "TimeStamp_Sydney": datetime(2026, 10, 21, 10, 0), "UserName": "TraderB", "Content": "disagree"},
                ]

        gex = FakeGex()
        fake_service = type("FakeService", (), {"gex_service": gex})()
        with patch.object(discord_summary, "DiscordMarketIntelligenceService", return_value=fake_service):
            result = discord_summary.get_discord_channel_day_prompt(7, date(2026, 10, 21), "tester", observation_dates=None)

        self.assertEqual(result["message_count"], 2)
        self.assertIn('"message_id": "99"', result["prompt"])
        self.assertIn("QQQ may retest 500", result["prompt"])
        self.assertIn("disagree", result["prompt"])
        self.assertIn("untrusted source material", result["prompt"])
        self.assertEqual(result["observation_dates"], ["2026-10-21"])
        self.assertEqual(result["windows"][0]["observation_date"], "2026-10-21")
        self.assertEqual(gex.args, (7, [date(2026, 10, 21)]))


if __name__ == "__main__":
    unittest.main()
