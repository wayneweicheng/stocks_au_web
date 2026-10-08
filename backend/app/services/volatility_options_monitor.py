from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Any, Mapping

from app.services.option_orders_service import get_option_chain, _today_us_market_date
from app.services.volatility_options_alerts import VolatilityOptionsAlertService
from app.services.volatility_options_persistence import VolatilityOptionsStore

logger = logging.getLogger("app.volatility_options.monitor")


def _number(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def _expiry_ib(value: Any) -> str:
    text = str(value or "")
    return text.replace("-", "")[:8]


def _find_quote(chain: Mapping[str, Any], option_symbol: str | None, strike: float, right: str = "P") -> Mapping[str, Any] | None:
    for row in chain.get("rows") or []:
        if not isinstance(row, Mapping) or str(row.get("right") or "").upper() != right:
            continue
        if option_symbol and str(row.get("option_symbol") or row.get("local_symbol") or "").upper() == option_symbol.upper():
            return row
        row_strike = _number(row.get("strike"))
        if row_strike is not None and abs(row_strike - strike) < 0.0001:
            return row
    return None


def _correlations(store: VolatilityOptionsStore, symbols: list[str]) -> list[dict[str, Any]]:
    if len(symbols) < 2:
        return []
    try:
        price_series: dict[str, list[float]] = {}
        for symbol in symbols:
            rows = store.model.execute_read_query(
                """
                SELECT TOP 61 [Close]
                FROM StockDB_US.StockData.v_PriceHistory WITH (NOLOCK)
                WHERE ASXCode = ? ORDER BY ObservationDate DESC
                """,
                (f"{symbol}.US",),
            ) or []
            closes = [float(row["Close"]) for row in reversed(rows) if _number(row.get("Close")) and float(row["Close"]) > 0]
            price_series[symbol] = [closes[index] / closes[index - 1] - 1 for index in range(1, len(closes))]
        pairs: list[dict[str, Any]] = []
        symbols = list(price_series)
        for left_index, left in enumerate(symbols):
            for right in symbols[left_index + 1:]:
                count = min(len(price_series[left]), len(price_series[right]))
                if count < 10:
                    continue
                x = price_series[left][-count:]
                y = price_series[right][-count:]
                x_mean, y_mean = sum(x) / count, sum(y) / count
                numerator = sum((a - x_mean) * (b - y_mean) for a, b in zip(x, y))
                denominator = (sum((a - x_mean) ** 2 for a in x) * sum((b - y_mean) ** 2 for b in y)) ** 0.5
                correlation = numerator / denominator if denominator else 0.0
                if correlation >= 0.70:
                    pairs.append({"left": left, "right": right, "correlation": correlation})
        return pairs
    except Exception:
        return []


def portfolio_risk_snapshot(
    *,
    store: VolatilityOptionsStore | None = None,
    schedule: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    store = store or VolatilityOptionsStore()
    schedule = schedule or store.get_schedule() or {}
    positions = store.list_manual_positions("OPEN")
    assignment_exposure = 0.0
    stress_loss = 0.0
    portfolio_delta = 0.0
    portfolio_gamma = 0.0
    portfolio_theta = 0.0
    portfolio_vega = 0.0
    symbol_exposure: dict[str, float] = {}
    strategy_counts: dict[str, int] = {}
    for position in positions:
        quantity = int(position.get("Quantity") or 0)
        short_strike = float(position.get("ShortStrike") or 0)
        entry_credit = float(position.get("EntryCredit") or 0)
        multiplier = 100.0
        symbol = str(position.get("Symbol") or "UNKNOWN")
        strategy = str(position.get("Strategy") or "unknown")
        strategy_counts[strategy] = strategy_counts.get(strategy, 0) + quantity
        if strategy == "short_put":
            assignment = short_strike * multiplier * quantity
            risk = max(short_strike - entry_credit, 0.0) * multiplier * quantity
        else:
            long_strike = float(position.get("LongStrike") or 0)
            assignment = 0.0
            risk = max(short_strike - long_strike - entry_credit, 0.0) * multiplier * quantity
        assignment_exposure += assignment
        stress_loss += risk
        portfolio_delta += float(position.get("CurrentDelta") or 0) * quantity * multiplier
        portfolio_gamma += float(position.get("CurrentGamma") or 0) * quantity * multiplier
        portfolio_theta += float(position.get("CurrentTheta") or 0) * quantity * multiplier
        portfolio_vega += float(position.get("CurrentVega") or 0) * quantity * multiplier
        symbol_exposure[symbol] = symbol_exposure.get(symbol, 0.0) + max(assignment, risk)
    account_equity = float(schedule.get("AccountEquity") or 0)
    max_assignment_pct = float(schedule.get("MaxAssignmentExposurePct") or 0.75)
    risk_budget_pct = float(schedule.get("RiskBudgetPct") or 0.02)
    correlation_pairs = _correlations(store, list(symbol_exposure))
    breaches: list[str] = []
    if account_equity > 0 and assignment_exposure > account_equity * max_assignment_pct:
        breaches.append("assignment exposure limit exceeded")
    if account_equity > 0 and stress_loss > account_equity * max(0.10, risk_budget_pct * 5):
        breaches.append("aggregate manual-position stress budget exceeded")
    for pair in correlation_pairs:
        combined = symbol_exposure.get(pair["left"], 0.0) + symbol_exposure.get(pair["right"], 0.0)
        if account_equity > 0 and combined > account_equity * max_assignment_pct:
            breaches.append(f"correlated exposure limit exceeded for {pair['left']}/{pair['right']}")
    return {
        "as_of": datetime.utcnow().isoformat() + "Z",
        "open_positions": len(positions),
        "assignment_exposure": assignment_exposure,
        "aggregate_stress_loss": stress_loss,
        "portfolio_delta": portfolio_delta,
        "portfolio_gamma": portfolio_gamma,
        "portfolio_theta": portfolio_theta,
        "portfolio_vega": portfolio_vega,
        "account_equity": account_equity,
        "max_assignment_exposure_pct": max_assignment_pct,
        "risk_budget_pct": risk_budget_pct,
        "symbol_exposure": symbol_exposure,
        "correlation_pairs": correlation_pairs,
        "strategy_counts": strategy_counts,
        "breaches": breaches,
        "safe_for_new_research_candidates": not breaches,
    }


def monitor_open_positions(
    *,
    store: VolatilityOptionsStore | None = None,
    alerts: VolatilityOptionsAlertService | None = None,
    positions: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    store = store or VolatilityOptionsStore()
    alerts = alerts or VolatilityOptionsAlertService(model=store.model)
    positions = positions if positions is not None else store.list_manual_positions("OPEN")
    risk = portfolio_risk_snapshot(store=store)
    monitored: list[dict[str, Any]] = []
    if risk["breaches"]:
        alerts.send_once(
            idempotency_key=f"portfolio:risk:{datetime.utcnow():%Y-%m-%d-%H%M}",
            alert_type="VSO_PORTFOLIO_RISK",
            title="VSO manual portfolio risk breach",
            message="\n".join(["Portfolio risk requires manual review:", *risk["breaches"]]),
            severity="high",
        )
    failed: list[dict[str, Any]] = []
    today = _today_us_market_date()
    for position in positions:
        position_id = int(position["PositionId"])
        symbol = str(position.get("Symbol") or "").strip().upper()
        try:
            chain = get_option_chain(
                symbol=symbol,
                right="P",
                max_expiries=1,
                strike_window_pct=0.50,
                expiry=_expiry_ib(position.get("Expiration")),
            )
            underlying = chain.get("underlying") or {}
            spot = _number(underlying.get("reference_price"))
            short_row = _find_quote(chain, position.get("ShortOption"), float(position["ShortStrike"]))
            long_row = None
            if position.get("LongOption") and position.get("LongStrike") is not None:
                long_row = _find_quote(chain, position.get("LongOption"), float(position["LongStrike"]))
            if spot is None or short_row is None:
                raise RuntimeError("current underlying or short-leg quote unavailable")
            short_quote = short_row.get("quote") if isinstance(short_row.get("quote"), Mapping) else {}
            long_quote = long_row.get("quote") if isinstance(long_row, Mapping) and isinstance(long_row.get("quote"), Mapping) else {}
            short_ask = _number(short_quote.get("ask"))
            short_iv = _number(short_quote.get("iv"))
            short_delta = _number(short_quote.get("delta"))
            if short_ask is None:
                raise RuntimeError("current short-leg ask unavailable")
            long_bid = _number(long_quote.get("bid")) if long_row else 0.0
            current_value = short_ask - (long_bid or 0.0)
            entry_credit = float(position["EntryCredit"])
            multiplier = 100.0
            quantity = int(position["Quantity"])
            pnl = (entry_credit - current_value) * multiplier * quantity
            short_gamma = _number(short_quote.get("gamma")) or 0.0
            short_theta = _number(short_quote.get("theta")) or 0.0
            short_vega = _number(short_quote.get("vega")) or 0.0
            long_delta = _number(long_quote.get("delta")) or 0.0
            long_gamma = _number(long_quote.get("gamma")) or 0.0
            long_theta = _number(long_quote.get("theta")) or 0.0
            long_vega = _number(long_quote.get("vega")) or 0.0
            net_delta = -(_number(short_quote.get("delta")) or 0.0) + long_delta
            net_gamma = -short_gamma + long_gamma
            net_theta = -short_theta + long_theta
            net_vega = -short_vega + long_vega
            dte = (date.fromisoformat(str(position["Expiration"])[:10]) - today).days
            target_pnl = entry_credit * multiplier * quantity * float(position.get("ProfitCaptureTarget") or 0.60)
            recommendation = "HOLD"
            if pnl >= target_pnl:
                recommendation = "PROFIT_TARGET"
            elif dte <= int(position.get("TimeExitDTE") or 14):
                recommendation = "TIME_EXIT"
            elif short_delta is not None and abs(short_delta) >= float(position.get("RiskDeltaExit") or 0.45):
                recommendation = "RISK_EXIT"
            store.update_manual_position(
                position_id,
                {
                    "current_spot": spot,
                    "current_iv": short_iv,
                    "current_value": current_value,
                    "current_delta": net_delta,
                    "current_gamma": net_gamma,
                    "current_theta": net_theta,
                    "current_vega": net_vega,
                    "unrealized_pnl": pnl,
                    "exit_recommendation": recommendation,
                },
            )
            result = {
                "position_id": position_id,
                "symbol": symbol,
                "spot": spot,
                "dte": dte,
                "current_value": current_value,
                "unrealized_pnl": pnl,
                "short_delta": short_delta,
                "current_iv": short_iv,
                "recommendation": recommendation,
                "manual_action_required": recommendation != "HOLD",
            }
            monitored.append(result)
            if recommendation != "HOLD":
                alerts.send_once(
                    idempotency_key=f"position:{position_id}:{recommendation}:{today.isoformat()}",
                    alert_type=f"VSO_{recommendation}",
                    title=f"VSO manual exit review: {symbol}",
                    message=(
                        f"{symbol} position {position_id}: {recommendation}\n"
                        f"P/L ${pnl:,.2f}; DTE {dte}; spot ${spot:,.2f}; "
                        f"short delta {short_delta if short_delta is not None else 'n/a'}\n"
                        "Review and close manually if appropriate. No broker order was submitted."
                    ),
                    severity="high" if recommendation == "RISK_EXIT" else "normal",
                    position_id=position_id,
                )
        except Exception as exc:
            failed.append({"position_id": position_id, "symbol": symbol, "error": str(exc)})
            alerts.send_once(
                idempotency_key=f"position:{position_id}:monitor_failure:{datetime.utcnow():%Y-%m-%d-%H%M}",
                alert_type="VSO_MONITOR_FAILURE",
                title=f"VSO monitor failure: {symbol}",
                message=f"Position {position_id} could not be monitored: {exc}. Manual review required.",
                severity="high",
                position_id=position_id,
            )
    return {"monitored": monitored, "failed": failed, "count": len(monitored), "failed_count": len(failed), "portfolio_risk": risk}
