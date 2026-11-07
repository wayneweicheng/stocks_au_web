import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import Mock, patch
from zoneinfo import ZoneInfo

from app.services import market_aware_stock_price_service as market_prices


EASTERN = ZoneInfo("America/New_York")


class MarketAwareStockPriceServiceTests(unittest.TestCase):
    def test_market_mode_boundaries_use_eastern_time(self):
        cases = [
            (datetime(2026, 1, 2, 7, 59, tzinfo=EASTERN), "smart"),
            (datetime(2026, 1, 2, 8, 0, tzinfo=EASTERN), "weekend_30m"),
            (datetime(2026, 1, 3, 12, 0, tzinfo=EASTERN), "weekend_30m"),
            (datetime(2026, 1, 4, 19, 59, tzinfo=EASTERN), "weekend_30m"),
            (datetime(2026, 1, 4, 20, 0, tzinfo=EASTERN), "overnight"),
            (datetime(2026, 1, 5, 3, 59, tzinfo=EASTERN), "overnight"),
            (datetime(2026, 1, 5, 4, 0, tzinfo=EASTERN), "smart"),
            (datetime(2026, 1, 5, 20, 0, tzinfo=EASTERN), "overnight"),
        ]
        for timestamp, expected in cases:
            with self.subTest(timestamp=timestamp):
                self.assertEqual(market_prices.market_price_mode(timestamp), expected)

    def test_weekend_uses_database_30m_snapshot_and_never_calls_ib(self):
        quote_loader = Mock(side_effect=AssertionError("weekend uses database"))
        history_loader = Mock(return_value=({"SPY": 700.25}, {"SPY": "2026-01-02T15:30:00"}))
        service = market_prices.MarketAwareStockPriceService(
            live_quote_loader=quote_loader, history_loader=history_loader,
            clock=lambda: datetime(2026, 1, 3, 12, 0, tzinfo=EASTERN),
        )

        snapshot = service.get_prices(["spy", "QQQ"])

        self.assertEqual(snapshot.prices, {"SPY": 700.25, "QQQ": None})
        self.assertEqual(snapshot.price_sources, {"SPY": "database_30m"})
        self.assertEqual(snapshot.price_times, {"SPY": "2026-01-02T15:30:00"})
        self.assertEqual(snapshot.exchange, None)
        history_loader.assert_called_once_with(["SPY", "QQQ"])
        quote_loader.assert_not_called()

    def test_overnight_and_smart_use_corresponding_ib_exchange_and_only_live_quotes(self):
        for timestamp, exchange in [
            (datetime(2026, 1, 5, 21, 0, tzinfo=EASTERN), "OVERNIGHT"),
            (datetime(2026, 1, 5, 12, 0, tzinfo=EASTERN), "SMART"),
        ]:
            quote_loader = Mock(return_value={
                "SPY": {"price": 700.5, "source": "ib_live"},
                "QQQ": {"price": 600.5, "source": "ib_delayed"},
            })
            service = market_prices.MarketAwareStockPriceService(
                live_quote_loader=quote_loader, history_loader=Mock(),
                clock=lambda: timestamp,
            )
            with self.subTest(exchange=exchange):
                snapshot = service.get_prices(["SPY", "QQQ"])
                self.assertEqual(snapshot.prices, {"SPY": 700.5, "QQQ": None})
                self.assertEqual(snapshot.price_sources, {"SPY": "ib_live"})
                self.assertEqual(snapshot.exchange, exchange)
                quote_loader.assert_called_once_with(
                    ["SPY", "QQQ"], wait_seconds=2.0,
                    connect_timeout=market_prices.QUOTE_CONNECT_TIMEOUT_SECONDS,
                    allow_close_fallback=False, quote_only=True, exchange=exchange,
                )

    def test_database_loader_queries_latest_30m_per_symbol_alias(self):
        class FakeModel:
            def execute_read_query(self, query, params):
                self.query, self.params = query, params
                return [
                    {"ASXCode": "SPY.US", "Close": 700.25, "TimeIntervalStart": datetime(2026, 1, 2, 15, 30)},
                    {"ASXCode": "QQQ", "Close": 600.5, "TimeIntervalStart": datetime(2026, 1, 2, 16, 0)},
                ]

        model = FakeModel()
        with patch.object(market_prices, "_open_saved_price_levels_model", return_value=model), patch.object(
            market_prices, "_close_saved_price_levels_model"
        ) as close:
            prices, times = market_prices._load_latest_30m_prices(["SPY", "QQQ"])

        self.assertEqual(prices, {"SPY": 700.25, "QQQ": 600.5})
        self.assertEqual(times["SPY"], "2026-01-02T15:30:00")
        self.assertIn("TimeFrame = CONVERT(varchar(10), ?)", model.query)
        self.assertEqual(model.params[0], "30M")
        close.assert_called_once_with(model)

    def test_invalid_symbols_are_rejected_before_quote_lookup(self):
        quote_loader = Mock()
        service = market_prices.MarketAwareStockPriceService(live_quote_loader=quote_loader)
        with self.assertRaises(ValueError):
            service.get_prices(["SPY; DROP TABLE T"])
        quote_loader.assert_not_called()


if __name__ == "__main__":
    unittest.main()
