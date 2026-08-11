from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, quote, urlencode, urlsplit, urlunsplit

from . import STRATEGY_VERSION
from .calendar import USCashCalendar
from .data import DataValidationError, FileMarketDataRepository, SqlServerMarketDataRepository
from .features import classify_observations, nq_daily_closes
from .ib_market_data import get_live_nq_snapshot
from .models import EnvironmentType, SignalClassification
from .notifications import (
    NotificationService,
    PushoverClient,
    exit_notification,
    signal_notification,
)
from .portfolio import PortfolioManager
from .report import render_html_report
from .simulation import first_touch
from .storage import StrategyStore

logger = logging.getLogger("app.spx_gex_strategy.service")


class SPXGEXStrategyService:
    def __init__(self, settings: Any = None, environment_type: EnvironmentType = EnvironmentType.FORWARD_PAPER) -> None:
        if settings is None:
            from app.core.config import settings as app_settings

            settings = app_settings
        self.settings = settings
        self.environment_type = environment_type
        self.strategy_version = STRATEGY_VERSION
        self.calendar = USCashCalendar(getattr(settings, "spx_gex_timezone", "America/New_York"))
        self.store = StrategyStore(self._resolve_path(getattr(settings, "spx_gex_db_path", "data/spx_gex_strategy.sqlite3")))
        self.portfolio = PortfolioManager(
            self.store,
            self.calendar,
            strategy_version=self.strategy_version,
            initial_capital=float(getattr(settings, "spx_gex_initial_capital", 100000.0)),
            exposure_factor=float(getattr(settings, "spx_gex_exposure_factor", 1.0)),
            environment_type=environment_type,
        )
        self.notifications = NotificationService(
            self.store,
            PushoverClient(
                getattr(settings, "pushover_user_key", ""),
                getattr(settings, "pushover_app_token", ""),
                device=getattr(settings, "pushover_device", "droid4"),
                sound=getattr(settings, "pushover_sound", "echo"),
            ),
        )

    @staticmethod
    def _resolve_path(value: str) -> Path:
        if str(value) == ":memory:":
            return Path(":memory:")
        path = Path(value)
        if path.is_absolute():
            return path
        backend_root = Path(__file__).resolve().parents[2]
        return backend_root / path

    def _source_data(self, target_date: date) -> tuple[list, list]:
        lookback = int(getattr(self.settings, "spx_gex_lookback_days", 60))
        start = self.calendar.session_offset(target_date, -(lookback + 10))
        if str(getattr(self.settings, "spx_gex_data_mode", "sql")).lower() == "file":
            repository = FileMarketDataRepository(
                self._resolve_path(getattr(self.settings, "spx_gex_gex_path")),
                self._resolve_path(getattr(self.settings, "spx_gex_nq_path")),
                timezone=self.calendar.timezone_name,
            )
            return repository.gex_observations(), repository.nq_bars()
        repository = SqlServerMarketDataRepository(
            source_database=getattr(self.settings, "spx_gex_source_database", "StockDB_US"),
            nq_symbol="NQMAIN.US",
        )
        end = self.calendar.next_session(target_date, include_current=True)
        return repository.gex_observations(start, target_date), repository.nq_bars(start, end, self.calendar.timezone_name)

    def _live_nq(self) -> dict[str, Any] | None:
        if not bool(getattr(self.settings, "spx_gex_require_live_nq", True)):
            return None
        return get_live_nq_snapshot()

    def _report_url(self, file_name: str | None = None) -> str:
        url = str(
            getattr(self.settings, "spx_gex_report_url", "https://pegasus.asxstocktoolings.com.au/api/spx-gex/report.html")
            or ""
        ).strip()
        if file_name and url:
            parts = urlsplit(url)
            marker = "/api/spx-gex/"
            if marker in parts.path:
                prefix = parts.path.split(marker, 1)[0] + marker
                path = prefix + "reports/" + quote(file_name)
            else:
                path = parts.path.rsplit("/", 1)[0] + "/reports/" + quote(file_name)
            url = urlunsplit((parts.scheme, parts.netloc, path, "", parts.fragment))
        token = str(getattr(self.settings, "spx_gex_report_token", "") or "").strip()
        if token and url:
            parts = urlsplit(url)
            query = parse_qs(parts.query)
            query.setdefault("report_token", [token])
            url = urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query, doseq=True), parts.fragment))
        return url

    def _latest_report_url(self) -> str:
        row = self.store.latest_report(self.environment_type.value)
        if row is not None and row["file_name"]:
            return self._report_url(str(row["file_name"]))
        return self._report_url()

    def _send_signal(
        self,
        signal_id: str,
        evaluation,
        plan=None,
        reference_price=None,
        nq_snapshot=None,
        report_url: str | None = None,
        notification_key_suffix: str | None = None,
    ) -> bool:
        report_url = report_url or self._latest_report_url()
        notification_type, title, message = signal_notification(
            evaluation,
            self.portfolio.snapshot,
            self.strategy_version,
            plan=plan,
            reference_price=reference_price,
            nq_snapshot=nq_snapshot,
            report_url=report_url,
        )
        if evaluation.classification == SignalClassification.NO_SIGNAL and not bool(
            getattr(self.settings, "spx_gex_notification_no_signal", False)
        ):
            return False
        key = f"signal|{signal_id}|{notification_type}"
        if notification_key_suffix:
            key += f"|{notification_key_suffix}"
        return self.notifications.send_idempotent(
            key,
            notification_type,
            title,
            message,
            url=report_url,
            url_title="Open SPX GEX HTML report",
        )

    def save_report_snapshot(
        self,
        observation_date: date,
        as_of_date: date,
        generated_at: datetime,
        live_nq: dict[str, Any] | None = None,
    ) -> str:
        """Persist an immutable HTML snapshot for a completed signal date."""
        html = render_html_report(
            self.store,
            self.strategy_version,
            live_nq,
            focus_date=observation_date,
            report_as_of=as_of_date,
            generated_at=generated_at,
        )
        return self.store.save_report(
            as_of_date,
            html,
            self.strategy_version,
            self.environment_type.value,
            observation_date=observation_date,
            generated_at=generated_at,
        )

    def run_daily_signal(
        self,
        now: datetime | None = None,
        observation_date: date | None = None,
        force_notification: bool = False,
        send_notification: bool = True,
    ) -> dict[str, Any]:
        effective_now = now or datetime.now(self.calendar.timezone)
        if effective_now.tzinfo is None:
            effective_now = effective_now.replace(tzinfo=self.calendar.timezone)
        as_of_date = effective_now.date()
        generated_at = datetime.now().astimezone()
        target_date = observation_date or self.calendar.latest_completed_session(effective_now)
        started = datetime.now()
        try:
            observations, bars = self._source_data(target_date)
            by_date = {observation.observation_date: observation for observation in observations}
            target = by_date.get(target_date)
            if target is None:
                raise DataValidationError(
                    f"Source data is stale: expected latest completed US session {target_date.isoformat()}"
                )
            closes = nq_daily_closes(bars, self.calendar)
            evaluations = classify_observations(
                observations,
                self.calendar,
                closes,
                lookback_days=int(getattr(self.settings, "spx_gex_lookback_days", 60)),
            )
            evaluation = next(item for item in evaluations if item.observation.observation_date == target_date)
            live_nq = None
            reference_price = None
            if evaluation.trade_allowed:
                try:
                    live_nq = self._live_nq()
                    reference_price = live_nq.get("price") if live_nq else None
                except Exception as exc:
                    evaluation.trade_allowed = False
                    evaluation.skip_reason = f"MISSING_LIVE_NQ_QUOTE: {exc}"

            if evaluation.trade_allowed:
                conflict = self.portfolio.conflict_reason(evaluation.classification)
                if conflict:
                    evaluation.trade_allowed = False
                    evaluation.skip_reason = conflict

            signal_id, _ = self.store.save_signal(evaluation, self.strategy_version, self.environment_type)
            plan = None
            if evaluation.trade_allowed:
                plan = self.portfolio.build_plan(evaluation, reference_price=reference_price)
                plan.signal_id = signal_id
                self.store.save_plan(plan)
                snapshot = self.portfolio.snapshot
                snapshot.pending_plan_id = self.store.plan_id_for_signal(signal_id)
                self.store.update_portfolio(snapshot)

            report_id = None
            report_file_name = None
            report_url = None
            report_error = None
            try:
                report_id = self.save_report_snapshot(target_date, as_of_date, generated_at, live_nq)
                report_row = self.store.report(report_id)
                if report_row is None:
                    raise RuntimeError(f"saved report {report_id} could not be reloaded")
                report_file_name = str(report_row["file_name"])
                report_url = self._report_url(report_file_name)
            except Exception as exc:
                report_error = str(exc)
                logger.error("SPX GEX report snapshot failed for %s: %s", target_date, exc, exc_info=True)

            notification_error = None
            sent = False
            if send_notification:
                try:
                    if not report_url:
                        raise RuntimeError("immutable report snapshot was not created; notification not sent")
                    sent = self._send_signal(
                        signal_id,
                        evaluation,
                        plan=plan,
                        reference_price=reference_price,
                        nq_snapshot=live_nq,
                        report_url=report_url,
                        notification_key_suffix=f"report-{report_id}" if force_notification else None,
                    )
                except Exception as exc:
                    notification_error = str(exc)
                    logger.error("SPX GEX signal notification failed: %s", exc)
            result = {
                "as_of_date": as_of_date.isoformat(),
                "observation_date": target_date.isoformat(),
                "signal": target.signal_raw,
                "classification": evaluation.classification.value,
                "actionable_at": evaluation.actionable_at.isoformat() if evaluation.actionable_at else None,
                "portfolio_state": self.portfolio.snapshot.state.value,
                "trade_allowed": evaluation.trade_allowed,
                "skip_reason": evaluation.skip_reason,
                "instrument": "QQQ" if evaluation.trade_allowed else None,
                "side": plan.direction.value if plan else None,
                "tp_pct": plan.tp_pct if plan else None,
                "sl_pct": plan.sl_pct if plan else None,
                "strategy_version": self.strategy_version,
                "notification_sent": sent,
                "notification_error": notification_error,
                "duration_ms": int((datetime.now() - started).total_seconds() * 1000),
                "report_id": report_id,
                "report_file_name": report_file_name,
                "report_url": report_url,
            }
            if report_id is None:
                result["report_error"] = report_error
            self.store.event("DAILY_SIGNAL", result)
            return result
        except Exception as exc:
            logger.error("SPX GEX daily signal failed for %s: %s", target_date, exc, exc_info=True)
            self.store.event("DATA_ERROR", {"observation_date": target_date.isoformat(), "error": str(exc)})
            notification_sent = False
            notification_error = None
            if not send_notification:
                return {
                    "observation_date": target_date.isoformat(),
                    "classification": SignalClassification.INSUFFICIENT_HISTORY.value,
                    "trade_allowed": False,
                    "skip_reason": str(exc),
                    "notification_sent": False,
                    "notification_error": None,
                }
            try:
                key = f"data-error|{target_date.isoformat()}|{self.strategy_version}"
                notification_sent = self.notifications.send_idempotent(
                    key,
                    "DATA_ERROR",
                    "⚠️ SIGNAL DATA INCOMPLETE",
                    f"Observation Date: {target_date}\nNO TRADE\nReason: {exc}\nStrategy Version: {self.strategy_version}",
                    priority="high",
                    url=self._latest_report_url(),
                    url_title="Open SPX GEX HTML report",
                )
            except Exception as notify_exc:
                notification_error = str(notify_exc)
                logger.error("SPX GEX data-error notification failed: %s", notify_exc)
            return {
                "observation_date": target_date.isoformat(),
                "classification": SignalClassification.INSUFFICIENT_HISTORY.value,
                "trade_allowed": False,
                "skip_reason": str(exc),
                "notification_sent": notification_sent,
                "notification_error": notification_error,
            }

    def run_position_monitor(self, now: datetime | None = None) -> dict[str, Any]:
        """Process persisted plans/positions at the available 30-minute resolution."""
        now = now or datetime.now(self.calendar.timezone)
        snapshot = self.portfolio.snapshot
        if not snapshot.active_trade_id and snapshot.state.value != "PENDING_GREEN_DIP":
            self._activate_due_plan(now)
            snapshot = self.portfolio.snapshot

        # A production monitor can use the IB quote for a current bar, while
        # historical/offline runs use the persisted NQMain 30M source.
        bars = self._monitor_bars(now)
        live = None
        if bool(getattr(self.settings, "spx_gex_require_live_nq", True)):
            try:
                live = get_live_nq_snapshot()
            except Exception:
                live = None
        if live:
            from .models import MarketBar

            current = float(live["price"])
            bars.append(MarketBar(now, current, current, current, current, "NQMAIN"))
            bars.sort(key=lambda item: item.timestamp)

        snapshot = self.portfolio.snapshot
        if snapshot.state.value == "PENDING_GREEN_DIP" and snapshot.pending_dip_plan_id:
            return self._monitor_pending_dip(snapshot.pending_dip_plan_id, bars, now)
        if snapshot.active_trade_id and snapshot.position:
            return self._monitor_active(snapshot, bars, now)
        return {"status": "IDLE", "portfolio_state": self.portfolio.snapshot.state.value}

    def _monitor_bars(self, now: datetime) -> list:
        start = self.calendar.previous_session(now.date(), include_current=True)
        start = self.calendar.session_offset(start, -8)
        if str(getattr(self.settings, "spx_gex_data_mode", "sql")).lower() == "file":
            repository = FileMarketDataRepository(
                self._resolve_path(getattr(self.settings, "spx_gex_gex_path")),
                self._resolve_path(getattr(self.settings, "spx_gex_nq_path")),
                self.calendar.timezone_name,
            )
            return repository.nq_bars()
        return SqlServerMarketDataRepository(
            getattr(self.settings, "spx_gex_source_database", "StockDB_US"), "NQMAIN.US"
        ).nq_bars(start, now.date(), self.calendar.timezone_name)

    def _activate_due_plan(self, now: datetime) -> None:
        plans = self.store.open_plans()
        for plan in plans:
            first_action = datetime.fromisoformat(plan["first_action_at"])
            if first_action.tzinfo is None:
                first_action = first_action.replace(tzinfo=self.calendar.timezone)
            if first_action > now:
                continue
            if plan["classification"] == SignalClassification.REVERSAL_GREEN.value:
                # Establish the reference from the exact D1 03:30 bar. A
                # later bar would introduce look-ahead and change the -1%
                # limit level.
                bars = self._monitor_bars(now)
                reference_bar = next((bar for bar in bars if bar.timestamp == first_action), None)
                if reference_bar:
                    self.portfolio.set_pending_dip(plan["plan_id"], float(reference_bar.open))
                continue
            # A market entry must use the exact actionable 03:30 bar.
            bars = self._monitor_bars(now)
            entry_bar = next((bar for bar in bars if bar.timestamp == first_action), None)
            if entry_bar:
                self.portfolio.open_trade(plan["plan_id"], entry_bar.open, entry_bar.timestamp)
                return

    def _monitor_pending_dip(self, plan_id: str, bars: list, now: datetime) -> dict[str, Any]:
        plan = self.store.plan(plan_id)
        if plan is None:
            return {"status": "DATA_ERROR", "reason": "MISSING_PENDING_PLAN"}
        metadata = json.loads(plan["metadata_json"] or "{}")
        reference_time = datetime.fromisoformat(plan["first_action_at"])
        if reference_time.tzinfo is None:
            reference_time = reference_time.replace(tzinfo=self.calendar.timezone)
        expiry = datetime.fromisoformat(str(metadata["dip_expire_at"]))
        fallback = datetime.fromisoformat(str(metadata["fallback_at"]))
        dip_price = float(plan["dip_price"])
        for bar in bars:
            if reference_time <= bar.timestamp < expiry and bar.timestamp <= now:
                if bar.open <= dip_price:
                    result = self.portfolio.activate_reversal_dip(plan_id, bar.open, bar.timestamp)
                    self._send_plan_event(
                        plan_id,
                        "DIP_ORDER_UPDATE",
                        "✅ REVERSAL GREEN DIP FILLED",
                        f"Dip order filled at ${bar.open:,.2f}\nExit: D5 cash close\nShadow NAV: ${self.portfolio.snapshot.shadow_nav:,.2f}",
                    )
                    return {"status": "DIP_FILLED", **result}
                if bar.low <= dip_price:
                    result = self.portfolio.activate_reversal_dip(plan_id, dip_price, bar.timestamp)
                    self._send_plan_event(
                        plan_id,
                        "DIP_ORDER_UPDATE",
                        "✅ REVERSAL GREEN DIP FILLED",
                        f"Dip order filled at ${dip_price:,.2f}\nExit: D5 cash close\nShadow NAV: ${self.portfolio.snapshot.shadow_nav:,.2f}",
                    )
                    return {"status": "DIP_FILLED", **result}
        if now >= fallback:
            bar = next((item for item in bars if item.timestamp == fallback), None)
            if bar:
                result = self.portfolio.open_trade(plan_id, bar.open, bar.timestamp, entry_type="D3_FALLBACK")
                self._send_plan_event(
                    plan_id,
                    "D3_FALLBACK",
                    "🟢 REVERSAL GREEN — D3 FALLBACK BUY",
                    f"Dip order was not filled.\nBUY QQQ at D3 03:30 proxy price ${bar.open:,.2f}\nExit: D5 cash close\nShadow NAV: ${self.portfolio.snapshot.shadow_nav:,.2f}",
                )
                return {"status": "D3_FALLBACK", "trade_id": result}
        return {"status": "PENDING_GREEN_DIP", "dip_price": dip_price}

    def _send_plan_event(self, plan_id: str, notification_type: str, title: str, message: str) -> None:
        try:
            report_url = self._latest_report_url()
            self.notifications.send_idempotent(
                f"plan|{plan_id}|{notification_type}",
                notification_type,
                title,
                message + f"\nHTML Report: {report_url}\nStrategy Version: {self.strategy_version}",
                url=report_url,
                url_title="Open SPX GEX HTML report",
            )
        except Exception as exc:
            logger.error("SPX GEX plan notification failed: %s", exc)

    def _monitor_active(self, snapshot, bars: list, now: datetime) -> dict[str, Any]:
        position = snapshot.position
        entry_time = datetime.fromisoformat(position["entry_timestamp"])
        if entry_time.tzinfo is None:
            entry_time = entry_time.replace(tzinfo=self.calendar.timezone)
        planned_exit = position.get("planned_exit_at")
        exit_time = None
        if planned_exit:
            exit_time = datetime.fromisoformat(planned_exit)
            if exit_time.tzinfo is None:
                exit_time = exit_time.replace(tzinfo=self.calendar.timezone)
        relevant = [
            bar
            for bar in bars
            if bar.timestamp >= entry_time
            and bar.timestamp <= now
            and (exit_time is None or bar.timestamp < exit_time)
        ]
        from .models import Direction

        result = first_touch(
            entry=float(position["entry_price"]),
            side=Direction(position["direction"]),
            tp=float(position["tp_price"]) if position.get("tp_price") else None,
            sl=float(position["sl_price"]) if position.get("sl_price") else None,
            bars=relevant,
        )
        if result.exit_price is None and exit_time:
            if now >= exit_time:
                eligible = [bar for bar in relevant if bar.timestamp < exit_time]
                if eligible:
                    last = eligible[-1]
                    result.exit_price, result.exit_time, result.exit_reason = last.close, last.timestamp, "TIME_EXIT"
        if result.exit_price is None:
            return {"status": "OPEN", "trade_id": snapshot.active_trade_id}
        result_dict = self.portfolio.close_trade(
            result.exit_price,
            result.exit_time or now,
            result.exit_reason or "TIME_EXIT",
            result.mfe_pct,
            result.mae_pct,
            result.bars_held,
            result.ambiguous,
        )
        trade = self.store.trade(result_dict["trade_id"])
        signal_type = trade["signal_type"] if trade else "SHADOW TRADE"
        try:
            notification_type, title, message = exit_notification(result_dict, signal_type, self.strategy_version)
            report_url = self._latest_report_url()
            self.notifications.send_idempotent(
                f"exit|{result_dict['trade_id']}|{result_dict['exit_reason']}",
                notification_type,
                title,
                message,
                url=report_url,
                url_title="Open SPX GEX HTML report",
            )
        except Exception as exc:
            logger.error("SPX GEX exit notification failed: %s", exc)
        return {"status": "CLOSED", **result_dict}
