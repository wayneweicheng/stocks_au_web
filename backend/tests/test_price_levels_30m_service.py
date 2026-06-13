import unittest
from datetime import date, datetime, timedelta

from app.services.price_levels_30m_service import (
    _calculate_levels,
    _select_reasonable_levels,
    _should_use_live_prices,
)


def _bars():
    start = datetime(2026, 6, 10, 9, 30)
    values = [
        (99, 97, 98),
        (101, 96, 100),
        (103, 99, 102),
        (105, 101, 104),
        (104, 100, 101),
        (103, 98, 100),
    ]
    return [
        {
            "TimeIntervalStart": start + timedelta(minutes=30 * index),
            "High": high,
            "Low": low,
            "Close": close,
            "Volume": 1000,
        }
        for index, (high, low, close) in enumerate(values)
    ]


def _daily_bars():
    start = datetime(2026, 5, 20)
    return [
        {
            "ObservationDate": start + timedelta(days=index),
            "High": 103 + index % 3,
            "Low": 97 - index % 2,
            "Close": 100 + index % 2,
        }
        for index in range(20)
    ]


class PriceLevels30mTests(unittest.TestCase):
    def test_live_price_date_policy(self):
        market_today = date(2026, 6, 12)
        recent_trading_dates = [
            date(2026, 6, 12),
            date(2026, 6, 11),
            date(2026, 6, 10),
            date(2026, 6, 9),
        ]

        self.assertTrue(_should_use_live_prices(market_today, market_today, recent_trading_dates))
        self.assertTrue(
            _should_use_live_prices(date(2026, 6, 11), market_today, recent_trading_dates)
        )
        self.assertTrue(
            _should_use_live_prices(date(2026, 6, 10), market_today, recent_trading_dates)
        )
        self.assertFalse(
            _should_use_live_prices(date(2026, 6, 9), market_today, recent_trading_dates)
        )

    def test_live_price_drives_sides_while_last_close_drives_distances(self):
        result = _calculate_levels(
            "TEST.US",
            _bars(),
            _daily_bars(),
            gamma_walls={
                "puts": [{"strike": 102, "open_interest": 5000, "nearest_expiry": "2026-06-19"}],
                "calls": [{"strike": 108, "open_interest": 5000, "nearest_expiry": "2026-06-19"}],
            },
            reference_price=106,
            price_source="ib_live",
            minimum_distance_atr=0,
        )

        self.assertIsNotNone(result)
        self.assertEqual(result["latest_close"], 100)
        self.assertEqual(result["reference_price"], 106)
        self.assertEqual(result["price_source"], "ib_live")
        self.assertTrue(all(level["price"] < 106 for level in result["supports"]))
        self.assertTrue(all(level["price"] > 106 for level in result["resistances"]))
        self.assertTrue(any(level["distance_pct"] > 0 for level in result["supports"]))
        for level in result["supports"] + result["resistances"]:
            expected_pct = round((level["price"] - result["latest_close"]) / result["latest_close"] * 100, 2)
            expected_atr = round(
                abs(level["price"] - result["latest_close"]) / result["atr_daily"],
                2,
            )
            self.assertEqual(level["distance_pct"], expected_pct)
            self.assertEqual(level["distance_atr"], expected_atr)

    def test_historical_calculation_uses_latest_30m_close(self):
        result = _calculate_levels("TEST.US", _bars(), _daily_bars())

        self.assertIsNotNone(result)
        self.assertEqual(result["latest_close"], 100)
        self.assertEqual(result["reference_price"], 100)
        self.assertEqual(result["price_source"], "30m_close")

    def test_atr_range_filters_levels_before_selecting_best_two(self):
        levels = [
            {"price": 99.8},
            {"price": 99.4},
            {"price": 98.8},
            {"price": 98.0},
        ]

        selected = _select_reasonable_levels(
            levels,
            latest_close=100,
            atr_daily=2,
            minimum_distance_atr=0.25,
            maximum_distance_atr=0.75,
        )

        self.assertEqual([level["price"] for level in selected], [99.4, 98.8])
        self.assertAlmostEqual(selected[0]["distance_atr"], 0.3)
        self.assertAlmostEqual(selected[1]["distance_atr"], 0.6)

    def test_quality_ranking_beats_proximity_within_atr_range(self):
        now = datetime(2026, 6, 12, 15, 30)
        levels = [
            {
                "price": 99.8,
                "touches": 1,
                "latest_touch": now,
                "sources": ["30m"],
            },
            {
                "price": 99.0,
                "touches": 4,
                "latest_touch": now - timedelta(days=1),
                "sources": ["30m"],
            },
            {
                "price": 98.5,
                "touches": 2,
                "latest_touch": now - timedelta(days=2),
                "sources": ["30m", "gamma"],
                "gamma_wall": {"open_interest": 5000},
            },
        ]

        selected = _select_reasonable_levels(
            levels,
            latest_close=100,
            atr_daily=2,
            minimum_distance_atr=0,
            maximum_distance_atr=1,
        )

        self.assertEqual([level["price"] for level in selected], [98.5, 99.0])

    def test_recency_and_distance_only_break_quality_ties(self):
        now = datetime(2026, 6, 12, 15, 30)
        levels = [
            {
                "price": 99.8,
                "touches": 2,
                "latest_touch": now - timedelta(days=2),
                "sources": ["30m"],
            },
            {
                "price": 99.0,
                "touches": 2,
                "latest_touch": now,
                "sources": ["30m"],
            },
            {
                "price": 98.8,
                "touches": 2,
                "latest_touch": now,
                "sources": ["30m"],
            },
        ]

        selected = _select_reasonable_levels(
            levels,
            latest_close=100,
            atr_daily=2,
            minimum_distance_atr=0,
            maximum_distance_atr=1,
        )

        self.assertEqual([level["price"] for level in selected], [99.0, 98.8])

    def test_calculation_reports_custom_atr_range(self):
        result = _calculate_levels(
            "TEST.US",
            _bars(),
            _daily_bars(),
            minimum_distance_atr=0.1,
            maximum_distance_atr=1.5,
        )

        self.assertIsNotNone(result)
        self.assertEqual(
            result["reasonable_distance_atr"],
            {"minimum": 0.1, "maximum": 1.5},
        )


if __name__ == "__main__":
    unittest.main()
