from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages


def _auth():
    return {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}


def test_option_flow_report_list_and_read_from_skill_runner(monkeypatch):
    def fake_list_reports(job_type):
        assert job_type == "analyze-option-flow"
        return [
            {
                "job_id": "flow-123",
                "label": "2026-07-02:MU",
                "ticker": "MU",
                "completed_at": "2026-07-03T10:30:00+10:00",
                "status": "succeeded",
            }
        ]

    def fake_get_job_report(job_id):
        assert job_id == "flow-123"
        return {"content": "# Option Flow\n\n- MU call buying expanded."}

    monkeypatch.setattr(skill_report_pages, "list_reports", fake_list_reports)
    monkeypatch.setattr(skill_report_pages, "get_job_report", fake_get_job_report)
    client = TestClient(app)

    listing = client.get("/api/option-flow-analysis-reports", headers=_auth())

    assert listing.status_code == 200
    items = listing.json()["items"]
    assert len(items) == 1
    assert items[0]["job_id"] == "flow-123"
    assert items[0]["title"] == "2026-07-02:MU"
    assert items[0]["stock_code"] == "MU"

    detail = client.get("/api/option-flow-analysis-reports/flow-123", headers=_auth())

    assert detail.status_code == 200
    assert detail.json()["content"] == "# Option Flow\n\n- MU call buying expanded."


def test_option_flow_full_market_job_submit_and_status(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        if method == "POST":
            return {"job_id": "flow-456", "status": "queued"}
        return {"job_id": "flow-456", "status": "running"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post(
        "/api/option-flow-analysis/jobs",
        headers=_auth(),
        json={
            "observation_date": "2026-07-02",
            "ticker": "",
            "top_n": 10,
            "timeout_minutes": 90,
            "model": "",
        },
    )

    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "flow-456"

    status = client.get("/api/option-flow-analysis/jobs/flow-456", headers=_auth())

    assert status.status_code == 200
    assert status.json()["data"]["status"] == "running"
    assert calls == [
        (
            "POST",
            "/api/jobs/analyze-option-flow",
            {
                "observation_date": "2026-07-02",
                "top_n": 10,
                "timeout_minutes": 90,
            },
        ),
        ("GET", "/api/jobs/flow-456", None),
    ]


def test_option_flow_ticker_drilldown_job_submit(monkeypatch):
    calls = []

    def fake_call_skill_runner(method, path, payload=None):
        calls.append((method, path, payload))
        return {"job_id": "flow-789", "status": "queued"}

    monkeypatch.setattr(skill_report_pages, "call_skill_runner", fake_call_skill_runner)
    client = TestClient(app)

    create = client.post(
        "/api/option-flow-analysis/jobs",
        headers=_auth(),
        json={
            "observation_date": "2026-07-02",
            "ticker": "mu",
            "top_n": 10,
            "timeout_minutes": 90,
            "model": "",
        },
    )

    assert create.status_code == 200
    assert create.json()["data"]["job_id"] == "flow-789"
    assert calls == [
        (
            "POST",
            "/api/jobs/analyze-option-flow",
            {
                "observation_date": "2026-07-02",
                "top_n": 10,
                "timeout_minutes": 90,
                "ticker": "MU",
            },
        ),
    ]
