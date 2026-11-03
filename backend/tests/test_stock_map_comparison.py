"""Two-date Stock Map comparison through the authenticated API boundary."""
from datetime import datetime
import json

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages

AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


@pytest.fixture(autouse=True)
def no_live_sql_option_reads(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "load_d1_option_rows", lambda symbol, d1, obs, ref: {
        "source": "StockDB_US.StockData.v_OptionDelayedQuote_V2", "observation_date": d1.isoformat(),
        "spot_reference_from_d1": ref, "status": "no_valid_pair", "option_rows": [],
    })


def _report(job_id, date, hour=6, stock="FORM"):
    return {"job_id": job_id, "status": "succeeded", "stock_code": stock,
            "label": f"{stock}:{date} {hour:02d}:30 America/New_York",
            "created_at": f"{date}T{hour:02d}:30:00-04:00",
            "report_path": f"stock_map_{stock}_{date.replace('-', '')}_{hour:02d}30_ET.html"}


def _json(job_id, date, stock="FORM"):
    return {"job_id": job_id, "content": {
        "ticker": stock, "as_of_et": f"{date}T06:30:00-04:00",
        "execution_reference": 101.0, "execution_reference_type": "completed_30m_bar",
        "primary_supports": [{"rank": 1, "zone_low": 97, "zone_high": 99,
                              "core_anchor_price": 98, "total_score": 72,
                              "main_evidence": ["daily pivot"]}],
        "primary_resistances": [{"rank": 1, "zone_low": 104, "zone_high": 106,
                                 "core_anchor_price": 105, "total_score": 63}],
        "orders": [{"direction": "long", "entry_zone": [97, 99], "targets": [105],
                    "invalidation": "below 96"}],
        "expected_moves": [{"expiry": "2026-10-30", "atm_strike": 100,
                            "spot_at_quote": 101, "call_price": 3, "put_price": 2,
                            "quote_source": "C:bid_ask_mid; P:last",
                            "data_timestamps": [f"{date}T00:00:00-04:00"] * 2}],
        "structural_bias": "bullish", "near_term_raw_levels": []}}


def test_october_30_premarket_map_is_d1_and_october_29_is_d2(monkeypatch):
    reports = [
        {**_report("oct30-premarket", "2026-10-30", 8, "SOXL"),
         "report_path": "stock_map_SOXL_20261030_0851_ET.html"},
        _report("oct30-older", "2026-10-30", 7, "SOXL"),
        _report("oct29-prior", "2026-10-29", 9, "SOXL"),
        _report("oct28-not-selected", "2026-10-28", 8, "SOXL"),
    ]
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: reports)
    def report_json(job_id):
        as_of = {"oct30-premarket": "2026-10-30T08:51:00-04:00",
                 "oct30-older": "2026-10-30T07:30:00-04:00",
                 "oct29-prior": "2026-10-29T09:30:00-04:00",
                 "oct28-not-selected": "2026-10-28T08:30:00-04:00"}[job_id]
        wrapper = _json(job_id, as_of[:10], "SOXL")
        wrapper["content"]["as_of_et"] = as_of
        return wrapper
    monkeypatch.setattr(skill_report_pages, "get_job_json", report_json)
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda **kwargs: {"live_price": 81.25, "live_price_source": "ib_live"})
    sent = []
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda method, path, payload: sent.append(payload) or {"job_id": "comparison"})
    client = TestClient(app)
    params = {"stock_code": "SOXL", "observation_date": "2026-10-30"}
    preview = client.get("/api/stock-map-comparison/preview", params=params, headers=AUTH)
    assert preview.status_code == 200
    assert (preview.json()["d1"]["report_job_id"], preview.json()["d2"]["report_job_id"]) == (
        "oct30-premarket", "oct29-prior")
    assert preview.json()["d1"]["as_of_et"] == "2026-10-30T08:51:00-04:00"
    prompt = client.get("/api/stock-map-comparison/prompt", params=params, headers=AUTH)
    assert prompt.status_code == 200
    embedded = json.loads(prompt.json()["prompt"].split("```json\n", 1)[1].split("\n```", 1)[0])
    assert (embedded["D1"]["trading_date"], embedded["D2"]["trading_date"]) == ("2026-10-30", "2026-10-29")
    assert "pre-market" in prompt.json()["prompt"]
    assert sent == []
    response = client.post("/api/stock-map-comparison/jobs", json=params, headers=AUTH)
    assert response.status_code == 200
    assert (sent[0]["D1"]["report_job_id"], sent[0]["D2"]["report_job_id"]) == (
        "oct30-premarket", "oct29-prior")
    assert sent[0]["current_market"]["option_rows_observation_date"] == "2026-10-30"
    assert "not a live" in sent[0]["current_market"]["option_rows_temporal_role"].lower()


def test_submit_chooses_current_date_and_latest_completed_prior_session(monkeypatch):
    reports = [_report("newest-28", "2026-10-28", 8), _report("older-28", "2026-10-28", 6),
               _report("not-selected-27", "2026-10-27", 6), _report("today-29", "2026-10-29", 6),
               _report("other-stock", "2026-10-29", 9, "QQQ")]
    submitted = []
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: reports)
    monkeypatch.setattr(skill_report_pages, "get_job_json", lambda job_id: _json(job_id, {
        "today-29": "2026-10-29", "newest-28": "2026-10-28", "older-28": "2026-10-28",
        "not-selected-27": "2026-10-27"}[job_id]))
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda stock_code, **kwargs: {
        "stock_code": stock_code, "last_close": 102, "last_close_timestamp": datetime(2026, 10, 29, 6),
        "live_price": 103, "live_price_source": "ib_live"})
    queried_dates = []

    def d1_options(stock_code, d1, observation_date, reference):
        queried_dates.append((d1.isoformat(), observation_date.isoformat(), reference))
        return {"source": "StockDB_US.StockData.v_OptionDelayedQuote_V2", "observation_date": d1.isoformat(),
                "spot_reference_from_d1": reference, "status": "available_historical_d1",
                "option_rows": [{"right": "C", "expiry": "2026-10-29", "strike": 101, "price": 3, "price_source": "last", "observation_date": d1.isoformat()},
                                {"right": "P", "expiry": "2026-10-29", "strike": 101, "price": 2, "price_source": "last", "observation_date": d1.isoformat()}]}

    monkeypatch.setattr(skill_report_pages, "load_d1_option_rows", d1_options, raising=False)

    def submit(method, path, payload):
        submitted.append((method, path, payload))
        return {"job_id": "comparison-123", "status": "queued"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", submit)
    client = TestClient(app)
    preview = client.get("/api/stock-map-comparison/preview?stock_code=form.us&observation_date=2026-10-29", headers=AUTH)
    assert preview.status_code == 200
    assert preview.json()["d1"]["report_job_id"] == "today-29"
    assert preview.json()["d2"]["report_job_id"] == "newest-28"
    assert preview.json()["current_market"]["option_rows"][0]["observation_date"] == "2026-10-29"
    response = client.post("/api/stock-map-comparison/jobs", headers=AUTH,
                           json={"stock_code": "form.us", "observation_date": "2026-10-29"})
    assert response.status_code == 200
    method, path, payload = submitted[0]
    assert (method, path) == ("POST", "/api/jobs/stock-map-comparison")
    assert (payload["D1"]["trading_date"], payload["D1"]["report_job_id"]) == ("2026-10-29", "today-29")
    assert (payload["D2"]["trading_date"], payload["D2"]["report_job_id"]) == ("2026-10-28", "newest-28")
    assert payload["D1"]["mapped_levels_and_orders"]["supports"][0]["range_low"] == 97
    assert payload["current_market"]["live_price"] == 103
    assert payload["current_market"]["option_rows"][0]["right"] == "C"
    assert payload["current_market"]["option_rows_observation_date"] == "2026-10-29"
    assert payload["D1"]["option_quote_snapshot"]["status"] == "available_historical_d1"
    assert "not a live" in payload["current_market"]["option_rows_temporal_role"].lower()
    assert queried_dates == [("2026-10-29", "2026-10-29", 101.0)] * 2
    assert payload["current_market"]["last_close_timestamp"] == "2026-10-29T06:00:00"
    json.dumps(payload)  # Exact runner wire payload must serialize real SQL datetime values.
    assert payload["execution_policy"] == {"mode": "recommendations_only_no_order_placement", "order_execution_enabled": False}


def test_get_prompt_is_read_only_and_uses_the_same_runner_evidence_as_submit(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [
        _report("json-29", "2026-10-29"), _report("json-28", "2026-10-28")])
    monkeypatch.setattr(skill_report_pages, "get_job_json", lambda job_id: _json(
        job_id, "2026-10-29" if job_id == "json-29" else "2026-10-28"))
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda stock_code, **kwargs: {
        "stock_code": stock_code, "live_price": 103, "live_price_source": "ib_delayed"})
    sent = []
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda method, path, payload: (
        sent.append(payload) or {"job_id": "queued"}))
    client = TestClient(app)
    params = {"stock_code": "FORM", "observation_date": "2026-10-29"}
    response = client.get("/api/stock-map-comparison/prompt", params=params, headers=AUTH)
    assert response.status_code == 200
    assert sent == []  # Get Prompt never posts a runner job.
    prompt = response.json()["prompt"]
    assert "mapped support zone" in prompt.lower()
    assert "discretionary" in prompt.lower()
    assert "No trade" in prompt
    assert "historical" in prompt.lower()
    embedded = json.loads(prompt.split("```json\n", 1)[1].split("\n```", 1)[0])
    assert embedded["D1"]["report_job_id"] == "json-29"
    assert embedded["D2"]["report_job_id"] == "json-28"
    assert embedded["execution_policy"]["order_execution_enabled"] is False
    assert embedded["analysis_mode"] == "retrospective"
    assert "d1" not in embedded and "d2" not in embedded
    queued = client.post("/api/stock-map-comparison/jobs", json=params, headers=AUTH)
    assert queued.status_code == 200
    embedded["current_market"].pop("retrieved_at_utc")
    sent[0]["current_market"].pop("retrieved_at_utc")
    assert embedded == sent[0]


def test_get_prompt_with_no_live_price_is_explicitly_non_actionable(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [
        _report("json-29", "2026-10-29"), _report("json-28", "2026-10-28")])
    monkeypatch.setattr(skill_report_pages, "get_job_json", lambda job_id: _json(
        job_id, "2026-10-29" if job_id == "json-29" else "2026-10-28"))
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda stock_code, **kwargs: {"live_price": None})
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("must not submit")))
    response = TestClient(app).get("/api/stock-map-comparison/prompt", params={
        "stock_code": "FORM", "observation_date": "2026-10-29"}, headers=AUTH)
    assert response.status_code == 200
    assert "unavailable" in response.json()["prompt"].lower()
    assert "do not propose executable" in response.json()["prompt"].lower()


def test_submit_blocks_when_either_required_date_has_no_json(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [_report("only-29", "2026-10-29")])
    monkeypatch.setattr(skill_report_pages, "get_job_json", lambda job_id: _json(job_id, "2026-10-29"))
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("must not submit")))
    response = TestClient(app).post("/api/stock-map-comparison/jobs", headers=AUTH,
                                    json={"stock_code": "FORM", "observation_date": "2026-10-29"})
    assert response.status_code == 422
    assert "2026-10-28" in response.json()["detail"]
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [_report("only-28", "2026-10-28")])
    response = TestClient(app).post("/api/stock-map-comparison/jobs", headers=AUTH,
                                    json={"stock_code": "FORM", "observation_date": "2026-10-29"})
    assert response.status_code == 422
    assert "2026-10-29" in response.json()["detail"]


def test_submit_uses_latest_completed_json_not_html_only_report(monkeypatch):
    reports = [_report("html-only-29", "2026-10-29", 9),
               _report("json-29", "2026-10-29", 8), _report("json-28", "2026-10-28", 6)]
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: reports)

    def get_json(job_id):
        if job_id == "html-only-29":
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="No JSON artifact")
        return _json(job_id, "2026-10-29" if job_id == "json-29" else "2026-10-28")

    monkeypatch.setattr(skill_report_pages, "get_job_json", get_json)
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda stock_code, **kwargs: {"live_price": 103})
    calls = []
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda method, path, payload: calls.append(payload) or {"job_id": "comparison-123"})
    result = TestClient(app).post("/api/stock-map-comparison/jobs", headers=AUTH,
                                  json={"stock_code": "FORM", "observation_date": "2026-10-29"})
    assert result.status_code == 200
    assert calls[0]["D1"]["report_job_id"] == "json-29"


def test_submit_blocks_without_current_live_price(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [
        _report("json-29", "2026-10-29"), _report("json-28", "2026-10-28")])
    monkeypatch.setattr(skill_report_pages, "get_job_json", lambda job_id: _json(job_id, "2026-10-29" if job_id == "json-29" else "2026-10-28"))
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda stock_code, **kwargs: {"live_price": None})
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("must not submit")))
    client = TestClient(app)
    preview = client.get("/api/stock-map-comparison/preview?stock_code=FORM&observation_date=2026-10-29", headers=AUTH)
    assert preview.status_code == 200
    assert preview.json()["current_market"]["live_price"] is None
    response = client.post("/api/stock-map-comparison/jobs", headers=AUTH,
                           json={"stock_code": "FORM", "observation_date": "2026-10-29"})
    assert response.status_code == 422
    assert "Current live price unavailable" in response.json()["detail"]


def test_runner_without_comparison_skill_returns_clear_unavailable_error(monkeypatch):
    from fastapi import HTTPException

    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [
        _report("json-29", "2026-10-29"), _report("json-28", "2026-10-28")])
    monkeypatch.setattr(skill_report_pages, "get_job_json", lambda job_id: _json(job_id, "2026-10-29" if job_id == "json-29" else "2026-10-28"))
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda stock_code, **kwargs: {"live_price": 103})

    def missing_runner_skill(method, path, payload):
        raise HTTPException(status_code=404, detail="Unknown job type")

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", missing_runner_skill)
    response = TestClient(app).post("/api/stock-map-comparison/jobs", headers=AUTH,
                                    json={"stock_code": "FORM", "observation_date": "2026-10-29"})
    assert response.status_code == 503
    assert "not installed" in response.json()["detail"]


def test_observation_date_must_be_us_trading_session(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [])
    client = TestClient(app)
    for day in ("2026-12-25", "2026-12-26"):  # Christmas Day and Saturday.
        response = client.post("/api/stock-map-comparison/jobs", headers=AUTH,
                               json={"stock_code": "FORM", "observation_date": day})
        assert response.status_code == 422
        assert "not a US trading session" in response.json()["detail"]


def test_comparison_report_viewer_uses_own_job_type(monkeypatch):
    monkeypatch.setattr(skill_report_pages, "list_reports", lambda job_type: [
        {"job_id": "comparison-123", "label": "FORM comparison", "status": "succeeded"}]
        if job_type == "stock-map-comparison" else [])
    monkeypatch.setattr(skill_report_pages, "get_job_report", lambda job_id: {"content": "# FORM: D1 versus D2"})
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda method, path: {"job_id": "comparison-123", "status": "succeeded"})
    client = TestClient(app)
    listing = client.get("/api/stock-map-comparison-reports", headers=AUTH)
    detail = client.get("/api/stock-map-comparison-reports/comparison-123", headers=AUTH)
    status = client.get("/api/stock-map-comparison/jobs/comparison-123", headers=AUTH)
    assert listing.status_code == detail.status_code == status.status_code == 200
    assert listing.json()["items"][0]["job_id"] == "comparison-123"
    assert detail.json()["content"] == "# FORM: D1 versus D2"
    assert status.json()["data"]["status"] == "succeeded"
