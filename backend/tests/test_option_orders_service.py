from datetime import date, datetime, timedelta, timezone
import sys
import types
import unittest

config_stub = types.ModuleType("app.core.config")
config_stub.settings = types.SimpleNamespace(ibg_api_host="127.0.0.1", ibg_api_port=4002)
db_stub = types.ModuleType("app.core.db")
db_stub.get_sql_model = lambda: None
sys.modules.setdefault("app.core.config", config_stub)
sys.modules.setdefault("app.core.db", db_stub)

from app.services.option_orders_service import (
    OptionQuote,
    _dte,
    _market_status_from_context,
    _merge_option_quote,
    _today_us_market_date,
)


class OptionOrdersServiceTests(unittest.TestCase):
    def test_market_date_uses_us_eastern_not_sydney_calendar_day(self):
        sydney_morning = datetime(2026, 6, 17, 14, 15, tzinfo=timezone.utc)

        self.assertEqual(_today_us_market_date(sydney_morning), date(2026, 6, 17))

    def test_dte_can_be_calculated_from_us_market_date(self):
        self.assertEqual(_dte("20260702", today=date(2026, 6, 17)), 15)

    def test_market_status_live_during_regular_session_with_realtime_data(self):
        now = datetime(2026, 6, 17, 10, 15, tzinfo=timezone(timedelta(hours=-4)))

        status = _market_status_from_context(market_data_type=1, now=now)

        self.assertTrue(status["is_live_market"])
        self.assertEqual(status["label"], "Live Market")

    def test_market_status_not_live_before_regular_session(self):
        now = datetime(2026, 6, 17, 8, 45, tzinfo=timezone(timedelta(hours=-4)))

        status = _market_status_from_context(market_data_type=1, now=now)

        self.assertFalse(status["is_live_market"])
        self.assertEqual(status["label"], "Market Not Live")
        self.assertIn("regular US market hours", status["detail"])

    def test_market_status_not_live_when_ib_returns_delayed_data(self):
        now = datetime(2026, 6, 17, 10, 15, tzinfo=timezone(timedelta(hours=-4)))

        status = _market_status_from_context(market_data_type=3, now=now)

        self.assertFalse(status["is_live_market"])
        self.assertEqual(status["label"], "Market Not Live")
        self.assertIn("not returning real-time", status["detail"])

    def test_merge_option_quote_prefers_live_bid_ask_and_keeps_database_volume(self):
        delayed_quote = {
            "bid": 1.0,
            "ask": 1.2,
            "mid": 1.1,
            "spread_pct": 20.0,
            "volume": 42,
            "iv": 0.35,
            "observation_date": "2026-06-16",
            "source": "database",
        }
        live_quote = OptionQuote(
            bid=1.05,
            ask=1.10,
            last=None,
            close=None,
            mid=1.075,
            iv=0.36,
            delta=None,
            gamma=None,
            theta=None,
            vega=None,
            market_data_type=1,
        )

        merged = _merge_option_quote(delayed_quote, live_quote, prefer_live=True)

        self.assertEqual(merged["bid"], 1.05)
        self.assertEqual(merged["ask"], 1.10)
        self.assertEqual(merged["mid"], 1.075)
        self.assertEqual(merged["volume"], 42)
        self.assertEqual(merged["source"], "live")
        self.assertEqual(merged["market_data_type"], 1)

    def test_merge_option_quote_uses_database_when_not_live(self):
        delayed_quote = {
            "bid": 1.0,
            "ask": 1.2,
            "mid": 1.1,
            "spread_pct": 20.0,
            "volume": 42,
            "iv": 0.35,
            "observation_date": "2026-06-16",
            "source": "database",
        }
        live_quote = OptionQuote(
            bid=1.05,
            ask=1.10,
            last=None,
            close=None,
            mid=1.075,
            iv=0.36,
            delta=None,
            gamma=None,
            theta=None,
            vega=None,
            market_data_type=1,
        )

        merged = _merge_option_quote(delayed_quote, live_quote, prefer_live=False)

        self.assertEqual(merged["bid"], 1.0)
        self.assertEqual(merged["ask"], 1.2)
        self.assertEqual(merged["mid"], 1.1)
        self.assertEqual(merged["source"], "database")


if __name__ == "__main__":
    unittest.main()
