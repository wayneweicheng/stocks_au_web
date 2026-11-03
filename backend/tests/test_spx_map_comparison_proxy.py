from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages

AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_spx_comparison_frontend_routes_proxy_to_skill_runner(monkeypatch):
    calls = []

    def fake_runner(method, path, payload=None):
        calls.append((method, path, payload))
        if path.endswith("/reports"):
            return [{"job_id": "comparison-1"}]
        if path.endswith("/report"):
            return {"content": "# Report"}
        if path.endswith("/preview"):
            return {"input_id": "input-1", "comparison_input": {"D1": {"source": {"job_id": "d1", "trading_date": "2026-10-30", "as_of_et": "2026-10-30T21:20:00-04:00"}, "report": {"support_zones": [{"center": 7700}]}}, "D2": {"source": {"job_id": "d2", "trading_date": "2026-10-29", "as_of_et": "2026-10-29T21:20:00-04:00"}, "report": {"resistance_zones": [{"center": 7710}]}}}}
        return {"job_id": "comparison-1", "status": "succeeded"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_runner)
    monkeypatch.setattr(skill_report_pages, "_load_spx_comparison_market_path_evidence", lambda comparison_input: {"D1": {"status": "unavailable"}, "D2": {"status": "unavailable"}})
    client = TestClient(app)

    assert client.get("/api/spx-map-comparison/reports", headers=AUTH).json() == [
        {"job_id": "comparison-1"}
    ]
    preview_request = {"observation_date": "2026-10-30"}
    preview_response = client.post("/api/spx-map-comparison/preview", json=preview_request, headers=AUTH)
    assert preview_response.status_code == 200
    prompt = {"preview": preview_response.json(), "effective_price_context": [{"day": "D1", "as_of_et": "2026-10-30T21:20:00-04:00", "effective_prices": {"SPX": 7700.0}}]}
    prompt_response = client.post("/api/spx-map-comparison/prompt", json=prompt, headers=AUTH)
    assert prompt_response.status_code == 200
    prompt_result = prompt_response.json()
    assert "conditional trading plan" in prompt_result["prompt"]
    assert "Entry SPX range/trigger" in prompt_result["prompt"]
    assert "As-of price and level classification rules" in prompt_result["prompt"]
    assert "Re-rank supports nearest-first" in prompt_result["prompt"]
    assert '"job_id":"d1"' in prompt_result["prompt"]
    assert '"center":7700' in prompt_result["prompt"]
    assert '"effective_prices":{"SPX":7700.0}' in prompt_result["prompt"]
    assert prompt_result["prompt_chars"] == len(prompt_result["prompt"])
    assert prompt_result["submitted"] is False
    submit = {**prompt, "timeout_minutes": 30}
    assert client.post("/api/jobs/spx-map-comparison", json=submit, headers=AUTH).json()["job_id"] == "comparison-1"
    assert client.get("/api/spx-map-comparison/jobs/comparison-1", headers=AUTH).status_code == 200
    assert client.get("/api/spx-map-comparison/jobs/comparison-1/report", headers=AUTH).json() == {
        "content": "# Report"
    }

    assert calls == [
        ("GET", "/api/spx-map-comparison/reports", None),
        ("POST", "/api/spx-map-comparison/preview", preview_request),
        ("POST", "/api/jobs/spx-map-comparison", submit),
        ("GET", "/api/jobs/comparison-1", None),
        ("GET", "/api/jobs/comparison-1/report", None),
    ]


def test_spx_comparison_prompt_compacts_optional_payload_below_runner_limit():
    from app.routers.skill_report_pages import _build_spx_comparison_prompt

    preview = {"input_id": "large-input", "comparison_input": {
        "D1": {"source": {"job_id": "d1", "trading_date": "2026-11-02", "as_of_et": "2026-11-02T01:52:00-05:00", "source_metadata": {"bulk": "x" * 15000}},
               "report": {"support_zones": [{"center": 7000}], "positioning_intelligence": {"raw": "x" * 77000}}},
        "D2": {"source": {"job_id": "d2", "trading_date": "2026-10-30", "as_of_et": "2026-10-30T06:05:00-04:00"},
               "report": {"resistance_zones": [{"center": 7100}]}}}}

    result = _build_spx_comparison_prompt(preview)

    assert len(result["prompt"].encode("utf-8")) < 160 * 1024
    assert '"raw":' not in result["prompt"]
    assert "bulky source metadata were omitted" in result["prompt"]
    assert "Additional mandatory analysis: forward-looking market path" in result["prompt"]
    assert "PRIMARY PRICE PATH" in result["prompt"]
    assert "SCENARIO" in result["prompt"]
    assert "latest valid as_of_et" in result["prompt"]
    assert "chronologically latest report" in result["prompt"]
    assert "MIXED_SNAPSHOT" in result["prompt"]
    assert "report_es_quote_candidates" in result["prompt"]
    assert "coming-session outlook clearly dominant" in result["prompt"]
    assert "machine-readable JSON forecast contract" in result["prompt"]
    assert '"primary_forecast_day":"D1"' in result["prompt"]
    assert '"previous_comparison_day":"D2"' in result["prompt"]
    assert '"job_id":"d1"' in result["prompt"]
    assert '"center":7000' in result["prompt"]
    assert result["prompt_chars"] == len(result["prompt"])
    assert result["submitted"] is False


def test_spx_market_path_evidence_uses_only_completed_bars_as_of_each_report(monkeypatch):
    from app.services import stock_map_chart_service

    from app.routers.skill_report_pages import _load_spx_comparison_market_path_evidence

    calls = []
    def fake_bars(symbol, **kwargs):
        calls.append(kwargs["observation_datetime"])
        return {"bars": [
            {"time": f"2026-10-30T{hour:02d}:{minute:02d}:00", "open": 100 + index,
             "high": 102 + index, "low": 99 + index, "close": 101 + index, "volume": 10}
            for index, (hour, minute) in enumerate([(9, 30), (10, 0), (10, 30), (11, 0), (11, 30), (12, 0)])
        ]}

    monkeypatch.setattr(stock_map_chart_service, "get_stock_map_chart_bars", fake_bars)
    evidence = _load_spx_comparison_market_path_evidence({
        "D1": {"source": {"as_of_et": "2026-10-30T12:00:00-04:00"}},
        "D2": {"source": {"as_of_et": "2026-10-30T11:00:00-04:00"}},
    })

    assert len(calls) == 2
    assert evidence["D1"]["status"] == "available"
    assert evidence["D1"]["completed_30m_bars"][-1]["time"] == "2026-10-30T11:30:00"
    assert evidence["D1"]["completed_30m_bars"][-1]["source_time_raw"] == "2026-10-30T10:30:00"
    assert evidence["D2"]["completed_30m_bars"][-1]["time"] == "2026-10-30T10:30:00"
    assert evidence["D1"]["timestamp_label_status"].startswith("SPXW SQL TimeIntervalStart corrected +1 hour")
    assert evidence["D1"]["source_availability_timestamp"] == "not supplied by the historical bar source"


def test_spx_prompt_marks_mixed_snapshot_and_blocks_conflicting_es_conversion():
    from app.routers.skill_report_pages import _build_spx_comparison_prompt

    preview = {"input_id": "quality", "comparison_input": {
        "D1": {"source": {"job_id": "current", "trading_date": "2026-11-02", "as_of_et": "2026-11-02T02:25:00-05:00"},
               "report": {"as_of_et": "2026-11-02T01:52:00-05:00", "es_price": 7673.25, "es_spx_basis": 34.525,
                          "warning": "LIVE DATABASE RECONSTRUCTION WARNING: requested cutoff could not be refreshed; fallback preserves 01:52 ET source snapshot"}},
        "D2": {"source": {"job_id": "previous", "trading_date": "2026-10-30", "as_of_et": "2026-10-30T06:05:00-04:00"}, "report": {}}}}
    market_path = {
        "D1": {"status": "available", "report_as_of_et": "2026-11-02T01:52:00-05:00", "inherited_or_fallback_snapshot_warning_detected": True,
               "report_source_timestamp_status": "MISMATCH", "volume_status": "PARTIAL_OR_ZERO",
               "timestamp_label_status": "unverified raw SQL TimeIntervalStart labels"},
        "D2": {"status": "available", "inherited_or_fallback_snapshot_warning_detected": False}}
    prices = [{"day": "D1", "as_of_et": "2026-11-02T02:25:00-05:00",
               "effective_prices": {"SPX": 7642.77, "ESMain": 7676.0}, "source": "ESMain completed 30M bar",
               "es_spx_basis": 33.23, "timestamp": "2026-11-02T02:00:00",
               "timestamps": {"ESMain": "2026-11-02T02:00:00"}, "basis_observation_date": "2026-10-30"}]

    result = _build_spx_comparison_prompt(preview, market_path, prices)
    assert '"status":"MIXED_SNAPSHOT"' in result["prompt"]
    assert "report SPX/ES quote or ES-SPX basis conflicts" in result["prompt"]
    assert "UNAVAILABLE_RECONCILIATION_REQUIRED" in result["prompt"]
    assert "report_as_of_et" in result["prompt"]


def test_spx_comparison_proxy_requires_app_authentication():

    response = TestClient(app).get("/api/spx-map-comparison/reports")
    assert response.status_code == 401
