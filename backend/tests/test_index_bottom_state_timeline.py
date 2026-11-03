from datetime import datetime
from zoneinfo import ZoneInfo

from app.services import index_bottom_state_timeline as timeline


REPORT = """# S&P 500 / Nasdaq-100 Short-Term Bottom Assessment
## Timestamps and cutoff
- **Requested cutoff:** 2026-10-30 16:09 America/New_York
## State
**Core state: Early watch, with failed/renewed pressure — not a reversal.**
- QQQ is oversold.
- SPY narrowly fails the core StochRSI threshold.
- Neither index has a fresh core reversal trigger.
**Raw confidence score:** **25/100 — No actionable setup / insufficiently confirmed**
**Evidence completeness:** approximately **11 of 12 score components directly observed**.
## Cash-bar indicators
unrelated
"""


def test_state_is_extracted_from_report_not_inferred():
    state = timeline.parse_report_state(REPORT)
    assert state["state"] == "Core state: Early watch, with failed/renewed pressure — not a reversal."
    assert "QQQ is oversold." in state["description"]
    assert "11 of 12 score components" in state["description"]
    assert "unrelated" not in state["description"]
    assert state["score"] == 25


def test_legacy_reports_use_stated_official_state_or_combined_table():
    legacy = """# Assessment
- **Requested cutoff:** 2026-03-30 17:00 America/New_York
- **Official state:** **Confirmed reversal — fragile**
## Core completed-cash state
QQQ had a prior trigger; this is not the state label.
"""
    assert timeline.parse_report_state(legacy)["state"] == "Official state: Confirmed reversal — fragile"
    table = """## State
| Complex | State |
|---|---|
| SPY | No setup |
| QQQ | No setup |
| Combined assessment | No actionable probable-bottom signal |
"""
    assert timeline.parse_report_state(table)["state"] == "Combined assessment: No actionable probable-bottom signal"


def test_report_as_at_is_new_york_time_and_not_generation_time():
    assert timeline.parse_as_at("2026-10-30 07:00 Australia/Sydney").isoformat() == "2026-10-29T16:00:00-04:00"
    assert timeline.parse_as_at("2026-01-06 07:00 Australia/Sydney").isoformat() == "2026-01-05T15:00:00-05:00"
    assert timeline.parse_as_at("2026-07-08 18:00 Sydney time").isoformat() == "2026-07-08T04:00:00-04:00"
    assert timeline.parse_as_at("2026-07-17 1:30pm US EST").isoformat() == "2026-07-17T13:30:00-04:00"


def test_paginated_state_endpoint_uses_report_cutoff_and_skips_generation_time(monkeypatch):
    from fastapi.testclient import TestClient
    from app.main import app
    from app.routers import skill_report_pages as routes
    from app.routers.auth import verify_credentials

    labels = {
        "latest": "2026-10-30 16:09 America/New_York",
        "older": "2026-10-30 07:00 Australia/Sydney",  # previous NY trading day
    }
    monkeypatch.setattr(routes, "list_reports", lambda _type: [
        {"job_id": key, "job_type": "find-index-bottoms", "status": "succeeded",
         "label": label, "created_at": "2026-11-15T00:00:00Z"}
        for key, label in labels.items()
    ])
    monkeypatch.setattr(routes, "get_job_report", lambda job: {"content": REPORT if job == "latest" else REPORT.replace(
        "2026-10-30 16:09 America/New_York", "2026-10-30 07:00 Australia/Sydney")})
    monkeypatch.setattr(routes, "load_index_bottom_price_rows", lambda _: [])
    routes._index_bottom_report_content.cache_clear()
    app.dependency_overrides[verify_credentials] = lambda: "test"
    try:
        response = TestClient(app).get("/api/find-index-bottoms-reports/states?page=1&page_size=1",
                                       headers={"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="})
        assert response.status_code == 200, response.text
        data = response.json()
        assert data["total"] == 2
        assert data["items"][0]["job_id"] == "latest"
        assert data["items"][0]["as_of_et"] == "2026-10-30T16:09:00-04:00"
        assert data["items"][0]["state"].startswith("Core state: Early watch")
        assert data["items"][0]["prices"]["SPY"]["returns"]["1"]["date"] == "2026-11-02"
        second = TestClient(app).get("/api/find-index-bottoms-reports/states?page=2&page_size=1",
                                     headers={"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}).json()["items"][0]
        assert second["job_id"] == "older"
        assert second["as_of_et"] == "2026-10-29T16:00:00-04:00"
        assert second["prices"]["QQQ"]["returns"]["1"]["date"] == "2026-10-30"
    finally:
        app.dependency_overrides.pop(verify_credentials, None)
        routes._index_bottom_report_content.cache_clear()


def test_next_trading_day_and_no_missing_day_substitution():
    # Friday 07:00 ET still has Monday as D1, not Friday's later close.
    as_at = datetime(2026, 10, 30, 7, tzinfo=ZoneInfo("America/New_York"))
    assert timeline.target_sessions(as_at)[1].isoformat() == "2026-11-02"
    assert timeline.target_sessions(as_at)[2].isoformat() == "2026-11-03"


def test_holiday_and_early_close_are_trading_sessions_not_calendar_days():
    as_at = datetime(2026, 11, 25, 16, tzinfo=ZoneInfo("America/New_York"))
    assert timeline.target_sessions(as_at)[1].isoformat() == "2026-11-27"  # Thanksgiving skipped
    rows = [
        {"ASXCode": "SPY.US", "TimeFrame": "5M", "TimeIntervalStart": datetime(2026, 11, 25, 15, 55), "Close": 100},
        {"ASXCode": "SPY.US", "TimeFrame": "5M", "TimeIntervalStart": datetime(2026, 11, 27, 12, 55), "Close": 105},
    ]
    assert timeline.calculate_returns(as_at, rows)["SPY"]["returns"]["1"]["percent"] == 5.0


def test_prices_use_last_completed_5m_else_recent_completed_30m_and_exact_daily_closes():
    as_at = datetime(2026, 10, 30, 16, 9, tzinfo=ZoneInfo("America/New_York"))
    rows = [
        {"ASXCode": "SPY.US", "TimeFrame": "5M", "TimeIntervalStart": datetime(2026, 10, 30, 15, 55), "Close": 700},
        {"ASXCode": "SPY.US", "TimeFrame": "5M", "TimeIntervalStart": datetime(2026, 10, 30, 16, 5), "Close": 701},
        {"ASXCode": "SPY.US", "TimeFrame": "30M", "TimeIntervalStart": datetime(2026, 10, 30, 15, 30), "Close": 702},
        {"ASXCode": "QQQ.US", "TimeFrame": "5M", "TimeIntervalStart": datetime(2026, 10, 29, 15, 55), "Close": 690},
        {"ASXCode": "QQQ.US", "TimeFrame": "30M", "TimeIntervalStart": datetime(2026, 10, 30, 15, 30), "Close": 700},
        {"ASXCode": "QQQ.US", "TimeFrame": "30M", "TimeIntervalStart": datetime(2026, 10, 30, 16, 0), "Close": 710},
        {"ASXCode": "SPY.US", "TimeFrame": "5M", "TimeIntervalStart": datetime(2026, 11, 2, 15, 55), "Close": 735},
        {"ASXCode": "QQQ.US", "TimeFrame": "30M", "TimeIntervalStart": datetime(2026, 11, 2, 15, 30), "Close": 735},
    ]
    result = timeline.calculate_returns(as_at, rows)
    assert result["SPY"]["base"]["price"] == 700
    assert result["SPY"]["base"]["timeframe"] == "5M"
    assert result["QQQ"]["base"]["price"] == 700  # a stale 5M does not override a current 30M
    assert result["QQQ"]["base"]["timeframe"] == "30M"
    assert result["SPY"]["returns"]["1"]["percent"] == 5.0
    assert result["QQQ"]["returns"]["1"]["percent"] == 5.0
    assert result["SPY"]["returns"]["2"]["percent"] is None  # no D2 price: never use D1
    assert result["SPY"]["returns"]["2"]["date"] == "2026-11-03"
