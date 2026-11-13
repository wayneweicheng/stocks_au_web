import importlib.util
import json
import logging
import tempfile
import unittest
from argparse import Namespace
from contextlib import contextmanager
from datetime import date, datetime
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).with_name("run-spx-map-scheduler.py")
SPEC = importlib.util.spec_from_file_location("spx_map_scheduler", SCRIPT)
assert SPEC and SPEC.loader
scheduler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scheduler)


@contextmanager
def acquired_lock(_path):
    yield True


class SpxMapSchedulerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.state_path = self.root / "processed.json"
        self.log_dir = self.root / "logs"
        self.logger = logging.getLogger(f"test.spx-map.{id(self)}")
        self.config = {
            "runner_url": "http://runner.invalid", "endpoint": "/api/jobs/spx-map",
            "token_env": "SKILL_RUNNER_API_TOKEN", "token_dotenv": "backend/.env",
            "processed_state_file": str(self.state_path), "log_directory": str(self.log_dir),
            "payload": {"as_at": "{{current_time}} Australia/Sydney", "timeout_minutes": 120},
            "current_time": {"timezone": "Australia/Sydney", "format": "%Y-%m-%d %H:%M"},
        }
        # 18:05 Sydney on Tuesday 2026-11-10; Market Flow date is Monday 2026-11-09.
        self.args = Namespace(now_utc="2026-11-10T07:05:00Z", dry_run=False)

    def tearDown(self):
        self.temp.cleanup()

    def run_tick(self, **patches):
        stack = [patch.object(scheduler.common, "single_instance", acquired_lock),
                 patch.object(scheduler, "read_secret", return_value="secret")]
        stack.extend(patches.values())
        with stack[0], stack[1]:
            for context in stack[2:]:
                context.__enter__()
            try:
                return scheduler.run_tick(self.args, self.config, self.logger, self.log_dir)
            finally:
                for context in reversed(stack[2:]):
                    context.__exit__(None, None, None)

    def test_market_flow_date_and_symbol_normalization(self):
        local = datetime(2026, 11, 10, 18, 5, tzinfo=scheduler.SYDNEY)
        self.assertEqual(scheduler.market_flow_date(local), date(2026, 11, 9))
        self.assertEqual(scheduler.normalize_code("spxw.US"), "SPXW")
        self.assertTrue(scheduler.in_window(local))
        self.assertFalse(scheduler.in_window(datetime(2026, 11, 10, 23, 50, tzinfo=scheduler.SYDNEY)))

    def test_absent_spxw_is_not_marked_and_next_tick_submits_once(self):
        absent = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPY"})
        self.assertEqual(self.run_tick(absent=absent), 0)
        self.assertFalse(self.state_path.exists())

        eligible = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPXW", "SPY"})
        submit = patch.object(scheduler, "submit_spx_map_job", return_value="job-123")
        self.assertEqual(self.run_tick(eligible=eligible, submit=submit), 0)
        state = json.loads(self.state_path.read_text(encoding="utf-8"))
        entry = state["dates"]["2026-11-09"]
        self.assertEqual(entry["status"], "submitted")
        self.assertEqual(entry["job_id"], "job-123")
        self.assertEqual(entry["as_at"], "2026-11-10 18:05 Australia/Sydney")

        again_eligible = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPXW"})
        never_submit = patch.object(scheduler, "submit_spx_map_job", side_effect=AssertionError("duplicate POST"))
        self.assertEqual(self.run_tick(eligible=again_eligible, submit=never_submit), 0)

    def test_uncertain_submission_is_remembered_and_not_retried(self):
        def uncertain(*_args):
            raise scheduler.SubmissionUncertain("timeout")
        eligible = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPXW"})
        submit = patch.object(scheduler, "submit_spx_map_job", side_effect=uncertain)
        self.assertEqual(self.run_tick(eligible=eligible, submit=submit), 3)
        state = json.loads(self.state_path.read_text(encoding="utf-8"))
        self.assertEqual(state["dates"]["2026-11-09"]["status"], "uncertain")

        eligible_again = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPXW"})
        never_submit = patch.object(scheduler, "submit_spx_map_job", side_effect=AssertionError("duplicate POST"))
        self.assertEqual(self.run_tick(eligible=eligible_again, submit=never_submit), 0)

    def test_explicit_runner_rejection_clears_reservation_for_next_tick(self):
        eligible = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPXW"})
        submit = patch.object(scheduler, "submit_spx_map_job", side_effect=scheduler.SubmissionRejected("queue full"))
        self.assertEqual(self.run_tick(eligible=eligible, submit=submit), 3)
        state = json.loads(self.state_path.read_text(encoding="utf-8"))
        self.assertNotIn("2026-11-09", state["dates"])

    def test_dry_run_never_submits_or_writes_state(self):
        self.args.dry_run = True
        eligible = patch.object(scheduler, "fetch_market_flow_codes", return_value={"SPXW"})
        never_submit = patch.object(scheduler, "submit_spx_map_job", side_effect=AssertionError("dry run POST"))
        self.assertEqual(self.run_tick(eligible=eligible, submit=never_submit), 0)
        self.assertFalse(self.state_path.exists())


if __name__ == "__main__":
    unittest.main()
