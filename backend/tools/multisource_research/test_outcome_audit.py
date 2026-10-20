"""Pure tests for source-bar outcome reconstruction used by Stage 1 audit."""
from __future__ import annotations

import importlib.util
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path
import unittest

SCRIPT = Path(__file__).with_name("audit_oos_outcomes.py")
spec = importlib.util.spec_from_file_location("audit_oos_outcomes", SCRIPT)
audit = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = audit
spec.loader.exec_module(audit)


class FakeCalendar:
    def session_offset(self, start: date, offset: int) -> date:
        current = start
        direction = 1 if offset >= 0 else -1
        for _ in range(abs(offset)):
            current += timedelta(days=direction)
            while current.weekday() >= 5:
                current += timedelta(days=direction)
        return current

    def cash_close(self, session: date) -> datetime:
        return datetime.combine(session, time(16, 0))


def bar(day: date, clock: time, opening: float, close: float) -> dict:
    stamp = datetime.combine(day, clock)
    return {"TimeIntervalStart": stamp, "Open": opening, "Close": close, "High": max(opening, close), "Low": min(opening, close)}


class OutcomeAuditTests(unittest.TestCase):
    def test_long_return_uses_next_session_0730_and_horizon_close(self):
        d0 = date(2026, 9, 1)
        bars = [
            bar(date(2026, 9, 2), time(7, 0), 90, 91),
            bar(date(2026, 9, 2), time(7, 30), 100, 101),
            bar(date(2026, 9, 2), time(11, 30), 105, 106),
            bar(date(2026, 9, 3), time(15, 30), 108, 109),
            bar(date(2026, 9, 4), time(15, 30), 109, 110),
        ]
        result = audit.expected_prices({"MarketDate": d0, "HoldingPeriodCode": "D3", "Direction": "LONG"}, bars, FakeCalendar())
        self.assertEqual(result["expected_entry_price"], 100)
        self.assertEqual(result["expected_exit_price"], 110)
        self.assertAlmostEqual(result["reconstructed_raw_return_pct"], 10)
        self.assertAlmostEqual(result["reconstructed_directional_return_pct"], 10)

    def test_short_direction_changes_sign_not_raw_return(self):
        bars = [bar(date(2026, 9, 2), time(7, 30), 100, 100), bar(date(2026, 9, 4), time(15, 30), 90, 90)]
        result = audit.expected_prices({"MarketDate": date(2026, 9, 1), "HoldingPeriodCode": "D3", "Direction": "SHORT"}, bars, FakeCalendar())
        self.assertAlmostEqual(result["reconstructed_raw_return_pct"], -10)
        self.assertAlmostEqual(result["reconstructed_directional_return_pct"], 10)

    def test_missing_entry_or_exit_is_not_a_zero_return(self):
        entry_missing = audit.expected_prices({"MarketDate": date(2026, 9, 1), "HoldingPeriodCode": "D3", "Direction": "LONG"}, [], FakeCalendar())
        self.assertEqual(entry_missing["audit_status"], "MISSING_ENTRY_BAR")
        missing_exit = audit.expected_prices({"MarketDate": date(2026, 9, 1), "HoldingPeriodCode": "D3", "Direction": "LONG"}, [bar(date(2026, 9, 2), time(7, 30), 100, 100)], FakeCalendar())
        self.assertEqual(missing_exit["audit_status"], "MISSING_EXIT_BAR")

    def test_uses_first_bar_after_entry_gate_if_exact_0730_missing_and_flags_it(self):
        bars = [bar(date(2026, 9, 2), time(8, 0), 101, 102), bar(date(2026, 9, 4), time(15, 30), 105, 106)]
        result = audit.expected_prices({"MarketDate": date(2026, 9, 1), "HoldingPeriodCode": "D3", "Direction": "LONG"}, bars, FakeCalendar())
        self.assertEqual(result["expected_entry_time"], "2026-09-02 08:00:00")
        self.assertFalse(result["entry_timestamp_exact_0730"])


if __name__ == "__main__":
    unittest.main()
