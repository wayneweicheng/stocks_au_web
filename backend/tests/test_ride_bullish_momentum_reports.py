from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages


def _auth():
    return {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_ride_bullish_momentum_reports_and_job_submission(monkeypatch):
    calls = []

    def fake_list_reports(job_type):
        assert job_type == "ride-bullish-momentum"
        return [{
            "job_id": "momentum-123",
            "label": "Current bullish momentum analysis",
            "status": "succeeded",
        }]

    def fake_get_job_report(job_id):
        assert job_id == "momentum-123"
        return {"content": "# Ride Bullish Momentum"}

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        if method == "POST":
            return {"job_id": "momentum-456", "status": "queued"}
        return {"job_id": "momentum-456", "status": "running"}

    monkeypatch.setattr(skill_report_pages, "list_reports", fake_list_reports)
    monkeypatch.setattr(skill_report_pages, "get_job_report", fake_get_job_report)
    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    listing = client.get("/api/ride-bullish-momentum-reports", headers=_auth())
    assert listing.status_code == 200
    assert listing.json()["items"][0]["job_id"] == "momentum-123"

    detail = client.get("/api/ride-bullish-momentum-reports/momentum-123", headers=_auth())
    assert detail.status_code == 200
    assert detail.json()["content"] == "# Ride Bullish Momentum"

    create = client.post(
        "/api/ride-bullish-momentum/jobs",
        headers=_auth(),
        json={"timeout_minutes": 90, "model": "gpt-5.6-luna"},
    )
    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "momentum-456"

    status = client.get("/api/ride-bullish-momentum/jobs/momentum-456", headers=_auth())
    assert status.status_code == 200
    assert status.json()["data"]["status"] == "running"

    historical = client.post(
        "/api/ride-bullish-momentum/jobs",
        headers=_auth(),
        json={"as_at": "2026-09-18 16:00 America/New_York", "timeout_minutes": 90},
    )
    assert historical.status_code == 200
    assert calls[-1] == (
        "POST",
        "/api/jobs/ride-bullish-momentum",
        {"as_at": "2026-09-18 16:00 America/New_York", "timeout_minutes": 90},
    )
