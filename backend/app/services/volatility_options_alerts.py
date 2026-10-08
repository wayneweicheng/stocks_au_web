from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any
from urllib.error import HTTPError, URLError

from app.core.config import settings
from app.core.db import get_sql_model
from app.spx_gex_strategy.notifications import PushoverClient

logger = logging.getLogger("app.volatility_options.alerts")


class VolatilityOptionsAlertService:
    """Idempotent notification adapter; it never places or changes broker orders."""

    def __init__(self, model: Any | None = None, client: PushoverClient | None = None) -> None:
        self.model = model or get_sql_model()
        self.client = client or PushoverClient(
            settings.pushover_user_key,
            settings.pushover_app_token,
            device=settings.pushover_device,
            sound=settings.pushover_sound,
        )

    def send_once(
        self,
        *,
        idempotency_key: str,
        alert_type: str,
        title: str,
        message: str,
        severity: str = "normal",
        run_id: str | None = None,
        position_id: int | None = None,
        report_url: str | None = None,
    ) -> dict[str, Any]:
        existing = self.model.execute_read_query(
            "SELECT TOP 1 AlertId, Status, ProviderId FROM [Analysis].[VolatilitySelectiveAlert] WHERE IdempotencyKey = ?",
            (idempotency_key,),
        ) or []
        if existing:
            return {"sent": existing[0].get("Status") == "SENT", "duplicate": True, **existing[0]}

        self.model.execute_update_usp(
            """
            INSERT INTO [Analysis].[VolatilitySelectiveAlert]
                (IdempotencyKey, RunId, PositionId, AlertType, Severity, Title, Message, Status)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING')
            """,
            (idempotency_key, run_id, position_id, alert_type, severity, title[:200], message),
        )
        if not self.client.configured:
            self._finish(idempotency_key, "SKIPPED", error="Pushover is not configured")
            logger.warning("Volatility options alert skipped because Pushover is not configured: %s", alert_type)
            return {"sent": False, "duplicate": False, "status": "SKIPPED", "error": "Pushover is not configured"}
        try:
            provider_id = self.client.send(
                title=title,
                message=message,
                priority="high" if severity.lower() in {"high", "critical"} else "normal",
                url=report_url,
                url_title="Open volatility options report",
            )
            self.model.execute_update_usp(
                """
                UPDATE [Analysis].[VolatilitySelectiveAlert]
                SET Status = 'SENT', ProviderId = ?, SentAt = getutcdate()
                WHERE IdempotencyKey = ?
                """,
                (provider_id, idempotency_key),
            )
            return {"sent": True, "duplicate": False, "status": "SENT", "provider_id": provider_id}
        except (HTTPError, URLError, OSError, RuntimeError) as exc:
            self._finish(idempotency_key, "FAILED", error=str(exc))
            logger.error("Volatility options alert failed: %s", exc)
            return {"sent": False, "duplicate": False, "status": "FAILED", "error": str(exc)}

    def list_alerts(self, limit: int = 100) -> list[dict[str, Any]]:
        bounded = max(1, min(int(limit), 500))
        return self.model.execute_read_query(
            f"""
            SELECT TOP {bounded} AlertId, IdempotencyKey, RunId, PositionId, AlertType,
                   Severity, Title, Message, Status, ProviderId, LastError,
                   CreatedAt, SentAt
            FROM [Analysis].[VolatilitySelectiveAlert] WITH (NOLOCK)
            ORDER BY CreatedAt DESC
            """,
            (),
        ) or []

    def _finish(self, key: str, status: str, error: str | None = None) -> None:
        self.model.execute_update_usp(
            "UPDATE [Analysis].[VolatilitySelectiveAlert] SET Status = ?, LastError = ? WHERE IdempotencyKey = ?",
            (status, error[:2000] if error else None, key),
        )


def candidate_alert_message(candidate: dict[str, Any]) -> str:
    return "\n".join(
        [
            f"{candidate.get('symbol')} {candidate.get('strategy')}",
            f"Expiry: {candidate.get('expiration')} ({candidate.get('dte')} DTE)",
            f"Credit: ${float(candidate.get('credit') or 0):.2f}",
            f"Score: {float(candidate.get('trade_score') or 0):.1f}",
            f"IV edge: {float(candidate.get('volatility_edge') or 0):+.2%}",
            f"Worst stress: ${float(candidate.get('worst_scenario_loss') or 0):,.0f}",
            "Manual review required; no order was submitted.",
        ]
    )
