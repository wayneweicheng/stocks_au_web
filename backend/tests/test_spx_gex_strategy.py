from __future__ import annotations

import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import date, datetime, timedelta
from io import StringIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch
from zoneinfo import ZoneInfo

from app.spx_gex_strategy.calendar import USCashCalendar
from app.spx_gex_strategy.cli import main as strategy_cli_main, parse_as_of
from app.spx_gex_strategy.data import (
    DataValidationError,
    SqlServerMarketDataRepository,
    aggregate_daily_gex,
    parse_market_bars,
)
from app.spx_gex_strategy.features import classify_observations, nq_daily_closes
from app.spx_gex_strategy.models import (
    DailyGexObservation,
    Direction,
    EnvironmentType,
    MarketBar,
    SignalClassification,
    SignalEvaluation,
    TradePlan,
)
from app.spx_gex_strategy.report import render_html_report
from app.spx_gex_strategy.notifications import NotificationService
from app.spx_gex_strategy.simulation import (
    first_touch,
    simulate_normal_green,
    simulate_reversal_green,
)
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
        self.assertTrue(call.kwargs["send_notification"])
        self.assertEqual(call.kwargs["now"].isoformat(), "2026-08-05T17:30:00+10:00")

    def test_daily_cli_can_generate_report_without_notification(self):
        service = Mock()
        service.run_daily_signal.return_value = {"notification_sent": False}
        with patch("app.spx_gex_strategy.cli._service", return_value=service), redirect_stdout(StringIO()):
            exit_code = strategy_cli_main(
                [
                    "daily",
                    "--as-of",
                    "2026-08-05 5:30pm",
                    "--timezone",
                    "Australia/Sydney",
                    "--no-notification",
                ]
            )
        self.assertEqual(exit_code, 0)
        self.assertFalse(service.run_daily_signal.call_args.kwargs["send_notification"])

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

    def test_nq_daily_close_excludes_overnight_and_post_close_bars(self):
        zone = ZoneInfo("America/New_York")
        bars = [
            MarketBar(datetime(2026, 1, 5, 15, 30, tzinfo=zone), 100, 101, 99, 100),
            MarketBar(datetime(2026, 1, 5, 16, 0, tzinfo=zone), 100, 102, 99, 101),
            MarketBar(datetime(2026, 1, 5, 23, 30, tzinfo=zone), 101, 110, 100, 109),
        ]

        closes = nq_daily_closes(bars, USCashCalendar())

        self.assertEqual(closes[date(2026, 1, 5)], 100)

    def test_raw_gex_requires_exact_four_capital_rows(self):
        rows = [
            {"ObservationDate": "2026-01-02", "CapitalType": code, "GEXDelta": value, "GEX": value * 10}
            for code, value in (("BC", 10), ("BP", 20), ("SC", 5), ("SP", 15))
        ]
        observations = aggregate_daily_gex(rows)
        self.assertEqual(observations[0].total_abs_gex_delta, 50)
        self.assertAlmostEqual(observations[0].sp_delta_share, 0.3)

    def test_yellow_sc_low_uses_sc_gex_level_not_sc_gex_delta(self):
        rows = []
        start = date(2026, 1, 2)
        for offset in range(61):
            observation_date = start + timedelta(days=offset)
            current = offset == 60
            values = {
                "BC": (64588 if current else 1000, 10000),
                "BP": (-56932 if current else -1000, -10000),
                "SC": (-6131 if current else -1000, 57041 if current else 60000),
                "SP": (1301 if current else 500, -16280 if current else -10000),
            }
            for capital_type, (gex_delta, gex_level) in values.items():
                rows.append(
                    {
                        "ObservationDate": observation_date.isoformat(),
                        "CapitalType": capital_type,
                        "GEXDelta": gex_delta,
                        "GEX": gex_level,
                        "Signal": "BEARISH" if current else None,
                    }
                )

        observations = aggregate_daily_gex(rows)
        target = classify_observations(observations, USCashCalendar(), lookback_days=60)[-1]
        self.assertEqual(target.observation.derived["SC_GEX_current"], 57041)
        self.assertEqual(target.sc_rolling_median_60, 60000)
        self.assertEqual(target.classification, SignalClassification.RELIABLE_YELLOW)

    def test_canonical_export_compat_does_not_reconstruct_blank_signal(self):
        from app.spx_gex_strategy.backtest import canonical_export_compat_observations

        observation = DailyGexObservation(
            observation_date=date(2025, 3, 6),
            bc_gex_delta=10,
            bp_gex_delta=-10,
            sc_gex_delta=-5,
            sp_gex_delta=2,
            total_abs_gex_delta=27,
            close=5738.52,
            vwap=None,
            put_call_ratio=0.760268,
            close_change_pct=-2.4332,
            pcr_change_pct=-33.4138,
            signal_raw="BULLISH",
            sc_gex=10000,
        )
        compatible = canonical_export_compat_observations(
            [observation],
            [{"ObservationDate": "2025-03-06", "Signal": "", "CloseChangePct": "", "PCRChangePct": ""}],
        )
        self.assertEqual(observation.signal_raw, "BULLISH")
        self.assertIsNone(compatible[0].signal_raw)
        self.assertIsNone(compatible[0].close_change_pct)
        self.assertIsNone(compatible[0].pcr_change_pct)

    def test_green_classification_is_identical_under_yellow_a_and_b(self):
        observation_date = date(2026, 1, 12)
        observation = DailyGexObservation(
            observation_date=observation_date,
            bc_gex_delta=10,
            bp_gex_delta=-10,
            sc_gex_delta=-5,
            sp_gex_delta=2,
            total_abs_gex_delta=27,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BULLISH",
            sc_gex=10000,
        )
        calendar = USCashCalendar()
        prior_date = calendar.session_offset(observation_date, -5)
        closes = {prior_date: 100.0, observation_date: 99.0}
        a = classify_observations(
            [observation], calendar, closes, sc_lookback_days=60, sp_lookback_days=60, sp_quantile=0.75
        )[0]
        b = classify_observations(
            [observation], calendar, closes, sc_lookback_days=60, sp_lookback_days=120, sp_quantile=0.60
        )[0]
        self.assertEqual(a.classification, SignalClassification.REVERSAL_GREEN)
        self.assertEqual(a.classification, b.classification)

    def test_sp_current_row_is_excluded_and_yellow_is_deterministic(self):
        observations = []
        start = date(2025, 1, 2)
        for offset in range(61):
            observation_date = start + timedelta(days=offset)
            sp_share = (offset + 1) / 100.0 if offset < 60 else 0.99
            observations.append(
                DailyGexObservation(
                    observation_date=observation_date,
                    bc_gex_delta=1,
                    bp_gex_delta=-1,
                    sc_gex_delta=-1,
                    sp_gex_delta=sp_share,
                    total_abs_gex_delta=1.0,
                    close=None,
                    vwap=None,
                    put_call_ratio=None,
                    close_change_pct=None,
                    pcr_change_pct=None,
                    signal_raw="BEARISH" if offset == 60 else None,
                    sc_gex=10000 if offset == 60 else 60000,
                )
            )
        first = classify_observations(observations, USCashCalendar(), lookback_days=60, sp_quantile=0.75)[-1]
        second = classify_observations(observations, USCashCalendar(), lookback_days=60, sp_quantile=0.75)[-1]
        self.assertEqual(first.classification, second.classification)
        self.assertLess(first.sp_share_p75_60, observations[-1].sp_delta_share)
        self.assertEqual(first.classification, SignalClassification.STRONG_YELLOW)

    def test_future_normal_green_does_not_reserve_before_d3(self):
        from app.spx_gex_strategy.portfolio import PortfolioManager
        from app.spx_gex_strategy.models import TradePlan

        store = StrategyStore(":memory:")
        calendar = USCashCalendar()
        manager = PortfolioManager(store, calendar, "v1.0.3-production")
        observation_date = date(2026, 1, 5)
        first_action = calendar.actionable_at(calendar.session_offset(observation_date, 3))
        evaluation = SignalEvaluation(
            observation=DailyGexObservation(
                observation_date=observation_date,
                bc_gex_delta=1,
                bp_gex_delta=-1,
                sc_gex_delta=-1,
                sp_gex_delta=1,
                total_abs_gex_delta=4,
                close=None,
                vwap=None,
                put_call_ratio=None,
                close_change_pct=None,
                pcr_change_pct=None,
                signal_raw="BULLISH",
                sc_gex=100,
            ),
            classification=SignalClassification.NORMAL_GREEN,
            actionable_at=first_action,
            action_date=first_action.date(),
            trade_allowed=True,
            skip_reason=None,
        )
        signal_id, _ = store.save_signal(evaluation, "v1.0.3-production", EnvironmentType.FORWARD_PAPER)
        plan = TradePlan(
            signal_id=signal_id,
            classification=SignalClassification.NORMAL_GREEN,
            observation_date=observation_date,
            action_date=first_action.date(),
            first_action_at=first_action,
            direction=Direction.LONG,
            entry_type="D3_MARKET",
            tp_pct=0.025,
            metadata={"base_signal_source_mode": "CAUSAL_COMPLETE"},
        )
        store.save_plan(plan)
        before_d3 = calendar.actionable_at(calendar.session_offset(observation_date, 2))
        self.assertEqual(store.open_plans(as_of=before_d3), [])
        self.assertIsNone(manager.conflict_reason(SignalClassification.NORMAL_GREEN, at=before_d3))

    def test_stale_planned_order_does_not_overlap_later_signal(self):
        from app.spx_gex_strategy.portfolio import PortfolioManager

        store = StrategyStore(":memory:")
        calendar = USCashCalendar()
        manager = PortfolioManager(store, calendar, "v1.0.3-production")
        old_evaluation = SignalEvaluation(
            observation=DailyGexObservation(
                observation_date=date(2026, 6, 26),
                bc_gex_delta=1,
                bp_gex_delta=-1,
                sc_gex_delta=-1,
                sp_gex_delta=1,
                total_abs_gex_delta=4,
                close=None,
                vwap=None,
                put_call_ratio=None,
                close_change_pct=None,
                pcr_change_pct=None,
                signal_raw="BEARISH",
                sc_gex=100,
            ),
            classification=SignalClassification.STRONG_YELLOW,
            actionable_at=calendar.actionable_at(date(2026, 6, 29)),
            action_date=date(2026, 6, 29),
            trade_allowed=True,
            skip_reason=None,
        )
        old_signal_id, _ = store.save_signal(
            old_evaluation, "v1.0.3-production", EnvironmentType.FORWARD_PAPER
        )
        old_action = calendar.actionable_at(date(2026, 6, 29))
        store.save_plan(
            TradePlan(
                signal_id=old_signal_id,
                classification=SignalClassification.STRONG_YELLOW,
                observation_date=date(2026, 6, 26),
                action_date=date(2026, 6, 29),
                first_action_at=old_action,
                direction=Direction.SHORT,
                entry_type="D1_MARKET",
                tp_pct=0.008,
                sl_pct=0.010,
            )
        )
        current_action = calendar.actionable_at(date(2026, 8, 12))
        self.assertIsNone(
            manager.conflict_reason(SignalClassification.REVERSAL_GREEN, at=current_action)
        )

    def test_live_qqq_quantity_uses_qqq_quote_not_nq_proxy(self):
        from app.spx_gex_strategy.notifications import signal_notification
        from app.spx_gex_strategy.models import PortfolioSnapshot, PortfolioState

        observation = DailyGexObservation(
            observation_date=date(2026, 1, 5),
            bc_gex_delta=10,
            bp_gex_delta=-10,
            sc_gex_delta=-5,
            sp_gex_delta=2,
            total_abs_gex_delta=27,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BEARISH",
            sc_gex=100,
            derived={"SC_lookback_days": 60, "SP_lookback_days": 60, "SP_threshold_quantile": 0.75},
        )
        evaluation = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.RELIABLE_YELLOW,
            actionable_at=datetime(2026, 1, 6, 3, 30, tzinfo=ZoneInfo("America/New_York")),
            action_date=date(2026, 1, 6),
            trade_allowed=True,
            skip_reason=None,
        )
        plan = TradePlan(
            signal_id="x",
            classification=SignalClassification.RELIABLE_YELLOW,
            observation_date=date(2026, 1, 5),
            action_date=date(2026, 1, 6),
            first_action_at=evaluation.actionable_at,
            direction=Direction.SHORT,
            entry_type="D1_MARKET",
            tp_pct=0.004,
            sl_pct=0.008,
        )
        message = signal_notification(
            evaluation,
            PortfolioSnapshot(PortfolioState.FLAT, 100000.0, 100000.0, 1.0),
            "v1.0.3-production",
            plan=plan,
            reference_price=20000.0,
            nq_snapshot={"price": 20000.0, "previous_close": 19900.0},
            qqq_snapshot={"price": 500.0, "source": "ib_live"},
        )[2]
        self.assertIn("Suggested Quantity (actual QQQ quote): 200 QQQ shares", message)
        self.assertNotIn("5 QQQ shares", message)

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
                    {
                        "ObservationDate": "2026-01-02",
                        "CapitalType": code,
                        "GEXDelta": value,
                        "GEX": value * 10,
                    }
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

    def test_reversal_dip_expiry_is_exclusive_and_fallback_requires_exact_bar(self):
        zone = ZoneInfo("America/New_York")
        reference_time = datetime(2026, 1, 5, 3, 30, tzinfo=zone)
        fallback_time = datetime(2026, 1, 7, 3, 30, tzinfo=zone)
        cash_close = datetime(2026, 1, 9, 16, 0, tzinfo=zone)
        bars = [
            MarketBar(reference_time, 100, 101, 100, 100),
            # A bar beginning exactly at D3 must not be used to fill the dip.
            MarketBar(fallback_time, 101, 102, 98, 101),
            MarketBar(datetime(2026, 1, 7, 4, 0, tzinfo=zone), 102, 103, 101, 102),
            MarketBar(datetime(2026, 1, 9, 15, 30, tzinfo=zone), 102, 103, 101, 102),
        ]

        result = simulate_reversal_green(
            reference_time,
            100,
            0.01,
            fallback_time,
            fallback_time,
            cash_close,
            bars,
        )

        self.assertEqual(result["entry_type"], "D3_FALLBACK")
        self.assertEqual(result["entry_time"], fallback_time)
        self.assertEqual(result["entry_price"], 101)

        missing_exact_fallback = simulate_reversal_green(
            reference_time,
            100,
            0.01,
            fallback_time,
            fallback_time,
            cash_close,
            [bar for bar in bars if bar.timestamp != fallback_time],
        )
        self.assertEqual(missing_exact_fallback["status"], "DATA_ERROR")
        self.assertEqual(missing_exact_fallback["reason"], "MISSING_D3_FALLBACK_BAR")

    def test_green_cash_close_uses_last_bar_ending_at_cash_close(self):
        zone = ZoneInfo("America/New_York")
        entry_time = datetime(2026, 1, 7, 3, 30, tzinfo=zone)
        cash_close = datetime(2026, 1, 9, 16, 0, tzinfo=zone)
        bars = [
            MarketBar(entry_time, 100, 101, 99, 100),
            MarketBar(datetime(2026, 1, 9, 15, 30, tzinfo=zone), 100, 101, 99, 100),
            MarketBar(datetime(2026, 1, 9, 16, 0, tzinfo=zone), 100, 110, 99, 109),
        ]

        result = simulate_normal_green(entry_time, 100, 0.25, cash_close, bars)

        self.assertEqual(result["exit_reason"], "TIME_EXIT")
        self.assertEqual(result["exit_time"], datetime(2026, 1, 9, 15, 30, tzinfo=zone))
        self.assertEqual(result["exit_price"], 100)

        missing_d5 = simulate_normal_green(
            entry_time,
            100,
            0.25,
            cash_close,
            [
                bars[0],
                MarketBar(datetime(2026, 1, 8, 15, 30, tzinfo=zone), 100, 101, 99, 101),
            ],
        )
        self.assertEqual(missing_d5["status"], "DATA_ERROR")
        self.assertEqual(missing_d5["reason"], "MISSING_NORMAL_GREEN_EXIT")

    def test_backtest_neutralizes_quarterly_nq_roll_gap(self):
        from app.spx_gex_strategy.backtest import neutralize_nq_roll_gaps

        zone = ZoneInfo("America/New_York")
        bars = [
            MarketBar(datetime(2025, 3, 13, 9, 0, tzinfo=zone), 99, 101, 98, 100),
            MarketBar(datetime(2025, 3, 13, 9, 30, tzinfo=zone), 110, 112, 109, 111),
        ]

        adjusted, roll_metadata = neutralize_nq_roll_gaps(bars)

        self.assertEqual(len(roll_metadata), 1)
        self.assertAlmostEqual(adjusted[1].open, 100.0)
        self.assertAlmostEqual(adjusted[1].close, 100.9090909)

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
            sc_gex=120,
            sp_gex=-20,
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
                "SC_GEXDelta_current": 120,
                "SC_GEX_threshold": 100,
                "SP_GEX_current": -20,
                "SP_GEXDelta_current": 10,
                "SP_delta_share_current": 0.0625,
                "SP_delta_share_threshold": 0.10,
            }
        )
        store.save_signal(evaluation, "v1.0.0", EnvironmentType.FORWARD_PAPER)
        html = render_html_report(store, "v1.0.0")
        self.assertIn("Why this is Weak Yellow", html)
        self.assertIn("SC current GEX level", html)
        self.assertIn("SC current GEXDelta", html)
        self.assertIn("SP current GEX level", html)
        self.assertIn("SP current GEXDelta", html)
        self.assertIn("SC_LOW = FALSE", html)
        self.assertIn("SP_HIGH = FALSE", html)
        self.assertIn("not tradable in strategy v1", html)
        self.assertIn("Strong Yellow", html)
        self.assertIn("Tradable Yellow", html)
        self.assertIn("SC_LOW FALSE (SC GEX level 120.00 &gt; 100.00)", html)
        self.assertIn("SP_HIGH FALSE (6.25% &lt;= 10.00%)", html)

    def test_report_gives_reversal_action_and_historical_performance(self):
        store = StrategyStore(":memory:")
        store.ensure_portfolio(100000, 1.0)
        observation = DailyGexObservation(
            observation_date=date(2026, 8, 11),
            bc_gex_delta=10,
            bp_gex_delta=-10,
            sc_gex_delta=-5,
            sp_gex_delta=2,
            total_abs_gex_delta=27,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BULLISH",
            sc_gex=100,
            derived={"prior_5d_nq_return": -0.0081},
        )
        evaluation = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.REVERSAL_GREEN,
            actionable_at=datetime.fromisoformat("2026-08-12T03:30:00-04:00"),
            action_date=date(2026, 8, 12),
            trade_allowed=False,
            skip_reason="PORTFOLIO_CONFLICT",
            prior_5d_nq_return=-0.0081,
        )
        signal_id, _ = store.save_signal(evaluation, "v1.0.3-production", EnvironmentType.FORWARD_PAPER)
        html = render_html_report(
            store,
            "v1.0.3-production",
            qqq_reference={
                "reference_price": 500.0,
                "reference_timestamp": "2026-08-12T03:30:00-04:00",
                "reference_source": "IB_HISTORICAL_03:30",
            },
            focus_date=date(2026, 8, 11),
        )
        self.assertIn("What this signal means", html)
        self.assertIn("Reversal Green action plan", html)
        self.assertIn("DO NOT PLACE AN ORDER", html)
        self.assertIn("78.57%", html)
        self.assertIn("Average return: +1.459%", html)
        self.assertIn("QQQ ORDER REFERENCE", html)
        self.assertIn("IB_HISTORICAL_03:30", html)
        self.assertNotIn("tradable LONG QQQ", html)

    def test_qqq_reference_uses_live_before_boundary_and_historical_after(self):
        settings = SimpleNamespace(
            spx_gex_timezone="America/New_York",
            spx_gex_db_path=":memory:",
            spx_gex_initial_capital=100000.0,
            spx_gex_exposure_factor=1.0,
            spx_gex_strategy_version="v1.0.3-production",
            spx_gex_shadow_enabled=False,
            pushover_user_key="",
            pushover_app_token="",
            pushover_device="",
            pushover_sound="",
        )
        service = SPXGEXStrategyService(settings)
        boundary = datetime.fromisoformat("2026-08-12T03:30:00-04:00")
        service._live_qqq = Mock(return_value={"price": 500.0, "timestamp": "before"})
        before = service._qqq_reference(boundary, datetime.fromisoformat("2026-08-12T03:29:00-04:00"))
        self.assertEqual(before["reference_source"], "IB_LIVE_BEFORE_03:30")
        self.assertEqual(before["reference_price"], 500.0)
        with patch(
            "app.spx_gex_strategy.service.get_qqq_reference_snapshot",
            return_value={"reference_price": 501.0, "reference_source": "IB_HISTORICAL_03:30"},
        ) as historical:
            after = service._qqq_reference(boundary, datetime.fromisoformat("2026-08-12T03:31:00-04:00"))
        historical.assert_called_once()
        self.assertEqual(after["reference_source"], "IB_HISTORICAL_03:30")
        self.assertEqual(after["reference_price"], 501.0)

    def test_missing_qqq_reference_does_not_make_reversal_signal_untradable(self):
        store = StrategyStore(":memory:")
        store.ensure_portfolio(100000, 1.0)
        observation = DailyGexObservation(
            observation_date=date(2026, 8, 11),
            bc_gex_delta=10,
            bp_gex_delta=-10,
            sc_gex_delta=-5,
            sp_gex_delta=2,
            total_abs_gex_delta=27,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BULLISH",
            sc_gex=100,
            derived={
                "prior_5d_nq_return": -0.0081,
                "QQQ_reference_unavailable_reason": "IB returned no QQQ bar",
            },
        )
        evaluation = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.REVERSAL_GREEN,
            actionable_at=datetime.fromisoformat("2026-08-12T03:30:00-04:00"),
            action_date=date(2026, 8, 12),
            trade_allowed=True,
            skip_reason=None,
            prior_5d_nq_return=-0.0081,
        )
        store.save_signal(evaluation, "v1.0.3-production", EnvironmentType.FORWARD_PAPER)
        html = render_html_report(store, "v1.0.3-production", focus_date=date(2026, 8, 11))
        self.assertIn("ACTION: PLACE A QQQ BUY LIMIT ORDER", html)
        self.assertIn("Q0 × 0.99", html)
        self.assertIn("Manual price required", html)
        self.assertNotIn("Reason: MISSING_LIVE_QQQ_QUOTE", html)

    def test_recent_signals_can_filter_out_stale_strategy_versions(self):
        store = StrategyStore(":memory:")
        observation = DailyGexObservation(
            observation_date=date(2026, 8, 4),
            bc_gex_delta=100,
            bp_gex_delta=-100,
            sc_gex_delta=-10,
            sp_gex_delta=10,
            total_abs_gex_delta=220,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BEARISH",
            sc_gex=57041,
            sp_gex=-16280,
        )
        evaluation = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.WEAK_YELLOW,
            trade_allowed=False,
            actionable_at=None,
            action_date=None,
            skip_reason="NON_TRADABLE_YELLOW_CLASSIFICATION",
        )
        store.save_signal(evaluation, "v1.0.0", EnvironmentType.FORWARD_PAPER)
        store.save_signal(evaluation, "v1.0.1", EnvironmentType.FORWARD_PAPER)

        rows = store.recent_signals(strategy_version="v1.0.1")

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["strategy_version"], "v1.0.1")

    def test_production_and_shadow_classifications_persist_as_a_pair(self):
        store = StrategyStore(":memory:")
        observation = DailyGexObservation(
            observation_date=date(2026, 8, 4),
            bc_gex_delta=100,
            bp_gex_delta=-100,
            sc_gex_delta=-10,
            sp_gex_delta=10,
            total_abs_gex_delta=220,
            close=None,
            vwap=None,
            put_call_ratio=None,
            close_change_pct=None,
            pcr_change_pct=None,
            signal_raw="BEARISH",
            sc_gex=57041,
            sp_gex=-16280,
        )
        production = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.RELIABLE_YELLOW,
            trade_allowed=True,
            skip_reason=None,
            actionable_at=datetime.fromisoformat("2026-08-05T03:30:00-04:00"),
            action_date=date(2026, 8, 5),
        )
        shadow = SignalEvaluation(
            observation=observation,
            classification=SignalClassification.STRONG_YELLOW,
            trade_allowed=True,
            skip_reason=None,
            actionable_at=production.actionable_at,
            action_date=production.action_date,
        )
        production_id, _ = store.save_signal(production, "v1.0.2", EnvironmentType.FORWARD_PAPER)
        shadow_id, _ = store.save_signal(shadow, "v1.1", EnvironmentType.FORWARD_PAPER)
        comparison_id = store.save_strategy_comparison(
            {
                "observation_date": "2026-08-04",
                "production_signal_id": production_id,
                "shadow_signal_id": shadow_id,
                "production_strategy_version": "v1.0.2",
                "shadow_strategy_version": "v1.1",
                "environment_type": "FORWARD_PAPER",
                "production_classification": "RELIABLE_YELLOW",
                "shadow_classification": "STRONG_YELLOW",
                "production_trade_allowed": 1,
                "shadow_trade_allowed": 1,
                "production_outcome_status": "PENDING_MANUAL",
                "shadow_outcome_status": "PENDING",
            }
        )
        row = store.recent_strategy_comparisons(1)[0]
        self.assertEqual(row["comparison_id"], comparison_id)
        self.assertEqual(row["production_classification"], "RELIABLE_YELLOW")
        self.assertEqual(row["shadow_classification"], "STRONG_YELLOW")

    def test_daily_signal_saves_shadow_without_creating_a_shadow_plan(self):
        observations = []
        start = date(2026, 1, 2)
        for offset in range(61):
            observation_date = start + timedelta(days=offset)
            current = offset == 60
            observations.append(
                DailyGexObservation(
                    observation_date=observation_date,
                    bc_gex_delta=64588 if current else 1000,
                    bp_gex_delta=-56932 if current else -1000,
                    sc_gex_delta=-6131 if current else -1000,
                    sp_gex_delta=1301 if current else 500,
                    total_abs_gex_delta=123952 if current else 3500,
                    close=None,
                    vwap=None,
                    put_call_ratio=None,
                    close_change_pct=None,
                    pcr_change_pct=None,
                    signal_raw="BEARISH" if current else None,
                    sc_gex=57041 if current else 60000,
                    sp_gex=-16280 if current else -10000,
                )
            )
        settings = SimpleNamespace(
            spx_gex_strategy_version="v1.0.2",
            spx_gex_shadow_enabled=True,
            spx_gex_shadow_strategy_version="v1.1",
            spx_gex_shadow_sc_lookback_days=60,
            spx_gex_shadow_sp_lookback_days=120,
            spx_gex_shadow_sp_threshold_quantile=0.60,
            spx_gex_timezone="America/New_York",
            spx_gex_db_path=":memory:",
            spx_gex_initial_capital=100000.0,
            spx_gex_exposure_factor=1.0,
            spx_gex_require_live_nq=False,
            spx_gex_report_url="https://example.test/api/spx-gex/report.html",
            spx_gex_report_token="",
            pushover_user_key="",
            pushover_app_token="",
            pushover_device="",
            pushover_sound="",
        )
        service = SPXGEXStrategyService(settings)
        service._source_data = Mock(return_value=(observations, []))
        target = observations[-1].observation_date
        result = service.run_daily_signal(
            now=datetime(2026, 3, 3, 17, 30, tzinfo=ZoneInfo("Australia/Sydney")),
            observation_date=target,
            send_notification=False,
        )
        self.assertEqual(result["strategy_version"], "v1.0.2")
        self.assertEqual(result["shadow"]["shadow_strategy_version"], "v1.1")
        self.assertEqual(len(service.store.recent_signals(strategy_version="v1.0.2")), 1)
        self.assertEqual(len(service.store.recent_signals(strategy_version="v1.1")), 1)
        self.assertEqual(len(service.store.recent_strategy_comparisons()), 1)
        self.assertEqual(len(service.store.open_plans()), 1)

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

    def test_stale_summary_file_is_rejected_without_gex_levels(self):
        root = Path(__file__).resolve().parents[2]
        from app.spx_gex_strategy.data import FileMarketDataRepository

        repository = FileMarketDataRepository(
            root / "backend/data/option_gex_delta_signal_SPXW_2025-01-01_to_present.csv",
            root / "backend/data/NQMain_30M.csv",
        )
        with self.assertRaisesRegex(DataValidationError, "missing BC/BP/SC/SP GEX levels"):
            repository.gex_observations()

    def test_backtest_summary_includes_classification_counts_and_monthly_returns(self):
        from app.spx_gex_strategy.backtest import neutralize_nq_roll_gaps, run_backtest_from_data

        observations = []
        for offset in range(61):
            observation_date = date(2026, 1, 2) + timedelta(days=offset)
            observations.append(
                DailyGexObservation(
                    observation_date=observation_date,
                    bc_gex_delta=1000,
                    bp_gex_delta=-1000,
                    sc_gex_delta=-1000,
                    sp_gex_delta=500,
                    total_abs_gex_delta=3500,
                    close=None,
                    vwap=None,
                    put_call_ratio=None,
                    close_change_pct=None,
                    pcr_change_pct=None,
                    signal_raw="BEARISH" if offset == 60 else None,
                    bc_gex=10000,
                    bp_gex=-10000,
                    sc_gex=57041 if offset == 60 else 60000,
                    sp_gex=-10000,
                )
            )
        result = run_backtest_from_data(
            observations,
            [],
            observations[-1].observation_date,
            observations[-1].observation_date,
        )
        self.assertEqual(result["classification_counts"]["RELIABLE_YELLOW"], 1)
        self.assertEqual(result["category_breakdown"]["RELIABLE_YELLOW"]["candidate_signals"], 1)
        self.assertIn("2026-03", result["monthly_returns"])


if __name__ == "__main__":
    unittest.main()
