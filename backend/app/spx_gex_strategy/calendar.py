from __future__ import annotations

from datetime import date, datetime, time, timedelta
from functools import lru_cache
from zoneinfo import ZoneInfo

try:  # Optional in the developer checkout; required in production installs.
    import pandas as pd  # type: ignore
    import exchange_calendars as xcals  # type: ignore
except Exception:  # pragma: no cover - the standard-library fallback is tested.
    pd = None  # type: ignore
    xcals = None  # type: ignore


NEW_YORK = ZoneInfo("America/New_York")


def _nth_weekday(year: int, month: int, weekday: int, n: int) -> date:
    current = date(year, month, 1)
    offset = (weekday - current.weekday()) % 7
    return current + timedelta(days=offset + (n - 1) * 7)


def _last_weekday(year: int, month: int, weekday: int) -> date:
    if month == 12:
        current = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        current = date(year, month + 1, 1) - timedelta(days=1)
    return current - timedelta(days=(current.weekday() - weekday) % 7)


def _easter_sunday(year: int) -> date:
    # Meeus/Jones/Butcher Gregorian algorithm.
    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = ((h + l - 7 * m + 114) % 31) + 1
    return date(year, month, day)


def _observed_fixed(year: int, month: int, day: int) -> date:
    holiday = date(year, month, day)
    if holiday.weekday() == 5:
        return holiday - timedelta(days=1)
    if holiday.weekday() == 6:
        return holiday + timedelta(days=1)
    return holiday


@lru_cache(maxsize=32)
def _fallback_holidays(year: int) -> frozenset[date]:
    holidays = {
        _observed_fixed(year, 1, 1),  # New Year's Day
        _nth_weekday(year, 1, 0, 3),  # MLK Day
        _nth_weekday(year, 2, 0, 3),  # Presidents' Day
        _easter_sunday(year) - timedelta(days=2),  # Good Friday
        _last_weekday(year, 5, 0),  # Memorial Day
        _observed_fixed(year, 7, 4),  # Independence Day
        _nth_weekday(year, 9, 0, 1),  # Labor Day
        _nth_weekday(year, 11, 3, 4),  # Thanksgiving
        _observed_fixed(year, 12, 25),  # Christmas Day
    }
    if year >= 2022:
        holidays.add(_observed_fixed(year, 6, 19))  # Juneteenth
    return frozenset(holidays)


class USCashCalendar:
    """XNYS session helper with a deterministic fallback for local tests."""

    def __init__(self, timezone: str = "America/New_York") -> None:
        self.timezone_name = timezone
        self.timezone = ZoneInfo(timezone)
        self._calendar = None
        if xcals is not None and pd is not None:
            try:
                self._calendar = xcals.get_calendar("XNYS")
            except Exception:
                self._calendar = None

    def is_session(self, session_date: date) -> bool:
        if self._calendar is not None and pd is not None:
            try:
                return bool(self._calendar.is_session(pd.Timestamp(session_date)))
            except Exception:
                pass
        return session_date.weekday() < 5 and session_date not in _fallback_holidays(session_date.year)

    def previous_session(self, session_date: date, include_current: bool = False) -> date:
        candidate = session_date if include_current else session_date - timedelta(days=1)
        while not self.is_session(candidate):
            candidate -= timedelta(days=1)
        return candidate

    def next_session(self, session_date: date, include_current: bool = False) -> date:
        candidate = session_date if include_current else session_date + timedelta(days=1)
        while not self.is_session(candidate):
            candidate += timedelta(days=1)
        return candidate

    def session_offset(self, session_date: date, offset: int) -> date:
        result = session_date
        step = 1 if offset >= 0 else -1
        for _ in range(abs(offset)):
            result = self.next_session(result) if step > 0 else self.previous_session(result)
        return result

    def latest_completed_session(self, now: datetime | None = None) -> date:
        local_now = (now or datetime.now(self.timezone)).astimezone(self.timezone)
        # At 03:30 today the current cash session has not completed; using a
        # strict prior session also keeps this correct on weekends/holidays.
        return self.previous_session(local_now.date())

    def actionable_at(self, session_date: date, hour: int = 3, minute: int = 30) -> datetime:
        return datetime.combine(session_date, time(hour, minute), tzinfo=self.timezone)

    def cash_close(self, session_date: date) -> datetime:
        if self._calendar is not None and pd is not None:
            try:
                schedule = self._calendar.schedule(
                    start_date=pd.Timestamp(session_date), end_date=pd.Timestamp(session_date)
                )
                if not schedule.empty:
                    close = schedule.iloc[0]["market_close"]
                    return close.to_pydatetime().astimezone(self.timezone)
            except Exception:
                pass

        # NYSE's recurring early-close dates. The authoritative exchange
        # calendar is preferred above; this protects offline operation.
        close_time = time(16, 0)
        if session_date.weekday() == 4 and session_date.month == 11:
            thanksgiving = _nth_weekday(session_date.year, 11, 3, 4)
            if session_date == thanksgiving + timedelta(days=1):
                close_time = time(13, 0)
        if session_date.month == 7 and session_date.day == 3 and session_date.weekday() < 5:
            close_time = time(13, 0)
        if session_date.month == 12 and session_date.day == 24 and session_date.weekday() < 5:
            close_time = time(13, 0)
        return datetime.combine(session_date, close_time, tzinfo=self.timezone)

    def session_dates(self, start: date, end: date) -> list[date]:
        if end < start:
            return []
        return [
            current
            for days in range((end - start).days + 1)
            for current in [start + timedelta(days=days)]
            if self.is_session(current)
        ]

