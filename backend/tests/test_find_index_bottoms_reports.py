from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages


def _auth():
    return {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_find_index_bottoms_report_list_and_read_from_skill_runner(monkeypatch):
    def fake_list_reports(job_type):
        assert job_type == "find-index-bottoms"
        return [
            {
                "job_id": "bottom-123",
                "label": "Current index-bottom analysis",
                "completed_at": "2026-07-05T10:30:00+10:00",
                "status": "succeeded",
            }
        ]

    def fake_get_job_report(job_id):
        assert job_id == "bottom-123"
        return {"content": "# Index Bottoms\n\n- SPX risk/reward improved."}

    monkeypatch.setattr(skill_report_pages, "list_reports", fake_list_reports)
    monkeypatch.setattr(skill_report_pages, "get_job_report", fake_get_job_report)
    client = TestClient(app)

    listing = client.get("/api/find-index-bottoms-reports", headers=_auth())

    assert listing.status_code == 200
    items = listing.json()["items"]
    assert len(items) == 1
    assert items[0]["job_id"] == "bottom-123"
    assert items[0]["title"] == "Current index-bottom analysis"

    detail = client.get("/api/find-index-bottoms-reports/bottom-123", headers=_auth())

    assert detail.status_code == 200
    assert detail.json()["content"] == "# Index Bottoms\n\n- SPX risk/reward improved."


def test_find_index_bottoms_detail_does_not_relist_reports(monkeypatch):
    def fail_list_reports(job_type):
        raise AssertionError("detail lookup should not call the slow report-list endpoint")

    monkeypatch.setattr(skill_report_pages, "list_reports", fail_list_reports)
    monkeypatch.setattr(
        skill_report_pages,
        "get_job_report",
        lambda job_id: {"job_id": job_id, "content": "# Index Bottoms"},
    )
    client = TestClient(app)

    detail = client.get("/api/find-index-bottoms-reports/bottom-fast", headers=_auth())

    assert detail.status_code == 200
    assert detail.json()["content"] == "# Index Bottoms"


def test_find_index_bottoms_current_job_submit_and_status(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        if method == "POST":
            return {"job_id": "bottom-456", "status": "queued"}
        return {"job_id": "bottom-456", "status": "running"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post(
        "/api/find-index-bottoms/jobs",
        headers=_auth(),
        json={"as_at": "", "timeout_minutes": 90, "model": ""},
    )

    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "bottom-456"

    status = client.get("/api/find-index-bottoms/jobs/bottom-456", headers=_auth())

    assert status.status_code == 200
    assert status.json()["data"]["status"] == "running"
    assert calls == [
        ("POST", "/api/jobs/find-index-bottoms", {"timeout_minutes": 90}),
        ("GET", "/api/jobs/bottom-456", None),
    ]


def test_find_index_bottoms_historical_job_submit(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        return {"job_id": "bottom-789", "status": "queued"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post(
        "/api/find-index-bottoms/jobs",
        headers=_auth(),
        json={
            "as_at": "2026-06-22 16:00 America/New_York",
            "timeout_minutes": 90,
            "model": "google/gemini-2.5-flash",
        },
    )

    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "bottom-789"
    assert calls == [
        (
            "POST",
            "/api/jobs/find-index-bottoms",
            {
                "as_at": "2026-06-22 16:00 America/New_York",
                "timeout_minutes": 90,
                "model": "google/gemini-2.5-flash",
            },
        ),
    ]
