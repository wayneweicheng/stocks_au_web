import importlib.util
import io
import json
import logging
import os
import tempfile
import unittest
from datetime import date, datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from urllib.error import HTTPError
from zoneinfo import ZoneInfo

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "stock-map" / "run-stock-map-scheduler.py"
SPEC = importlib.util.spec_from_file_location("stock_map_scheduler", SCRIPT)
assert SPEC and SPEC.loader
scheduler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scheduler)


class StockMapSchedulerTests(unittest.TestCase):
    def setUp(self):
        sleeper = patch.object(scheduler.time_module, "sleep")
        self.sleep = sleeper.start()
        self.addCleanup(sleeper.stop)

    def tearDown(self):
        logger = logging.getLogger("skill-runner-scheduler")
        for handler in logger.handlers:
            handler.close()
        logger.handlers.clear()

    def config(self, root):
        file = root / "config.json"
        file.write_text(json.dumps({
            "name": "stock-map", "runner_url": "http://runner.test", "endpoint": "/api/jobs/stock-map",
            "token_env": "TEST_STOCK_MAP_TOKEN", "log_directory": str(root / "logs"),
            "processed_state_file": str(root / "logs" / "processed.json"),
            "market_flow": {"base_url": "http://backend.test"},
            "current_time": {"timezone": "Australia/Sydney", "format": "%Y-%m-%d %H:%M"},
            "batch": {"placeholder": "stock_code", "values": ["QQQ", "SOXL", "NVDA"], "delay_seconds": 30},
            "payload": {"stock_code": "{{stock_code}}", "as_at": "{{current_time}} Australia/Sydney", "timeout_minutes": 120},
        }), encoding="utf-8")
        return file

    def invoke(self, config, now="2026-10-26T06:00:00Z", dry_run=False):
        return scheduler.run(SimpleNamespace(config=config, now_utc=now, dry_run=dry_run))

    def test_sydney_weekday_window_and_previous_business_day(self):
        sydney = ZoneInfo("Australia/Sydney")
        self.assertEqual(scheduler.market_flow_date(datetime(2026, 10, 26, 17, tzinfo=sydney)), date(2026, 10, 23))
        for hour, minute, expected in [(16, 55, False), (17, 0, True), (23, 45, True), (23, 46, False)]:
            self.assertEqual(scheduler.in_window(datetime(2026, 10, 26, hour, minute, tzinfo=sydney)), expected)
        # The Task Scheduler trigger normally starts a second or more after
        # 23:45:00; the entire final scheduled minute must remain eligible.
        self.assertTrue(scheduler.in_window(datetime(2026, 10, 26, 23, 45, 1, tzinfo=sydney)))
        self.assertTrue(scheduler.in_window(datetime(2026, 10, 26, 23, 45, 59, tzinfo=sydney)))
        for day in (24, 25):
            self.assertFalse(scheduler.in_window(datetime(2026, 10, day, 19, tzinfo=sydney)))

    def test_market_flow_query_matches_default_page_date_and_gex(self):
        config = {"market_flow": {"base_url": "http://backend.test", "credentials_dotenv": "backend/.env"}}
        def request(url, headers, timeout):
            self.assertIn("observation_date=2026-10-23&source_type=GEX", url)
            self.assertIn("Basic ", headers["Authorization"])
            self.assertEqual(timeout, 20)
            return [{"stock_code": "QQQ.US"}, {"stock_code": "NVDA"}]
        with patch.dict(os.environ, {"ADMIN_USERNAME": "admin", "ADMIN_PASSWORD": "secret"}), patch.object(scheduler, "request_json", side_effect=request):
            self.assertEqual(scheduler.fetch_market_flow_codes(config, date(2026, 10, 23)), {"QQQ", "NVDA"})

    def test_submit_once_per_symbol_and_reconcile_html_report(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            state_file = root / "logs" / "processed.json"
            reports = []
            submissions = []
            def submit(_config, payload, _token):
                submissions.append(payload)
                return f"job-{payload['stock_code'].lower()}"
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ", "NVDA"}), \
                 patch.object(scheduler, "runner_get", side_effect=lambda *_: {"items": reports}), \
                 patch.object(scheduler, "job_status", return_value="running"), \
                 patch.object(scheduler, "submit_stock_map_job", side_effect=submit):
                self.assertEqual(self.invoke(config), 0)
                self.assertEqual([item["stock_code"] for item in submissions], ["QQQ", "NVDA"])
                self.assertEqual([call.args[0] for call in self.sleep.call_args_list], [30.0])  # skipped SOXL adds no wait
                state = json.loads(state_file.read_text())
                self.assertEqual(state["dates"]["2026-10-23"]["QQQ"]["job_id"], "job-qqq")
                self.assertEqual(state["dates"]["2026-10-23"]["QQQ"]["status"], "submitted")
                self.assertIn("submitted_at", state["dates"]["2026-10-23"]["QQQ"])
                self.assertEqual(self.invoke(config, "2026-10-26T06:05:00Z"), 0)
                self.assertEqual(len(submissions), 2)
                reports.append({"job_id": "job-qqq", "file_name": "stock_map_QQQ_20261026_1700_ET.html"})
                self.assertEqual(self.invoke(config, "2026-10-26T06:10:00Z"), 0)
                self.assertEqual(json.loads(state_file.read_text())["dates"]["2026-10-23"]["QQQ"]["status"], "reported")
                self.assertEqual(len(submissions), 2)
                self.assertEqual([call.args[0] for call in self.sleep.call_args_list], [30.0])
            self.tearDown()

    def test_dry_run_is_read_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ"}), \
                 patch.object(scheduler, "runner_get", return_value={"items": []}), \
                 patch.object(scheduler, "submit_stock_map_job") as submit:
                self.assertEqual(self.invoke(config, dry_run=True), 0)
                submit.assert_not_called()
                self.assertFalse((root / "logs" / "processed.json").exists())
            self.tearDown()

    def test_external_same_day_html_does_not_satisfy_scheduler_submission(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            reports = [{"job_id": "manual", "title": "QQQ:2026-10-26 08:17 Australia/Sydney", "file_type": "html"}]
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ"}), \
                 patch.object(scheduler, "runner_get", return_value={"items": reports}), \
                 patch.object(scheduler, "job_status", return_value="running"), \
                 patch.object(scheduler, "submit_stock_map_job", return_value="scheduled-qqq") as submit:
                self.assertEqual(self.invoke(config), 0)
                self.assertEqual(submit.call_count, 1)
                entry = json.loads((root / "logs" / "processed.json").read_text())["dates"]["2026-10-23"]["QQQ"]
                self.assertEqual(entry["job_id"], "scheduled-qqq")
                self.assertIn("submitted_at", entry)
                self.assertEqual(entry["external_report_job_id"], "manual")
                self.assertEqual(self.invoke(config, "2026-10-26T06:05:00Z"), 0)
                self.assertEqual(submit.call_count, 1)
                self.assertEqual(json.loads((root / "logs" / "processed.json").read_text())["dates"]["2026-10-23"]["QQQ"]["status"], "submitted")
                reports.append({"job_id": "scheduled-qqq", "title": "QQQ:2026-10-26 17:10 Australia/Sydney", "file_type": "html"})
                self.assertEqual(self.invoke(config, "2026-10-26T06:10:00Z"), 0)
                self.assertEqual(json.loads((root / "logs" / "processed.json").read_text())["dates"]["2026-10-23"]["QQQ"]["status"], "reported")
                self.assertEqual(submit.call_count, 1)
            self.tearDown()

    def test_externally_adopted_html_state_without_submitted_at_is_eligible_again(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            state_file = root / "logs" / "processed.json"
            state_file.parent.mkdir(parents=True)
            state_file.write_text(json.dumps({"version": 1, "dates": {"2026-10-23": {"SOXL": {
                "status": "reported", "job_id": "external-soxl", "market_flow_date": "2026-10-23"}}}}), encoding="utf-8")
            reports = [{"job_id": "external-soxl", "title": "SOXL:2026-10-26 08:17 Australia/Sydney", "file_type": "html"}]
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"SOXL"}), \
                 patch.object(scheduler, "runner_get", return_value={"items": reports}), \
                 patch.object(scheduler, "submit_stock_map_job", return_value="scheduled-soxl") as submit:
                self.assertEqual(self.invoke(config), 0)
                self.assertEqual(submit.call_count, 1)
                entry = json.loads(state_file.read_text())["dates"]["2026-10-23"]["SOXL"]
                self.assertEqual(entry["job_id"], "scheduled-soxl")
                self.assertEqual(entry["external_report_job_id"], "external-soxl")
                self.assertIn("submitted_at", entry)
            self.tearDown()

    def test_rejected_queue_full_is_not_processed_and_retries_next_tick(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            attempted = []
            def submit(_config, payload, _token):
                attempted.append(payload["stock_code"])
                if len(attempted) == 1:
                    raise scheduler.SubmissionRejected("skill runner queue is full")
                return f"job-{payload['stock_code'].lower()}"
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ", "NVDA"}), \
                 patch.object(scheduler, "runner_get", return_value={"items": []}), \
                 patch.object(scheduler, "job_status", return_value="running"), \
                 patch.object(scheduler, "submit_stock_map_job", side_effect=submit):
                self.assertEqual(self.invoke(config), 3)
                state = json.loads((root / "logs" / "processed.json").read_text())["dates"]["2026-10-23"]
                self.assertNotIn("QQQ", state)
                self.assertEqual(state["NVDA"]["status"], "submitted")
                self.assertEqual([call.args[0] for call in self.sleep.call_args_list], [30.0])
                self.assertEqual(self.invoke(config, "2026-10-26T06:05:00Z"), 0)
                self.assertEqual(attempted, ["QQQ", "NVDA", "QQQ"])
            self.tearDown()

    def test_submit_api_http_and_json_errors_are_definite_rejections(self):
        config = {"runner_url": "http://runner.test", "endpoint": "/api/jobs/stock-map"}
        rejection = HTTPError("http://runner.test/api/jobs/stock-map", 429, "Too Many Requests", {}, io.BytesIO(b'{"detail":"skill runner queue is full"}'))
        with patch.object(scheduler, "urlopen", side_effect=rejection):
            with self.assertRaisesRegex(scheduler.SubmissionRejected, "skill runner queue is full"):
                scheduler.submit_stock_map_job(config, {"stock_code": "QQQ"}, "token")
        for body in (b'{"error":"skill runner queue is full"}', b'{"message":"skill runner queue is full"}', b'skill runner queue is full'):
            with patch.object(scheduler, "urlopen", return_value=io.BytesIO(body)):
                with self.assertRaisesRegex(scheduler.SubmissionRejected, "skill runner queue is full"):
                    scheduler.submit_stock_map_job(config, {"stock_code": "QQQ"}, "token")

    def test_failed_job_can_retry_next_tick_but_not_while_running(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            attempted = []
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ"}), \
                 patch.object(scheduler, "runner_get", return_value={"items": []}), \
                 patch.object(scheduler, "job_status", return_value="failed"), \
                 patch.object(scheduler, "submit_stock_map_job", side_effect=lambda *_: (attempted.append(1) or f"job-{len(attempted)}")):
                self.assertEqual(self.invoke(config), 0)
                self.assertEqual(self.invoke(config, "2026-10-26T06:05:00Z"), 0)  # confirm failure, retry next tick
                self.assertEqual(len(attempted), 1)
                self.assertEqual(self.invoke(config, "2026-10-26T06:10:00Z"), 0)
                self.assertEqual(len(attempted), 2)
            self.tearDown()

    def test_report_filename_et_date_matches_sydney_not_generated_date(self):
        report = {"job_id": "r1", "file_name": "stock_map_QQQ_20261025_2100_ET.html", "created_at": "2026-10-27T02:00:00Z"}
        self.assertEqual(scheduler.report_sydney_date(report), "2026-10-26")
        self.assertEqual(scheduler.report_code(report), "QQQ")
        self.assertIs(scheduler.matching_html_report([report], "QQQ", "2026-10-26"), report)
        self.assertIsNone(scheduler.matching_html_report([report], "QQQ", "2026-10-27"))
        self.assertEqual(scheduler.report_sydney_date({"as_of_sydney": "2026-10-26T19:00:00+11:00"}), "2026-10-26")
        self.assertTrue(scheduler.is_html_report({"report_file": "reports/stock_map_QQQ_20261025_2100_ET.html"}))

    def test_fail_closed_when_report_listing_unavailable_and_on_ambiguous_submit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ"}), \
                 patch.object(scheduler, "runner_get", side_effect=RuntimeError("down")), \
                 patch.object(scheduler, "submit_stock_map_job") as submit:
                self.assertEqual(self.invoke(config), 3)
                submit.assert_not_called()
            with patch.dict(os.environ, {"TEST_STOCK_MAP_TOKEN": "secret"}), \
                 patch.object(scheduler, "fetch_market_flow_codes", return_value={"QQQ"}), \
                 patch.object(scheduler, "runner_get", return_value={"items": []}), \
                 patch.object(scheduler, "submit_stock_map_job", side_effect=scheduler.SubmissionUncertain("POST timed out")) as submit:
                self.assertEqual(self.invoke(config), 3)
                self.assertEqual(self.invoke(config, "2026-10-26T06:05:00Z"), 0)
                self.assertEqual(submit.call_count, 1)
                self.assertEqual(json.loads((root / "logs" / "processed.json").read_text())["dates"]["2026-10-23"]["QQQ"]["status"], "uncertain")
            self.tearDown()

    def test_outside_window_never_calls_network_or_creates_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = self.config(root)
            with patch.object(scheduler, "fetch_market_flow_codes") as fetch:
                self.assertEqual(self.invoke(config, "2026-10-24T08:00:00Z"), 0) # Saturday Sydney
                self.assertEqual(self.invoke(config, "2026-10-26T12:46:00Z"), 0) # 23:46 Sydney
                fetch.assert_not_called()
            self.assertFalse((root / "logs" / "processed.json").exists())
            self.tearDown()


if __name__ == "__main__":
    unittest.main()
