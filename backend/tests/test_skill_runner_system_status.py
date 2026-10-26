from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.main import app
from app.routers import auth, skill_report_pages


AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}
URL = "/api/skill-runner/system-status"


def test_status_proxies_get_without_body_and_requires_login(monkeypatch):
    monkeypatch.setattr(auth, "get_credentials", lambda: {"username": "admin", "password": "password123"})
    snapshot = {
        "as_of": "2026-10-25T08:15:00+00:00",
        "skill_runner": {
            "running": 1, "queued": 2, "outstanding": 3,
            "max_outstanding": 6, "max_concurrent": 2,
            "by_job_type": {"stock-map": {"running": 1, "queued": 1}},
            "running_jobs": [{"job_id": "abc", "status": "running"}],
            "queued_jobs": [{"job_id": "def", "status": "queued"}],
        },
        "memory": {"process_rss_bytes": None, "system_total_bytes": 1000},
    }
    calls = []

    def fake_call(method, path, payload=None, *, timeout_seconds=180, expected_not_found=False):
        calls.append((method, path, payload, timeout_seconds, expected_not_found))
        return snapshot

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call)
    client = TestClient(app)
    assert client.get(URL).status_code == 401
    response = client.get(URL, headers=AUTH)
    assert response.status_code == 200
    assert response.json() == snapshot
    assert calls == [("GET", "/api/system/status", None, 10, True)]


def test_status_falls_back_to_health_and_filtered_jobs_when_route_is_missing(monkeypatch):
    monkeypatch.setattr(auth, "get_credentials", lambda: {"username": "admin", "password": "password123"})
    calls = []

    def fake_call(method, path, payload=None, *, timeout_seconds=180, expected_not_found=False):
        calls.append((method, path, payload, timeout_seconds, expected_not_found))
        if path == "/api/system/status":
            raise HTTPException(status_code=404, detail="Not Found")
        if path == "/health":
            return {"status": "ok", "skill_runner_capacity": {"max_outstanding": 6, "max_concurrent": 2}}
        if path == "/api/jobs?status=running":
            return [{"job_id": "abc123", "job_type": "stock-map", "label": "GOOG", "stock_code": "GOOG", "status": "running", "created_at": "2026-10-25T08:10:00+00:00", "updated_at": "2026-10-25T08:10:15+00:00"}]
        if path == "/api/jobs?status=queued":
            return [{"job_id": "def456", "job_type": "stock-map", "status": "queued"}, {"job_id": "ghi789", "job_type": "us-equity-analysis", "status": "queued"}]
        raise AssertionError(path)

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call)
    response = TestClient(app).get(URL, headers=AUTH)
    assert response.status_code == 200
    snapshot = response.json()
    assert snapshot["source"] == "compatibility"
    assert snapshot["skill_runner"]["running"] == 1
    assert snapshot["skill_runner"]["queued"] == 2
    assert snapshot["skill_runner"]["outstanding"] == 3
    assert snapshot["skill_runner"]["max_outstanding"] == 6
    assert snapshot["skill_runner"]["by_job_type"] == {"stock-map": {"running": 1, "queued": 1}, "us-equity-analysis": {"running": 0, "queued": 1}}
    assert snapshot["skill_runner"]["running_jobs"][0]["label"] == "GOOG"
    assert snapshot["memory"]["process_rss_bytes"] is None
    assert {path for _, path, _, _, _ in calls} == {"/api/system/status", "/health", "/api/jobs?status=running", "/api/jobs?status=queued"}


def test_status_reports_upstream_failure_and_invalid_response(monkeypatch):
    monkeypatch.setattr(auth, "get_credentials", lambda: {"username": "admin", "password": "password123"})
    client = TestClient(app)

    def fail(*args, **kwargs):
        raise HTTPException(status_code=503, detail="Runner unavailable")

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fail)
    failure = client.get(URL, headers=AUTH)
    assert failure.status_code == 503
    assert failure.json()["detail"] == "Runner unavailable"

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", lambda *args, **kwargs: {"raw": "bad reply"})
    invalid = client.get(URL, headers=AUTH)
    assert invalid.status_code == 502
