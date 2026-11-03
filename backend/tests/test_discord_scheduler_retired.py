from unittest.mock import patch

from app.core import scheduler as scheduler_module


class FakeScheduler:
    def __init__(self):
        self.jobs = {}
        self.started = False

    def add_listener(self, *_args):
        pass

    def add_job(self, _callback, *, id, **kwargs):
        self.jobs[id] = kwargs

    def start(self):
        self.started = True

    def get_jobs(self):
        return []


def test_start_scheduler_does_not_register_daily_discord_followers():
    scheduler = FakeScheduler()
    with patch.object(scheduler_module, "get_scheduler", return_value=scheduler), patch.object(scheduler_module, "_is_running", False):
        scheduler_module.start_scheduler()
    assert scheduler.started
    assert "discord_market_intelligence" not in scheduler.jobs
    assert {"volatility_selective_scan", "volatility_selective_manual_monitor"}.issubset(scheduler.jobs)
