from __future__ import annotations

import logging
from datetime import datetime

from .service import SPXGEXStrategyService

logger = logging.getLogger("app.spx_gex_strategy.jobs")


def spx_gex_data_check_job() -> None:
    service = SPXGEXStrategyService()
    target = service.calendar.latest_completed_session()
    try:
        observations, _ = service._source_data(target)
        dates = {row.observation_date for row in observations}
        if target not in dates:
            raise RuntimeError(f"latest completed session {target} is not present in source data")
        logger.info("[SPX GEX] source data current through %s", target)
    except Exception as exc:
        logger.error("[SPX GEX] source data check failed: %s", exc)


def spx_gex_daily_signal_job() -> None:
    result = SPXGEXStrategyService().run_daily_signal()
    logger.info(
        "[SPX GEX] daily result observation=%s classification=%s allowed=%s notification=%s",
        result.get("observation_date"),
        result.get("classification"),
        result.get("trade_allowed"),
        result.get("notification_sent"),
    )
    if result.get("shadow"):
        logger.info(
            "[SPX GEX] shadow result version=%s classification=%s allowed=%s outcome=%s",
            result["shadow"].get("shadow_strategy_version"),
            result["shadow"].get("shadow_classification"),
            result["shadow"].get("shadow_trade_allowed"),
            result["shadow"].get("shadow_outcome_status"),
        )


def spx_gex_position_monitor_job() -> None:
    result = SPXGEXStrategyService().run_position_monitor()
    if result.get("status") not in {"IDLE", "OPEN", "PENDING_GREEN_DIP"}:
        logger.info("[SPX GEX] position monitor result=%s", result)


def spx_gex_monthly_report_job() -> None:
    service = SPXGEXStrategyService()
    now = datetime.now(service.calendar.timezone)
    current = now.date()
    if service.calendar.next_session(current, include_current=True) != current:
        return
    next_session = service.calendar.next_session(current)
    if next_session.month == current.month:
        return

    trades = service.store.list_trades(service.environment_type.value)
    month_trades = [
        trade for trade in trades
        if trade["exit_timestamp"] and str(trade["exit_timestamp"])[:7] == current.strftime("%Y-%m")
    ]
    comparisons = service.store.recent_strategy_comparisons(
        200,
        service.environment_type.value,
        service.shadow_strategy_version,
    )
    shadow_yellow = [
        row for row in comparisons
        if row["shadow_trade_allowed"] and str(row["observation_date"])[:7] == current.strftime("%Y-%m")
    ]
    shadow_strong = sum(row["shadow_classification"] == "STRONG_YELLOW" for row in shadow_yellow)
    shadow_reliable = sum(row["shadow_classification"] == "RELIABLE_YELLOW" for row in shadow_yellow)
    shadow_closed = sum(row["shadow_outcome_status"] == "CLOSED" for row in shadow_yellow)
    wins = sum(float(trade["return_pct"] or 0) > 0 for trade in month_trades)
    losses = len(month_trades) - wins
    message = "\n".join(
        [
            "Month: " + current.strftime("%Y-%m"),
            f"Trades: {len(month_trades)}",
            f"Wins: {wins}",
            f"Losses: {losses}",
            f"Current NAV: ${service.portfolio.snapshot.shadow_nav:,.2f}",
            f"Forward trades accumulated / 50: {len(trades)} / 50",
            f"Strategy Version: {service.strategy_version}",
            f"{service.shadow_strategy_version} Yellow candidates: {len(shadow_yellow)} (Strong {shadow_strong} / Reliable {shadow_reliable})",
            f"{service.shadow_strategy_version} outcomes closed: {shadow_closed}",
        ]
    )
    try:
        service.notifications.send_idempotent(
            f"monthly-report|{current.strftime('%Y-%m')}|{service.strategy_version}",
            "SHADOW_SUMMARY",
            "📊 MONTHLY SIGNAL REPORT",
            message,
            url=service._report_url(),
            url_title="Open SPX GEX HTML report",
        )
    except Exception as exc:
        logger.error("[SPX GEX] monthly report notification failed: %s", exc)

    for milestone in (10, 20, 30, 50):
        if len(trades) >= milestone:
            try:
                service.notifications.send_idempotent(
                    f"milestone|{milestone}|{service.strategy_version}",
                    "SHADOW_SUMMARY",
                    f"📈 FORWARD TEST MILESTONE — {milestone} TRADES",
                    f"Forward paper trades accumulated: {len(trades)}\nReview strategy evidence at the {milestone}-trade milestone.\nStrategy Version: {service.strategy_version}",
                    url=service._report_url(),
                    url_title="Open SPX GEX HTML report",
                )
            except Exception as exc:
                logger.error("[SPX GEX] milestone notification failed: %s", exc)
