from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages


def _auth():
    return {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_spx_map_report_list_and_read_from_skill_runner(monkeypatch):
    def fake_list_reports(job_type):
        assert job_type == "spx-map"
        return [
            {
                "job_id": "spx-123",
                "title": "SPX Map",
                "completed_at": "2026-09-15T20:00:00+10:00",
                "status": "succeeded",
            }
        ]

    def fake_get_job_report(job_id):
        assert job_id == "spx-123"
        return {"content": "# SPX Map\n\n- Resistance: 6,800"}

    monkeypatch.setattr(skill_report_pages, "list_reports", fake_list_reports)
    monkeypatch.setattr(skill_report_pages, "get_job_report", fake_get_job_report)
    client = TestClient(app)

    listing = client.get("/api/spx-map-reports", headers=_auth())

    assert listing.status_code == 200
    items = listing.json()["items"]
    assert len(items) == 1
    assert items[0]["job_id"] == "spx-123"
    assert items[0]["title"] == "SPX Map"

    detail = client.get("/api/spx-map-reports/spx-123", headers=_auth())

    assert detail.status_code == 200
    assert detail.json()["content"] == "# SPX Map\n\n- Resistance: 6,800"


def test_spx_map_job_submit_and_status(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        if method == "POST":
            return {"job_id": "spx-456", "status": "queued"}
        return {"job_id": "spx-456", "status": "running"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post(
        "/api/spx-map/jobs",
        headers=_auth(),
        json={
            "as_at": "2026-09-15 20:00 Australia/Sydney",
            "timeout_minutes": 120,
            "model": "gpt-5.6-luna",
        },
    )

    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "spx-456"

    status = client.get("/api/spx-map/jobs/spx-456", headers=_auth())

    assert status.status_code == 200
    assert status.json()["data"]["status"] == "running"
    assert calls == [
        (
            "POST",
            "/api/jobs/spx-map",
            {
                "as_at": "2026-09-15 20:00 Australia/Sydney",
                "timeout_minutes": 120,
                "model": "gpt-5.6-luna",
            },
        ),
        ("GET", "/api/jobs/spx-456", None),
    ]


def test_stock_map_job_list_json_submit_and_status(monkeypatch):
    calls = []

    def fake_list_reports(job_type):
        assert job_type == "stock-map"
        return [{"job_id": "stock-123", "stock_code": "NVDA", "status": "succeeded"}]

    def fake_get_job_json(job_id):
        assert job_id == "stock-123"
        return {"stock_code": "NVDA", "primary_supports": []}

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        return {"job_id": "stock-456", "status": "queued" if method == "POST" else "running"}

    monkeypatch.setattr(skill_report_pages, "list_reports", fake_list_reports)
    monkeypatch.setattr(skill_report_pages, "get_job_json", fake_get_job_json)
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    listing = client.get("/api/stock-map-reports", headers=_auth())
    assert listing.status_code == 200
    assert listing.json()["items"][0]["job_id"] == "stock-123"

    audit = client.get("/api/stock-map-reports/stock-123/json", headers=_auth())
    assert audit.status_code == 200
    assert audit.json()["data"]["stock_code"] == "NVDA"

    create = client.post(
        "/api/stock-map/jobs",
        headers=_auth(),
        json={
            "stock_code": "nvda",
            "as_at": "2026-09-15T20:00:00+10:00",
            "timeout_minutes": 120,
            "model": "gpt-5.6-luna",
        },
    )
    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "stock-456"

    status = client.get("/api/stock-map/jobs/stock-456", headers=_auth())
    assert status.status_code == 200
    assert status.json()["data"]["status"] == "running"
    assert calls == [
        (
            "POST",
            "/api/jobs/stock-map",
            {
                "stock_code": "NVDA",
                "as_at": "2026-09-15T20:00:00+10:00",
                "timeout_minutes": 120,
                "model": "gpt-5.6-luna",
            },
        ),
        ("GET", "/api/jobs/stock-456", None),
    ]


def test_spx_map_job_defaults_and_omits_blank_optional_values(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        return {"job_id": "spx-789", "status": "queued"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post(
        "/api/spx-map/jobs",
        headers=_auth(),
        json={"as_at": "", "model": ""},
    )

    assert create.status_code == 200
    assert calls == [("POST", "/api/jobs/spx-map", {"timeout_minutes": 120})]
