"""Public API round-trip against an in-memory HTTP mock of the skill runner.

No broker, live runner, or SQL connection is used. The mock only exists in this test.
"""
import io
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.main import app
from app.routers import skill_report_pages
from app.services import skill_runner_client, stock_map_comparison_service

AUTH = {"Authorization": "Basic YWRtaW46cGFzc3dvcmQxMjM="}
EXAMPLE = Path(__file__).parent / "fixtures" / "stock_map_comparison_api.json"


@pytest.fixture(autouse=True)
def no_live_sql_option_reads(monkeypatch):
    def d1_options(symbol, d1, observation_date, reference):
        return {"source": "StockDB_US.StockData.v_OptionDelayedQuote_V2", "observation_date": d1.isoformat(),
                "spot_reference_from_d1": reference, "status": "available_historical_d1",
                "option_rows": [
                    {"symbol": symbol, "right": "C", "expiry": observation_date.isoformat(), "strike": reference,
                     "price": 3.0, "price_source": "last", "observation_date": d1.isoformat()},
                    {"symbol": symbol, "right": "P", "expiry": observation_date.isoformat(), "strike": reference,
                     "price": 2.0, "price_source": "last", "observation_date": d1.isoformat()},
                ]}
    monkeypatch.setattr(skill_report_pages, "load_d1_option_rows", d1_options)


def _freeze_new_york_today(monkeypatch):
    class FixedDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            fixed = datetime(2026, 10, 29, 12, tzinfo=timezone.utc)
            return fixed.astimezone(tz) if tz else fixed.replace(tzinfo=None)

    monkeypatch.setattr(stock_map_comparison_service, "datetime", FixedDatetime)


def test_comparison_mock_request_to_queued_status_and_immutable_report(monkeypatch):
    _freeze_new_york_today(monkeypatch)
    example = json.loads(EXAMPLE.read_text(encoding="utf-8"))
    submitted = []
    state = {"status": "queued"}

    def mock_runner_http(request, timeout):
        route = urlsplit(request.full_url)
        method = request.get_method()
        assert request.get_header("Authorization", "").startswith("Bearer ")
        if (method, route.path) == ("GET", "/api/reports"):
            query = parse_qs(route.query)
            assert query.get("job_type") == ["stock-map"]
            assert query.get("stock_code") == ["FORM"]
            assert query.get("start_date") == ["2026-10-28"]
            assert query.get("end_date") == ["2026-10-29"]
            kind = query.get("job_type", [None])[0]
            if kind == "stock-map":
                response = example["stock_map_report_list"]
            elif kind == "stock-map-comparison":
                response = example["runner_list_response"] if state["status"] == "succeeded" else []
            else:
                raise AssertionError(f"Unexpected report type: {kind}")
        elif method == "GET" and route.path.startswith("/api/jobs/stock-") and route.path.endswith("/json"):
            job_id = route.path.split("/")[3]
            response = example["stock_map_report_json"][job_id]
        elif (method, route.path) == ("POST", "/api/jobs/stock-map-comparison"):
            payload = json.loads(request.data)
            required = ("stock_code", "observation_date", "analysis_mode", "D1", "D2", "current_market", "execution_policy")
            errors = [{"type": "missing", "loc": ["body", key], "msg": "Field required", "input": payload}
                      for key in required if key not in payload]
            if "execution_policy" in payload and not isinstance(payload["execution_policy"], dict):
                errors.append({"type": "dict_type", "loc": ["body", "execution_policy"],
                               "msg": "Input should be a valid dictionary", "input": payload["execution_policy"]})
            if errors:
                raise HTTPError(request.full_url, 422, "Unprocessable Entity", {},
                                io.BytesIO(json.dumps({"detail": errors}).encode("utf-8")))
            accepted_modes = ("current-day", "conditional-future-session", "retrospective")
            if payload["analysis_mode"] not in accepted_modes:
                raise HTTPError(request.full_url, 422, "Unprocessable Entity", {},
                                io.BytesIO(json.dumps({"detail": "analysis_mode must be current-day, conditional-future-session, or retrospective"}).encode("utf-8")))
            submitted.append(payload)
            response = example["runner_submit_response"]
        elif (method, route.path) == ("GET", "/api/jobs/mock-comparison-001"):
            response = example["runner_status_responses"][state["status"]]
        elif (method, route.path) == ("GET", "/api/jobs/mock-comparison-001/report"):
            response = example["runner_report_response"]
        else:
            raise AssertionError(f"Unexpected outbound runner request: {method} {route.path}?{route.query}")
        result = io.BytesIO(json.dumps(response).encode("utf-8"))
        result.status = 200
        return result

    monkeypatch.setattr(skill_runner_client, "urlopen", mock_runner_http)
    # The SQL/IB price adapter is a separate external boundary. Never touch live quotes here.
    price_requests = []
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda **kwargs: (price_requests.append(kwargs) or example["current_price"]))
    client = TestClient(app)
    request = example["frontend_submit_request"]

    preview = client.get("/api/stock-map-comparison/preview", params=request, headers=AUTH)
    assert preview.status_code == 200
    assert (preview.json()["d1"]["report_job_id"], preview.json()["d2"]["report_job_id"]) == ("stock-29", "stock-28")
    assert len(price_requests) == 1
    assert price_requests[0]["observation_date"] is None and price_requests[0]["as_of_et"] is None

    queued = client.post("/api/stock-map-comparison/jobs", json=request, headers=AUTH)
    assert queued.status_code == 200
    assert queued.json() == {"data": example["runner_submit_response"]}
    assert len(submitted) == 1
    assert "d1" not in submitted[0] and "d2" not in submitted[0]
    assert submitted[0]["analysis_mode"] == "current-day"
    assert (submitted[0]["D1"]["trading_date"], submitted[0]["D2"]["trading_date"]) == ("2026-10-29", "2026-10-28")
    assert submitted[0]["D1"]["mapped_levels_and_orders"]["supports"][0]["range_low"] == 97
    assert submitted[0]["D1"]["expected_moves"][0]["quote_source"] == "C:bid_ask_mid; P:last"
    assert submitted[0]["execution_policy"]["mode"] == "recommendations_only_no_order_placement"
    assert submitted[0]["execution_policy"]["order_execution_enabled"] is False
    assert submitted[0]["current_market"]["live_price"] == 103
    assert submitted[0]["current_market"]["option_rows_observation_date"] == "2026-10-29"
    assert [row["right"] for row in submitted[0]["current_market"]["option_rows"]] == ["C", "P"]
    assert "not a live" in submitted[0]["current_market"]["option_rows_temporal_role"].lower()

    job_id = queued.json()["data"]["job_id"]
    queued_status = client.get(f"/api/stock-map-comparison/jobs/{job_id}", headers=AUTH)
    assert queued_status.json() == {"data": example["runner_status_responses"]["queued"]}
    state["status"] = "succeeded"
    done_status = client.get(f"/api/stock-map-comparison/jobs/{job_id}", headers=AUTH)
    assert done_status.json() == {"data": example["runner_status_responses"]["succeeded"]}

    listing = client.get("/api/stock-map-comparison-reports", headers=AUTH)
    assert listing.status_code == 200
    assert listing.json()["items"][0]["job_id"] == job_id
    report = client.get(f"/api/stock-map-comparison-reports/{job_id}", headers=AUTH)
    assert report.status_code == 200
    assert "# FORM: D2 → D1" in report.json()["content"]
    assert "No order was sent" in report.json()["content"]


@pytest.mark.parametrize(("observation_date", "expected_mode", "d1_date", "d2_date"), [
    ("2026-10-30", "conditional-future-session", "2026-10-30", "2026-10-29"),
    ("2026-10-28", "retrospective", "2026-10-28", "2026-10-27"),
])
def test_runner_accepts_future_and_historical_mode_at_public_submit_boundary(
    monkeypatch, observation_date, expected_mode, d1_date, d2_date,
):
    _freeze_new_york_today(monkeypatch)
    example = json.loads(EXAMPLE.read_text(encoding="utf-8"))
    reports = list(example["stock_map_report_list"])
    wrappers = dict(example["stock_map_report_json"])
    for day in ("2026-10-30",):
        job_id = f"stock-{day[-2:]}"
        reports.append({"job_id": job_id, "stock_code": "FORM", "status": "succeeded",
                        "report_path": f"stock_map_FORM_{day.replace('-', '')}_0630_ET.html",
                        "created_at": f"{day}T10:40:00+00:00"})
        wrapper = json.loads(json.dumps(wrappers["stock-28"]))
        wrapper["job_id"] = job_id
        wrapper["content"]["as_of_et"] = f"{day}T06:30:00-04:00"
        wrapper["content"]["expected_moves"] = []
        wrappers[job_id] = wrapper
    posted = []

    def mock_runner_http(request, timeout):
        route = urlsplit(request.full_url)
        method = request.get_method()
        if (method, route.path) == ("GET", "/api/reports"):
            query = parse_qs(route.query)
            assert query.get("stock_code") == ["FORM"]
            assert "start_date" in query and "end_date" in query
            response = reports
        elif method == "GET" and route.path.endswith("/json"):
            response = wrappers[route.path.split("/")[3]]
        elif (method, route.path) == ("POST", "/api/jobs/stock-map-comparison"):
            payload = json.loads(request.data)
            if payload["analysis_mode"] not in ("current-day", "conditional-future-session", "retrospective"):
                raise HTTPError(request.full_url, 422, "Unprocessable Entity", {},
                                io.BytesIO(b'{"detail":"analysis_mode must be current-day, conditional-future-session, or retrospective"}'))
            posted.append(payload)
            response = example["runner_submit_response"]
        else:
            raise AssertionError(f"Unexpected runner route: {method} {route.path}")
        result = io.BytesIO(json.dumps(response).encode("utf-8"))
        result.status = 200
        return result

    monkeypatch.setattr(skill_runner_client, "urlopen", mock_runner_http)
    monkeypatch.setattr(skill_report_pages, "get_stock_map_prices", lambda **kwargs: example["current_price"])
    response = TestClient(app).post("/api/stock-map-comparison/jobs", headers=AUTH,
                                    json={"stock_code": "FORM", "observation_date": observation_date})
    assert response.status_code == 200
    assert posted[0]["analysis_mode"] == expected_mode
    assert (posted[0]["D1"]["trading_date"], posted[0]["D2"]["trading_date"]) == (d1_date, d2_date)


def test_runner_validation_error_never_exposes_the_submitted_report_in_logs_or_response(monkeypatch, caplog):
    def invalid_runner(request, timeout):
        detail = [{"type": "missing", "loc": ["body", "D1"], "msg": "Field required",
                   "input": {"private_report_payload": "DO-NOT-LOG-THIS"}}]
        raise HTTPError(request.full_url, 422, "Unprocessable Entity", {},
                        io.BytesIO(json.dumps({"detail": detail}).encode("utf-8")))

    monkeypatch.setattr(skill_runner_client, "urlopen", invalid_runner)
    with caplog.at_level(logging.ERROR, logger="app.services.skill_runner_client"):
        with pytest.raises(HTTPException) as error:
            skill_runner_client.call_skill_runner("POST", "/api/jobs/stock-map-comparison", {"stock_code": "FORM"})
    assert error.value.status_code == 422
    assert error.value.detail == [{"type": "missing", "loc": ["body", "D1"], "msg": "Field required"}]
    assert "DO-NOT-LOG-THIS" not in caplog.text
