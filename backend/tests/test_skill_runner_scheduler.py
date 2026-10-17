import importlib.util
import io
import json
import logging
import os
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "skill-runner" / "run-skill-runner-job.py"
SPEC = importlib.util.spec_from_file_location("skill_runner_scheduler", SCRIPT_PATH)
assert SPEC and SPEC.loader
scheduler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scheduler)


class SkillRunnerSchedulerBatchTests(unittest.TestCase):
    def _write_config(self, directory: Path, *, delay_seconds: int = 300) -> Path:
        config = {
            "name": "stock-map-test",
            "runner_url": "http://runner.test",
            "endpoint": "/api/jobs/stock-map",
            "token_env": "TEST_SKILL_RUNNER_TOKEN",
            "log_directory": str(directory / "logs"),
            "current_time": {"timezone": "UTC", "format": "%Y-%m-%d %H:%M"},
            "batch": {
                "placeholder": "stock_code",
                "values": ["QQQ", "NVDA", "META"],
                "delay_seconds": delay_seconds,
            },
            "payload": {
                "stock_code": "{{stock_code}}",
                "as_at": "{{current_time}} UTC",
                "timeout_minutes": 120,
            },
        }
        path = directory / "config.json"
        path.write_text(json.dumps(config), encoding="utf-8")
        return path

    def _close_logger(self) -> None:
        logger = logging.getLogger("skill-runner-scheduler")
        for handler in logger.handlers:
            handler.close()
        logger.handlers.clear()

    def tearDown(self) -> None:
        self._close_logger()

    def test_batch_dry_run_expands_values_without_waiting(self):
        with tempfile.TemporaryDirectory() as temp_directory:
            config_path = self._write_config(Path(temp_directory))
            stdout = io.StringIO()
            with patch.object(scheduler.time, "sleep") as sleep, redirect_stdout(stdout):
                result = scheduler.run(
                    SimpleNamespace(config=config_path, dry_run=True, now_utc="2026-08-28T11:00:00Z")
                )
            output = json.loads(stdout.getvalue())
            self._close_logger()

        self.assertEqual(result, 0)
        self.assertEqual([payload["stock_code"] for payload in output], ["QQQ", "NVDA", "META"])
        self.assertEqual({payload["as_at"] for payload in output}, {"2026-08-28 11:00 UTC"})
        sleep.assert_not_called()

    def test_batch_submits_in_order_and_waits_between_requests(self):
        with tempfile.TemporaryDirectory() as temp_directory:
            config_path = self._write_config(Path(temp_directory))
            submissions = []

            def fake_submit_job(config, payload, token):
                submissions.append((payload, token))
                return f"job-{payload['stock_code'].lower()}"

            with (
                patch.dict(os.environ, {"TEST_SKILL_RUNNER_TOKEN": "secret"}),
                patch.object(scheduler, "submit_job", side_effect=fake_submit_job),
                patch.object(scheduler.time, "sleep") as sleep,
            ):
                result = scheduler.run(
                    SimpleNamespace(config=config_path, dry_run=False, now_utc="2026-08-28T11:00:00Z")
                )
            self._close_logger()

        self.assertEqual(result, 0)
        self.assertEqual([payload["stock_code"] for payload, _ in submissions], ["QQQ", "NVDA", "META"])
        self.assertEqual([token for _, token in submissions], ["secret", "secret", "secret"])
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [300.0, 300.0])

    def test_batch_continues_after_a_submission_failure(self):
        with tempfile.TemporaryDirectory() as temp_directory:
            config_path = self._write_config(Path(temp_directory))
            attempted = []

            def fake_submit_job(config, payload, token):
                attempted.append(payload["stock_code"])
                if payload["stock_code"] == "NVDA":
                    raise RuntimeError("temporary failure")
                return f"job-{payload['stock_code'].lower()}"

            with (
                patch.dict(os.environ, {"TEST_SKILL_RUNNER_TOKEN": "secret"}),
                patch.object(scheduler, "submit_job", side_effect=fake_submit_job),
                patch.object(scheduler.time, "sleep") as sleep,
            ):
                result = scheduler.run(
                    SimpleNamespace(config=config_path, dry_run=False, now_utc="2026-08-28T11:00:00Z")
                )
            self._close_logger()

        self.assertEqual(result, 3)
        self.assertEqual(attempted, ["QQQ", "NVDA", "META"])
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [300.0, 300.0])


if __name__ == "__main__":
    unittest.main()
