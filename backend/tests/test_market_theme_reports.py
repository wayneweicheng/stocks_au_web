from fastapi.testclient import TestClient

from app.main import app
from app.routers import market_theme_reports


def _auth():
    return {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_market_theme_report_list_and_read_from_skill_runner(monkeypatch):
    def fake_list_reports(job_type):
        assert job_type == "market-theme-radar"
        return [
            {
                "job_id": "job-123",
                "title": "Market Theme Radar",
                "completed_at": "2026-06-20T09:30:00+10:00",
                "status": "completed",
            }
        ]

    def fake_get_job_report(job_id):
        assert job_id == "job-123"
        return {"content": "# Market Themes\n\n- AI leadership"}

    monkeypatch.setattr(market_theme_reports, "list_reports", fake_list_reports)
    monkeypatch.setattr(market_theme_reports, "get_job_report", fake_get_job_report)
    client = TestClient(app)

    listing = client.get("/api/market-theme-reports", headers=_auth())

    assert listing.status_code == 200
    items = listing.json()["items"]
    assert len(items) == 1
    assert items[0]["job_id"] == "job-123"
    assert items[0]["title"] == "Market Theme Radar"

    detail = client.get("/api/market-theme-reports/job-123", headers=_auth())

    assert detail.status_code == 200
    assert detail.json()["content"] == "# Market Themes\n\n- AI leadership"


def test_market_theme_radar_job_submit_and_status(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        if method == "POST":
            return {"job_id": "job-456", "status": "queued"}
        return {"job_id": "job-456", "status": "running"}

    monkeypatch.setattr(market_theme_reports, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post("/api/market-theme-radar/jobs", headers=_auth())

    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "job-456"

    status = client.get("/api/market-theme-radar/jobs/job-456", headers=_auth())

    assert status.status_code == 200
    assert status.json()["data"]["status"] == "running"
    assert calls == [
        ("POST", "/api/jobs/market-theme-radar", {}),
        ("GET", "/api/jobs/job-456", None),
    ]
