from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages, stock_codes


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


def test_option_flow_report_delete_hides_report(monkeypatch, tmp_path):
    deleted_path = tmp_path / "deleted_skill_reports.json"

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

    monkeypatch.setattr(skill_report_pages, "DELETED_REPORTS_PATH", deleted_path)
    monkeypatch.setattr(skill_report_pages, "list_reports", fake_list_reports)
    client = TestClient(app)

    delete_response = client.delete("/api/option-flow-analysis-reports/flow-123", headers=_auth())

    assert delete_response.status_code == 200
    assert delete_response.json() == {
        "deleted": True,
        "job_id": "flow-123",
        "data": {},
    }

    listing = client.get("/api/option-flow-analysis-reports", headers=_auth())
    assert listing.status_code == 200
    assert listing.json()["items"] == []

    detail = client.get("/api/option-flow-analysis-reports/flow-123", headers=_auth())
    assert detail.status_code == 404
    assert detail.json()["detail"] == "Report has been deleted"


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


def test_option_flow_aggregates_returns_trade_and_bidask_counts(monkeypatch):
    calls = []

    class FakeSqlModel:
        def execute_read_query(self, query, params):
            calls.append((query, params))
            if "v_OptionTrade" in query:
                return [
                    {"ASXCode": "MU", "NumRecords": 12, "NumOptions": 5},
                    {"ASXCode": "NVDA", "NumRecords": 20, "NumOptions": 7},
                ]
            if "v_OptionBidAsk" in query:
                return [{"ASXCode": "MU", "NumRecords": 30, "NumOptions": 9}]
            return []

    monkeypatch.setattr(stock_codes, "get_sql_model", lambda: FakeSqlModel())
    client = TestClient(app)

    response = client.get("/api/option-flow-aggregates?observation_date=2026-07-10", headers=_auth())

    assert response.status_code == 200
    assert response.json() == {
        "trades": [
            {"ASXCode": "MU", "NumRecords": 12, "NumOptions": 5},
            {"ASXCode": "NVDA", "NumRecords": 20, "NumOptions": 7},
        ],
        "bidask": [{"ASXCode": "MU", "NumRecords": 30, "NumOptions": 9}],
    }
    assert len(calls) == 2
    assert calls[0][1][0].isoformat() == "2026-07-10"
    assert calls[1][1][0].isoformat() == "2026-07-10"
    assert "WITH (NOLOCK)" in calls[0][0]
    assert "WITH (NOLOCK)" in calls[1][0]
