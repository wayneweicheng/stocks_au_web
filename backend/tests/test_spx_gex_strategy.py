from __future__ import annotations

import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import date, datetime, timedelta
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

from app.spx_gex_strategy.calendar import USCashCalendar
from app.spx_gex_strategy.cli import main as strategy_cli_main, parse_as_of
from app.spx_gex_strategy.data import SqlServerMarketDataRepository, aggregate_daily_gex, parse_market_bars
from app.spx_gex_strategy.features import classify_observations
from app.spx_gex_strategy.models import (
    DailyGexObservation,
    Direction,
    EnvironmentType,
    MarketBar,
    SignalClassification,
    SignalEvaluation,
)
from app.spx_gex_strategy.report import render_html_report
from app.spx_gex_strategy.notifications import NotificationService
from app.spx_gex_strategy.simulation import first_touch
from app.spx_gex_strategy.service import SPXGEXStrategyService
from app.spx_gex_strategy.storage import StrategyStore


class SPXGEXStrategyTests(unittest.TestCase):
    def test_daily_as_of_accepts_sydney_local_time(self):
        as_of = parse_as_of("2026-08-05 5:30pm", "Australia/Sydney")
        self.assertEqual(as_of.isoformat(), "2026-08-05T17:30:00+10:00")
        self.assertEqual(USCashCalendar().latest_completed_session(as_of), date(2026, 8, 4))

    def test_daily_as_of_requires_timezone_for_naive_time(self):
        with self.assertRaisesRegex(ValueError, "--timezone is required"):
            parse_as_of("2026-08-05 17:30")

    def test_daily_cli_forwards_force_notification(self):
        service = Mock()
        service.run_daily_signal.return_value = {"notification_sent": True}
        with patch("app.spx_gex_strategy.cli._service", return_value=service), redirect_stdout(StringIO()):
            exit_code = strategy_cli_main(
                [
                    "daily",
                    "--as-of",
                    "2026-08-05 5:30pm",
                    "--timezone",
                    "Australia/Sydney",
                    "--force-notification",
                ]
            )
        self.assertEqual(exit_code, 0)
        call = service.run_daily_signal.call_args
        self.assertTrue(call.kwargs["force_notification"])
        self.assertEqual(call.kwargs["now"].isoformat(), "2026-08-05T17:30:00+10:00")

    def test_notification_carries_native_report_url(self):
        class FakePushover:
            def __init__(self):
                self.kwargs = None

            def send(self, *args, **kwargs):
                self.kwargs = kwargs
                return "provider-id"

        store = StrategyStore(":memory:")
        fake = FakePushover()
        sent = NotificationService(store, fake).send_idempotent(
            "test-notification",
            "SIGNAL_READY",
            "Title",
            "Message",
            url="https://example.test/report.html",
            url_title="Open report",
        )
        self.assertTrue(sent)
        self.assertEqual(fake.kwargs["priority"], "high")
        self.assertEqual(fake.kwargs["url"], "https://example.test/report.html")
        self.assertEqual(fake.kwargs["url_title"], "Open report")

    def test_report_url_targets_the_immutable_timestamped_file(self):
        service = SPXGEXStrategyService.__new__(SPXGEXStrategyService)
        service.settings = SimpleNamespace(
            spx_gex_report_url="https://example.test/api/spx-gex/report.html",
            spx_gex_report_token="secret",
        )
        self.assertEqual(
            service._report_url("spx-gex-report-2026-08-05-20260810173500.html"),
            "https://example.test/api/spx-gex/reports/"
            "spx-gex-report-2026-08-05-20260810173500.html?report_token=secret",
        )

    def test_calendar_keeps_action_time_at_0330_across_dst(self):
        calendar = USCashCalendar()
        summer = calendar.actionable_at(date(2026, 7, 6))
        winter = calendar.actionable_at(date(2026, 1, 5))
        self.assertEqual(summer.hour, 3)
        self.assertEqual(summer.utcoffset().total_seconds(), -4 * 3600)
        self.assertEqual(winter.utcoffset().total_seconds(), -5 * 3600)

    def test_raw_gex_requires_exact_four_capital_rows(self):
        rows = [
            {"ObservationDate": "2026-01-02", "CapitalType": code, "GEXDelta": value}
            for code, value in (("BC", 10), ("BP", 20), ("SC", 5), ("SP", 15))
        ]
        observations = aggregate_daily_gex(rows)
        self.assertEqual(observations[0].total_abs_gex_delta, 50)
        self.assertAlmostEqual(observations[0].sp_delta_share, 0.3)

    def test_sql_repository_uses_shared_trading_orders_connection(self):
        class FakeConnection:
            def __init__(self):
                self.closed = False

            def close(self):
                self.closed = True

        class FakeModel:
            def __init__(self):
                self.cnxn = FakeConnection()

            def execute_read_query(self, _sql, _params):
                return [
                    {"ObservationDate": "2026-01-02", "CapitalType": code, "GEXDelta": value}
                    for code, value in (("BC", 10), ("BP", 20), ("SC", 5), ("SP", 15))
                ]

        fake_model = FakeModel()
        with patch(
            "arkofdata_common.SQLServerHelper.SQLServerHelper.SQLServerModel",
            return_value=fake_model,
        ) as factory:
            observations = SqlServerMarketDataRepository("StockDB_US").gex_observations(
                date(2026, 1, 1), date(2026, 1, 2)
            )
        factory.assert_called_once_with(database="StockDB_US")
        self.assertEqual(len(observations), 1)
        self.assertTrue(fake_model.cnxn.closed)

    def test_first_touch_gap_and_same_bar_are_conservative(self):
        entry = 100.0
        bars = [
            MarketBar(datetime(2026, 1, 2, 3, 30), 100, 102, 98, 100),
        ]
        result = first_touch(entry, Direction.SHORT, 99, 101, bars)
        self.assertEqual(result.exit_reason, "SL_HIT")
        self.assertTrue(result.ambiguous)

    def test_report_renders_without_trades(self):
        with tempfile.TemporaryDirectory() as directory:
            store = StrategyStore(Path(directory) / "strategy.sqlite3")
            store.ensure_portfolio(100000, 1.0)
            html = render_html_report(store, "v1.0.0")
            self.assertIn("SPX GEX Signal Report", html)
            self.assertIn("No shadow trades", html)
            self.assertIn("Yellow classification guide", html)

    def test_report_explains_weak_yellow_from_saved_thresholds(self):
        store = StrategyStore(":memory:")
        store.ensure_portfolio(100000, 1.0)
        observation = DailyGexObservation(
            observation_date=date(2026, 8, 4),
            bc_gex_delta=10,
            bp_gex_delta=20,
            sc_gex_delta=120,
            sp_gex_delta=10,
            total_abs_gex_delta=160,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BEARISH",
        )
        evaluation = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.WEAK_YELLOW,
            actionable_at=datetime.fromisoformat("2026-08-05T03:30:00-04:00"),
            action_date=date(2026, 8, 5),
            trade_allowed=False,
            skip_reason="NON_TRADABLE_YELLOW_CLASSIFICATION",
            sc_rolling_median_60=100,
            sp_share_p75_60=0.10,
        )
        observation.derived.update(
            {
                "SC_GEX_current": 120,
                "SC_GEX_threshold": 100,
                "SP_delta_share_current": 0.0625,
                "SP_delta_share_threshold": 0.10,
            }
        )
        store.save_signal(evaluation, "v1.0.0", EnvironmentType.FORWARD_PAPER)
        html = render_html_report(store, "v1.0.0")
        self.assertIn("Why this is Weak Yellow", html)
        self.assertIn("SC_LOW = FALSE", html)
        self.assertIn("SP_HIGH = FALSE", html)
        self.assertIn("not tradable in strategy v1", html)
        self.assertIn("Strong Yellow", html)
        self.assertIn("Tradable Yellow", html)
        self.assertIn("SC_LOW FALSE (120.00 &gt; 100.00)", html)
        self.assertIn("SP_HIGH FALSE (6.25% &lt;= 10.00%)", html)

    def test_report_snapshots_are_append_only(self):
        with tempfile.TemporaryDirectory() as directory:
            store = StrategyStore(Path(directory) / "strategy.sqlite3")
            generated = datetime.fromisoformat("2026-08-10T17:35:00+10:00")
            first = store.save_report(
                date(2026, 8, 5),
                "<html>first</html>",
                "v1.0.0",
                "FORWARD_PAPER",
                observation_date=date(2026, 8, 4),
                generated_at=generated,
            )
            second = store.save_report(
                date(2026, 8, 5),
                "<html>first</html>",
                "v1.0.0",
                "FORWARD_PAPER",
                observation_date=date(2026, 8, 4),
                generated_at=generated + timedelta(microseconds=1),
            )
            self.assertNotEqual(first, second)
            self.assertEqual(len(store.recent_reports()), 2)
            first_row = store.report(first)
            second_row = store.report(second)
            self.assertEqual(first_row["file_name"], "spx-gex-report-2026-08-05-20260810173500.html")
            self.assertEqual(second_row["file_name"], "spx-gex-report-2026-08-05-20260810173500-02.html")
            self.assertEqual(first_row["observation_date"], "2026-08-04")
            self.assertIsNotNone(store.report_for_file_name(second_row["file_name"], "FORWARD_PAPER"))

            third = store.save_report(
                date(2026, 8, 5),
                "<html>corrected</html>",
                "v1.0.0",
                "FORWARD_PAPER",
                observation_date=date(2026, 8, 4),
                generated_at=generated + timedelta(seconds=1),
            )
            self.assertNotEqual(second, third)
            self.assertEqual(len(store.recent_reports()), 3)
            latest = store.report_for_date(date(2026, 8, 5), "FORWARD_PAPER")
            self.assertIn("<html>corrected</html>", latest["html_content"])

    def test_supplied_files_are_causal_and_new_york_timed(self):
        root = Path(__file__).resolve().parents[2]
        from app.spx_gex_strategy.data import FileMarketDataRepository
        from app.spx_gex_strategy.features import nq_daily_closes

        repository = FileMarketDataRepository(
            root / "backend/data/option_gex_delta_signal_SPXW_2025-01-01_to_present.csv",
            root / "backend/data/NQMain_30M.csv",
        )
        calendar = USCashCalendar()
        evaluations = classify_observations(
            repository.gex_observations(), calendar, nq_daily_closes(repository.nq_bars(), calendar)
        )
        target = next(item for item in evaluations if item.observation.observation_date == date(2026, 8, 6))
        self.assertEqual(target.classification, SignalClassification.NORMAL_GREEN)
        self.assertEqual(target.actionable_at.isoformat(), "2026-08-07T03:30:00-04:00")

    def test_supplied_files_produce_a_reproducible_backtest_summary(self):
        root = Path(__file__).resolve().parents[2]
        from app.spx_gex_strategy.backtest import run_backtest

        result = run_backtest(
            root / "backend/data/option_gex_delta_signal_SPXW_2025-01-01_to_present.csv",
            root / "backend/data/NQMain_30M.csv",
            date(2025, 3, 1),
            date(2026, 8, 6),
        )
        self.assertEqual(result["strategy_version"], "v1.0.0")
        self.assertGreater(result["trade_count"], 0)
        self.assertIn("unresolved_yellow", result)


if __name__ == "__main__":
    unittest.main()
