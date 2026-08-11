from __future__ import annotations

import json
import logging
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .models import PortfolioSnapshot, SignalClassification, SignalEvaluation, TradePlan
from .storage import StrategyStore

logger = logging.getLogger("app.spx_gex_strategy.notifications")


class PushoverClient:
    endpoint = "https://api.pushover.net/1/messages.json"

    def __init__(
        self,
        user_key: str | None,
        api_token: str | None,
        device: str | None = None,
        sound: str | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.user_key = (user_key or "").strip()
        self.api_token = (api_token or "").strip()
        self.device = (device or "").strip()
        self.sound = (sound or "").strip()
        self.timeout = timeout

    @property
    def configured(self) -> bool:
        return bool(self.user_key and self.api_token)

    def send(
        self,
        title: str,
        message: str,
        priority: str = "normal",
        url: str | None = None,
        url_title: str | None = None,
    ) -> str | None:
        if not self.configured:
            raise RuntimeError("Pushover is not configured; set PUSHOVER_USER_KEY and PUSHOVER_APP_TOKEN")
        fields = {
            "token": self.api_token,
            "user": self.user_key,
            "title": title,
            "message": message,
            "priority": {"normal": 0, "high": 1}.get(priority, 0),
        }
        if self.device:
            fields["device"] = self.device
        if self.sound:
            fields["sound"] = self.sound
        if url:
            fields["url"] = url
            fields["url_title"] = url_title or "Open HTML report"
        payload = urlencode(fields).encode("utf-8")
        request = Request(self.endpoint, data=payload, method="POST")
        with urlopen(request, timeout=self.timeout) as response:  # nosec B310 - fixed HTTPS endpoint.
            body = json.loads(response.read().decode("utf-8"))
        if body.get("status") != 1:
            raise RuntimeError(f"Pushover rejected notification: {body.get('errors') or body}")
        return str(body.get("request") or "") or None


class NotificationService:
    def __init__(self, store: StrategyStore, client: PushoverClient) -> None:
        self.store = store
        self.client = client

    def send_idempotent(
        self,
        key: str,
        notification_type: str,
        title: str,
        message: str,
        priority: str = "high",
        url: str | None = None,
        url_title: str | None = None,
    ) -> bool:
        if not self.store.claim_notification(key, notification_type, title, message):
            return False
        try:
            provider_id = self.client.send(title, message, priority=priority, url=url, url_title=url_title)
            self.store.finish_notification(key, sent=True, provider_id=provider_id)
            return True
        except Exception as exc:
            self.store.finish_notification(key, sent=False, error=str(exc))
            raise


def _money(value: float | None) -> str:
    return "n/a" if value is None else f"${value:,.2f}"


def _pct(value: float | None, signed: bool = False) -> str:
    if value is None:
        return "n/a"
    return f"{value:+.2%}" if signed else f"{value:.2%}"


def _number(value: float | None) -> str:
    return "n/a" if value is None else f"{value:,.2f}"


def signal_notification(
    evaluation: SignalEvaluation,
    snapshot: PortfolioSnapshot,
    strategy_version: str,
    plan: TradePlan | None = None,
    reference_price: float | None = None,
    nq_snapshot: dict[str, Any] | None = None,
    qqq_snapshot: dict[str, Any] | None = None,
    report_url: str | None = None,
    shadow_evaluation: SignalEvaluation | None = None,
    shadow_strategy_version: str | None = None,
) -> tuple[str, str, str]:
    """Return notification type, title and structured message."""
    classification = evaluation.classification
    shadow_line = (
        f"Shadow {shadow_strategy_version or 'variant'} {shadow_evaluation.observation.derived.get('SP_lookback_days', 120)}D/P"
        f"{int(float(shadow_evaluation.observation.derived.get('SP_threshold_quantile', 0.60)) * 100)}: "
        f"{shadow_evaluation.classification.value} "
        f"({'TRADEABLE' if shadow_evaluation.trade_allowed else 'FILTERED'})"
        if shadow_evaluation is not None
        else None
    )
    shadow_lines = [shadow_line] if shadow_line else []
    if not evaluation.trade_allowed or plan is None:
        notification_type = "TRADE_SKIPPED"
        title = "⚪ SIGNAL SKIPPED"
        message = "\n".join(
            [
                f"Signal: {classification.value}",
                f"Observation Date: {evaluation.observation.observation_date}",
                f"Action Date: {evaluation.action_date or 'n/a'}",
                f"Portfolio State: {snapshot.state.value}",
                "Trade Allowed: NO",
                f"Skip Reason: {evaluation.skip_reason or 'not tradable'}",
                *shadow_lines,
                f"Shadow NAV: {_money(snapshot.shadow_nav)}",
                f"HTML Report: {report_url or 'n/a'}",
                f"Strategy Version: {strategy_version}",
            ]
        )
        return notification_type, title, message

    nq_lines: list[str] = []
    if nq_snapshot:
        nq_lines = [
            f"Live NQMAIN: {_money(nq_snapshot.get('price'))}",
            f"NQ Prior Close: {_money(nq_snapshot.get('previous_close'))}",
            f"NQ Move: {_pct(nq_snapshot.get('move_fraction'), signed=True)}",
            f"NQ Source: {nq_snapshot.get('source', 'n/a')}",
        ]
    reference = reference_price or plan.reference_price
    qqq_price = float(qqq_snapshot.get("price")) if qqq_snapshot and qqq_snapshot.get("price") else None
    qqq_quantity = int(snapshot.shadow_nav * snapshot.exposure_factor / qqq_price) if qqq_price else None
    sc_lookback = int(evaluation.observation.derived.get("SC_lookback_days", 60))
    sp_lookback = int(evaluation.observation.derived.get("SP_lookback_days", 60))
    sp_quantile = float(evaluation.observation.derived.get("SP_threshold_quantile", 0.75))
    common = [
        f"Signal: {classification.value}",
        "Production Variant: A",
        f"Observation Date: {evaluation.observation.observation_date}",
        f"Action Date: {plan.action_date}",
        f"Action Time: {plan.first_action_at.strftime('%H:%M %Z')}",
        "Instrument: QQQ",
        f"Side: {plan.direction.value}",
        f"Reference Price (NQ proxy): {_money(reference)}",
        f"Live QQQ Price: {_money(qqq_price)}",
        f"QQQ Source: {qqq_snapshot.get('source', 'n/a') if qqq_snapshot else 'n/a'}",
        *nq_lines,
        f"Portfolio State: {snapshot.state.value}",
        "Trade Allowed: YES",
        *shadow_lines,
        f"Shadow NAV: {_money(snapshot.shadow_nav)}",
        f"HTML Report: {report_url or 'n/a'}",
        f"Exposure: {snapshot.exposure_factor:.0%}",
        f"Suggested Quantity (actual QQQ quote): {qqq_quantity if qqq_quantity is not None else 'at action price'} QQQ shares",
        f"SP Delta Share: {_pct(evaluation.observation.sp_delta_share)}",
        f"SC GEX Level: {_number(evaluation.observation.sc_gex)}",
        f"SC GEXDelta: {_number(evaluation.observation.sc_gex_delta)}",
        f"SC GEX {sc_lookback}D Median: {_number(evaluation.sc_rolling_median_60)}",
        f"SC {sc_lookback}D Percentile: {_pct((evaluation.sc_percentile_60 or 0) / 100.0)}" if evaluation.sc_percentile_60 is not None else f"SC {sc_lookback}D Percentile: n/a",
        f"SP Share {sp_lookback}D P{int(sp_quantile * 100)}: {_pct(evaluation.sp_share_p75_60)}",
        f"Prior 5D NQ Return: {_pct(evaluation.prior_5d_nq_return, signed=True)}",
        f"Strategy Version: {strategy_version}",
    ]
    if classification == SignalClassification.STRONG_YELLOW:
        title = "🔴 STRONG YELLOW — SHORT QQQ"
        notification_type = "SIGNAL_READY"
        common[6:6] = ["Entry Rule: SHORT at D1 03:30 New York"]
        common.extend([
            "TP: -0.80%", "SL: +1.00%",
            f"QQQ TP: {_money(qqq_price * 0.992) if qqq_price else 'at live entry quote'}",
            f"QQQ SL: {_money(qqq_price * 1.01) if qqq_price else 'at live entry quote'}",
        ])
    elif classification == SignalClassification.RELIABLE_YELLOW:
        title = "🟡 RELIABLE YELLOW — SHORT QQQ"
        notification_type = "SIGNAL_READY"
        common[6:6] = ["Entry Rule: SHORT at D1 03:30 New York"]
        common.extend([
            "TP: -0.40%", "SL: +0.80%",
            f"QQQ TP: {_money(qqq_price * 0.996) if qqq_price else 'at live entry quote'}",
            f"QQQ SL: {_money(qqq_price * 1.008) if qqq_price else 'at live entry quote'}",
        ])
    elif classification == SignalClassification.REVERSAL_GREEN:
        title = "🟢 REVERSAL GREEN — BUY DIP"
        notification_type = "SIGNAL_READY"
        common[6:6] = [
            "Entry Rule: Buy dip at -1.00% from D1 03:30 reference",
            f"QQQ Dip Limit (actual QQQ quote): {_money(qqq_price * 0.99) if qqq_price else 'at D1 live quote'}",
            "Validity: D1 03:30 until D3 03:30 New York",
            "Fallback: BUY at D3 03:30 if unfilled",
            "Exit: D5 cash close",
        ]
    else:
        title = "🟢 NORMAL GREEN — D3 BUY"
        notification_type = "SIGNAL_READY"
        common[6:6] = [
            "Entry Rule: BUY at D3 03:30 New York",
            "TP: +2.50%",
            f"QQQ TP (from current quote, refreshed at D3): {_money(qqq_price * 1.025) if qqq_price else 'at D3 live quote'}",
            "Otherwise: D5 cash close",
        ]
    return notification_type, title, "\n".join(common)


def exit_notification(exit_result: dict[str, Any], signal_type: str, strategy_version: str) -> tuple[str, str, str]:
    reason = str(exit_result.get("exit_reason") or "TIME_EXIT")
    prefix = {"TP_HIT": "✅", "SL_HIT": "❌", "TIME_EXIT": "⏰"}.get(reason, "ℹ️")
    title = f"{prefix} {signal_type} {reason.replace('_', ' ')}"
    return (
        reason,
        title,
        "\n".join(
            [
                f"Trade ID: {exit_result.get('trade_id')}",
                f"Entry: {_money(exit_result.get('entry_price'))}",
                f"Exit: {_money(exit_result.get('exit_price'))}",
                f"Return: {_pct(exit_result.get('return_pct'), signed=True)}",
                f"Shadow P&L: {_money(exit_result.get('pnl_usd'))}",
                f"New Shadow NAV: {_money(exit_result.get('shadow_nav'))}",
                f"Strategy Version: {strategy_version}",
            ]
        ),
    )
