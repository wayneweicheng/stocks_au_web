from __future__ import annotations

import json
from datetime import date, datetime
from html import escape
from typing import Any

from .calendar import USCashCalendar
from .storage import StrategyStore


# Frozen production benchmark. Historical returns are the NQ percentage-path
# proxy used by the strategy, not a claim of historical QQQ fills.
REVERSAL_GREEN_HISTORICAL_STATS = {
    "window": "2025-03-06 through 2026-08-06",
    "strategy_version": "v1.0.3-production",
    "candidate_count": 42,
    "hypothetical_wins": 33,
    "hypothetical_losses": 9,
    "hypothetical_win_rate": 0.7857142857142857,
    "hypothetical_average_return": 0.014594850729727663,
    "hypothetical_profit_factor": 4.135462260447396,
    "executed_count": 24,
    "executed_wins": 17,
    "executed_losses": 7,
    "executed_win_rate": 0.7083333333333334,
    "executed_average_return": 0.008988744291774362,
    "executed_profit_factor": 2.3303814804951735,
}

# These Yellow and Normal Green figures come from the frozen causal backtest
# ledger for the same production rules. Returns use the NQ percentage-path
# proxy; they are not a historical QQQ execution ledger.
SIGNAL_HISTORICAL_STATS = {
    "STRONG_YELLOW": {
        "label": "Strong Yellow",
        "candidate_count": 8,
        "skipped_count": 4,
        "executed_count": 4,
        "wins": 4,
        "losses": 0,
        "win_rate": 1.0,
        "average_return": 0.008,
        "profit_factor": None,
    },
    "RELIABLE_YELLOW": {
        "label": "Reliable Yellow",
        "candidate_count": 17,
        "skipped_count": 9,
        "candidate_wins": 15,
        "candidate_losses": 2,
        "candidate_win_rate": 15 / 17,
        "candidate_average_return": 0.002588235294117647,
        "candidate_profit_factor": 1.25,
        "executed_count": 8,
        "wins": 7,
        "losses": 1,
        "win_rate": 0.875,
        "average_return": 0.0025,
        "profit_factor": 3.625554653652297,
    },
    "NORMAL_GREEN": {
        "label": "Normal Green",
        "candidate_count": 26,
        "skipped_count": 4,
        "executed_count": 21,
        "wins": 15,
        "losses": 6,
        "win_rate": 15 / 21,
        "average_return": 0.0036701179020242427,
        "profit_factor": 1.7548203302311083,
    },
}


def _money(value: Any) -> str:
    try:
        return f"${float(value):,.2f}"
    except (TypeError, ValueError):
        return "N/A"


def _pct(value: Any) -> str:
    try:
        return f"{float(value):+.2%}"
    except (TypeError, ValueError):
        return "N/A"


def _pct3(value: Any) -> str:
    try:
        return f"{float(value):+.3%}"
    except (TypeError, ValueError):
        return "N/A"


def _unsigned_pct(value: Any) -> str:
    try:
        return f"{float(value):.2%}"
    except (TypeError, ValueError):
        return "N/A"


def _number(value: Any) -> str:
    try:
        return f"{float(value):,.2f}"
    except (TypeError, ValueError):
        return "N/A"


def _row_value(row: Any, key: str, default: Any = None) -> Any:
    try:
        return row[key]
    except (KeyError, IndexError, TypeError):
        return default


def _metrics(row: Any) -> dict[str, Any]:
    try:
        value = json.loads(_row_value(row, "metrics_json", "{}") or "{}")
        return value if isinstance(value, dict) else {}
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}


def _comparison_return(row: Any) -> str:
    try:
        outcome = json.loads(_row_value(row, "shadow_outcome_json", "") or "")
    except (TypeError, ValueError, json.JSONDecodeError):
        outcome = {}
    return _pct(outcome.get("return_pct")) if isinstance(outcome, dict) else "N/A"


def _reference_details(row: Any, qqq_reference: dict[str, Any] | None) -> dict[str, Any]:
    metrics = _metrics(row)
    source = qqq_reference or {}
    price = source.get("reference_price") or source.get("price") or metrics.get("QQQ_reference_price")
    timestamp = source.get("reference_timestamp") or metrics.get("QQQ_reference_timestamp")
    reference_source = source.get("reference_source") or metrics.get("QQQ_reference_source")
    rule = source.get("reference_rule") or metrics.get("QQQ_reference_rule")
    unavailable_reason = metrics.get("QQQ_reference_unavailable_reason")
    return {
        "price": price,
        "timestamp": timestamp,
        "source": reference_source,
        "rule": rule,
        "unavailable_reason": unavailable_reason,
    }


def _parse_date(value: Any) -> date | None:
    try:
        return date.fromisoformat(str(value)[:10])
    except (TypeError, ValueError):
        return None


def _plan_for_signal(store: StrategyStore, row: Any) -> Any | None:
    signal_id = _row_value(row, "signal_id")
    if not signal_id:
        return None
    plan_id = store.plan_id_for_signal(str(signal_id))
    return store.plan(plan_id) if plan_id else None


def _signal_meaning(row: Any) -> str:
    classification = str(_row_value(row, "classification", "") or "")
    metrics = _metrics(row)
    observation_date = escape(str(_row_value(row, "observation_date", "N/A")))
    if classification == "REVERSAL_GREEN":
        return (
            f"The {observation_date} raw signal was <b>BULLISH</b>, but NQ had fallen "
            f"{_pct(metrics.get('prior_5d_nq_return'))} over the previous five US cash sessions. "
            "The strategy therefore treats this as a possible bullish mean-reversion setup: "
            "look for a cheaper QQQ entry first, rather than buying immediately at the first signal."
        )
    if classification == "NORMAL_GREEN":
        return (
            f"The {observation_date} raw signal was <b>BULLISH</b> and the previous five-session "
            f"NQ return was {_pct(metrics.get('prior_5d_nq_return'))}. This is the ordinary bullish "
            "Green setup, scheduled for a D3 03:30 New York entry."
        )
    if classification.endswith("_YELLOW"):
        return (
            f"The {observation_date} raw signal was <b>BEARISH</b>. The Yellow classifier compares "
            "current SC GEX level and SP delta share with their causal historical thresholds to "
            "decide whether a short QQQ setup is permitted."
        )
    if classification == "NO_SIGNAL":
        return "No bullish or bearish raw signal was recorded, so there is no trade setup."
    return "The signal does not have enough valid history to produce a trade setup."


def _yellow_explanation(row: Any) -> str:
    metrics = _metrics(row)
    classification = str(_row_value(row, "classification", "YELLOW"))
    label = classification.replace("_", " ").title()
    observation_date = escape(str(_row_value(row, "observation_date", "N/A")))
    sc_current = metrics.get("SC_GEX_current")
    sc_delta = metrics.get("SC_GEXDelta_current", metrics.get("SC_GEXDelta"))
    sc_threshold = metrics.get("SC_GEX_threshold")
    sp_level = metrics.get("SP_GEX_current", metrics.get("SP_GEX"))
    sp_delta = metrics.get("SP_GEXDelta_current", metrics.get("SP_GEXDelta"))
    sp_current = metrics.get("SP_delta_share_current")
    sp_threshold = metrics.get("SP_delta_share_threshold")
    sc_lookback = int(metrics.get("SC_lookback_days", 60) or 60)
    sp_lookback = int(metrics.get("SP_lookback_days", 60) or 60)
    sp_quantile = float(metrics.get("SP_threshold_quantile", 0.75) or 0.75)
    if None in (sc_current, sc_threshold, sp_current, sp_threshold):
        return (
            f"<section class=\"explanation\"><h2>Why this is {escape(label)}</h2>"
            f"<p>The {observation_date} raw signal was <b>BEARISH</b>, but the saved signal does not "
            "contain all threshold values needed for a detailed comparison.</p></section>"
        )

    sc_low = float(sc_current) <= float(sc_threshold)
    sp_high = float(sp_current) > float(sp_threshold)
    allowed = bool(_row_value(row, "trade_allowed", False))
    decision = (
        "Production permits a SHORT QQQ setup."
        if allowed
        else "Production filters this setup out; it is not tradable in strategy v1; do not short QQQ."
    )
    return f"""
<section class="explanation"><h2>Why this is {escape(label)}</h2>
<p>The {observation_date} raw signal was <b>BEARISH</b>. The thresholds use only completed sessions before that observation date.</p>
<div class="rule-checks">
<div class="rule-check"><span class="rule-name">SC_LOW = {str(sc_low).upper()}</span><span>SC current GEX level: <b>{_number(sc_current)}</b></span><span>SC current GEXDelta: <b>{_number(sc_delta)}</b></span><span>Prior-{sc_lookback} median: <b>{_number(sc_threshold)}</b></span><span>Check: {_number(sc_current)} {'&le;' if sc_low else '&gt;'} {_number(sc_threshold)}</span></div>
<div class="rule-check"><span class="rule-name">SP_HIGH = {str(sp_high).upper()}</span><span>SP current GEX level: <b>{_number(sp_level)}</b></span><span>SP current GEXDelta: <b>{_number(sp_delta)}</b></span><span>SP delta share: <b>{_unsigned_pct(sp_current)}</b></span><span>Prior-{sp_lookback} P{int(sp_quantile * 100)}: <b>{_unsigned_pct(sp_threshold)}</b></span><span>Check: {_unsigned_pct(sp_current)} {'&gt;' if sp_high else '&le;'} {_unsigned_pct(sp_threshold)}</span></div>
</div>
<p class="decision">{decision}</p></section>"""


def _action_plan_section(row: Any, plan: Any | None, qqq_reference: dict[str, Any] | None) -> str:
    classification = str(_row_value(row, "classification", "") or "")
    allowed = bool(_row_value(row, "trade_allowed", False))
    skip_reason = str(_row_value(row, "skip_reason", "") or "")
    metrics = _metrics(row)
    observation_date = _parse_date(_row_value(row, "observation_date"))
    action_at = str(_row_value(row, "actionable_at", "N/A") or "N/A")
    action_date = _parse_date(_row_value(row, "action_date"))
    reference = _reference_details(row, qqq_reference)
    reference_price = reference["price"]
    plan_dip = _row_value(plan, "dip_price") if plan is not None else None
    dip_price = plan_dip or (float(reference_price) * 0.99 if reference_price else None)
    overlap_warning = metrics.get("production_overlap_warning")

    if classification == "REVERSAL_GREEN":
        calendar = USCashCalendar()
        d3 = calendar.session_offset(observation_date, 3) if observation_date else None
        d5 = calendar.session_offset(observation_date, 5) if observation_date else None
        d3_at = calendar.actionable_at(d3).isoformat() if d3 else "N/A"
        d5_close = calendar.cash_close(d5).isoformat() if d5 else "N/A"
        decision = (
            "<b>DO NOT PLACE AN ORDER.</b> Production has marked this signal as not tradable. "
            f"Reason: {escape(skip_reason or 'No production authorization was recorded.')}"
            if not allowed
            else "<b>ACTION: PLACE A QQQ BUY LIMIT ORDER.</b>"
        )
        execution_note = (
            "These are the frozen execution rules for reference only; production has not authorized this signal."
            if not allowed
            else "Execute these steps only while the production decision remains YES."
        )
        manual_reference = reference_price is None
        reference_value = "N/A — calculate manually" if manual_reference else _money(reference_price)
        limit_value = "Q0 × 0.99" if manual_reference else _money(dip_price)
        reference_source = "Manual QQQ price required" if manual_reference else str(reference.get("source") or "N/A")
        reference_unavailable = reference.get("unavailable_reason")
        order_lines = f"""
<p class="muted"><b>{execution_note}</b></p>
<div class="action-grid">
<div><span class="label">D1 03:30 ET QQQ reference</span><strong>{reference_value}</strong><small>{escape(reference_source)}</small></div>
<div><span class="label">Buy limit (reference −1%)</span><strong>{limit_value}</strong><small>{'Get Q0 manually, then place Q0 × 0.99' if manual_reference else 'Place at the calculated QQQ limit price'}</small></div>
<div><span class="label">Limit-order expiry</span><strong>D3 03:30 ET</strong><small>{escape(d3_at)}</small></div>
<div><span class="label">If unfilled</span><strong>Cancel limit; buy at market</strong><small>At D3 03:30 ET, only if production authorization remains valid; otherwise remain flat</small></div>
<div><span class="label">If filled</span><strong>Hold the QQQ long</strong><small>No additional entry; no strategy stop/target is defined</small></div>
<div><span class="label">Exit</span><strong>D5 cash close</strong><small>{escape(d5_close)}</small></div>
</div>"""
        reference_note = (
            f"Reference timestamp: {escape(str(reference.get('timestamp') or 'N/A'))}. "
            "Before D1 03:30 ET this is the current IB quote; at or after D1 03:30 ET it is the exact IB historical 03:30 one-minute bar open. "
            + ("IB did not provide the reference, but this is not a production blocker; obtain Q0 manually and calculate Q0 × 0.99. " if manual_reference else "")
            + (f"IB detail: {escape(str(reference_unavailable))}" if reference_unavailable else "")
        )
        overlap_note = (
            f"<p class=\"decision overlap\"><b>OPTIONAL OVERLAP WARNING:</b> {escape(str(overlap_warning))}. "
            "This does not make today’s signal non-tradable. If you already have a previous order or position, you may choose to skip this new order.</p>"
            if overlap_warning
            else ""
        )
        return f"""
<section class="action-section"><div class="section-kicker">DECISION AND EXECUTION</div><h2>Reversal Green action plan</h2>
<p class="decision {'blocked' if not allowed else 'approved'}">{'<b>TRADABLE: YES.</b> ' if allowed else ''}{decision}</p>
{overlap_note}
<p class="muted">This plan uses QQQ prices, not NQMAIN. NQMAIN is only the signal and historical percentage-path proxy.</p>
{order_lines}
<p class="muted">{reference_note}</p>
</section>"""

    if classification in {"STRONG_YELLOW", "RELIABLE_YELLOW"}:
        tp = "−0.80%" if classification == "STRONG_YELLOW" else "−0.40%"
        sl = "+1.00%" if classification == "STRONG_YELLOW" else "+0.80%"
        decision = (
            "<b>ACTION: SHORT QQQ at D1 03:30 ET.</b>"
            if allowed
            else f"<b>DO NOT SHORT QQQ.</b> Production has filtered this setup. Reason: {escape(skip_reason or 'Not tradable.')}"
        )
        return f"""
<section class="action-section"><div class="section-kicker">DECISION AND EXECUTION</div><h2>{escape(classification.replace('_', ' ').title())} action plan</h2>
<p class="decision {'approved' if allowed else 'blocked'}">{'<b>TRADABLE: YES.</b> ' if allowed else ''}{decision}</p>
<ul class="steps"><li>Entry: {'short QQQ at D1 03:30 ET' if allowed else 'no entry'}.</li><li>Take profit: {tp}; stop-loss: {sl}.</li><li>Exit when either level is touched; the Yellow time-exit rule is not defined.</li></ul>
</section>"""

    if classification == "NORMAL_GREEN":
        decision = "<b>ACTION: BUY QQQ at D3 03:30 ET.</b>" if allowed else "<b>DO NOT BUY.</b> Production has not authorized this setup."
        return f"""
<section class="action-section"><div class="section-kicker">DECISION AND EXECUTION</div><h2>Normal Green action plan</h2>
<p class="decision {'approved' if allowed else 'blocked'}">{'<b>TRADABLE: YES.</b> ' if allowed else ''}{decision}</p>
<ul class="steps"><li>Entry: D3 03:30 ET market price.</li><li>Take profit: +2.50%; otherwise hold to the D5 cash close.</li></ul>
</section>"""

    reason = skip_reason or "No tradable setup was generated."
    return f"""
<section class="action-section"><div class="section-kicker">DECISION AND EXECUTION</div><h2>No-trade decision</h2>
<p class="decision blocked"><b>DO NOT PLACE AN ORDER.</b> {escape(reason)}</p></section>"""


def _signal_rule_summary(row: Any) -> str:
    classification = str(_row_value(row, "classification", "") or "")
    metrics = _metrics(row)
    allowed = bool(_row_value(row, "trade_allowed", False))
    if classification.endswith("_YELLOW"):
        sc_current = metrics.get("SC_GEX_current")
        sc_threshold = metrics.get("SC_GEX_threshold")
        sp_current = metrics.get("SP_delta_share_current")
        sp_threshold = metrics.get("SP_delta_share_threshold")
        if None not in (sc_current, sc_threshold, sp_current, sp_threshold):
            sc_low = float(sc_current) <= float(sc_threshold)
            sp_high = float(sp_current) > float(sp_threshold)
            decision = "PRODUCTION: SHORT QQQ" if allowed else "PRODUCTION: NO TRADE"
            return (
                f"SC_LOW {str(sc_low).upper()} (SC GEX level {_number(sc_current)} {'<=' if sc_low else '>'} {_number(sc_threshold)}); "
                f"SP_HIGH {str(sp_high).upper()} ({_unsigned_pct(sp_current)} {'>' if sp_high else '<='} {_unsigned_pct(sp_threshold)}); {decision}."
            )
    if classification in {"NORMAL_GREEN", "REVERSAL_GREEN"}:
        decision = "PRODUCTION: LONG QQQ" if allowed else "PRODUCTION: NO TRADE"
        return f"Prior five-session NQ return: {_pct(metrics.get('prior_5d_nq_return'))}; {decision}."
    return str(_row_value(row, "skip_reason", "") or classification.replace("_", " ").title())


def _historical_performance_section(classification: str) -> str:
    if classification == "REVERSAL_GREEN":
        stats = REVERSAL_GREEN_HISTORICAL_STATS
        return f"""
<section class="history-section"><div class="section-kicker">HISTORICAL EVIDENCE</div><h2>Reversal Green historical performance</h2>
<p>Frozen production rule <b>{escape(stats['strategy_version'])}</b>, {escape(stats['window'])}. Results use NQ's historical percentage path as a QQQ proxy; they are not a historical QQQ execution ledger.</p>
<div class="history-grid">
<div class="history-card"><span class="label">All signals, hypothetical</span><strong>{stats['hypothetical_win_rate']:.2%}</strong><small>{stats['hypothetical_wins']} wins / {stats['hypothetical_losses']} losses from {stats['candidate_count']} signals</small><small>Average return: {_pct3(stats['hypothetical_average_return'])}</small><small>Profit factor: {stats['hypothetical_profit_factor']:.2f}</small></div>
<div class="history-card"><span class="label">Portfolio-executed only</span><strong>{stats['executed_win_rate']:.2%}</strong><small>{stats['executed_wins']} wins / {stats['executed_losses']} losses from {stats['executed_count']} trades</small><small>Average return: {_pct3(stats['executed_average_return'])}</small><small>Profit factor: {stats['executed_profit_factor']:.2f}</small></div>
</div>
<p class="muted">The hypothetical figure includes signals skipped because another position was already open. The executed figure reflects the single-position portfolio rule.</p>
</section>"""

    stats = SIGNAL_HISTORICAL_STATS.get(classification)
    if stats is None:
        label = classification.replace("_", " ").title() if classification else "Current signal"
        return f"""
<section class="history-section"><div class="section-kicker">HISTORICAL EVIDENCE</div><h2>{escape(label)} historical performance</h2>
<p>No applicable historical trade-performance summary is available for this classification.</p></section>"""

    pf = "N/A" if stats["profit_factor"] is None else f"{stats['profit_factor']:.2f}"
    return f"""
<section class="history-section"><div class="section-kicker">HISTORICAL EVIDENCE</div><h2>{escape(stats['label'])} historical performance</h2>
<p>This section matches the current signal type. The frozen causal backtest uses NQ's historical percentage path as a QQQ proxy; it is not a historical QQQ execution ledger.</p>
<div class="history-grid">
<div class="history-card"><span class="label">All candidates, no existing position</span><strong>{stats.get('candidate_win_rate', stats['win_rate']):.2%}</strong><small>{stats.get('candidate_wins', stats['wins'])} wins / {stats.get('candidate_losses', stats['losses'])} losses from {stats['candidate_count']} signals</small><small>Average return: {_pct3(stats.get('candidate_average_return', stats['average_return']))}</small><small>Profit factor: {stats.get('candidate_profit_factor', pf) if stats.get('candidate_profit_factor') is not None else 'N/A'}</small></div>
<div class="history-card"><span class="label">Portfolio-executed only</span><strong>{stats['win_rate']:.2%}</strong><small>{stats['wins']} wins / {stats['losses']} losses from {stats['executed_count']} trades</small><small>Average return: {_pct3(stats['average_return'])}</small><small>Profit factor: {pf}</small></div>
<div class="history-card"><span class="label">Candidate signals</span><strong>{stats['candidate_count']}</strong><small>{stats['skipped_count']} were skipped by the single-position rule</small></div>
</div>
<p class="muted">The first card assumes every candidate could be traded because no position was open. The second card reflects the historical single-position portfolio. Both are separate from the live portfolio metrics above.</p>
</section>"""


def _yellow_guide() -> str:
    return """
<section><div class="section-kicker">CLASSIFICATION GUIDE</div><h2>Yellow classification guide — what each signal allows</h2>
<p>Yellow begins with a BEARISH raw signal. Green begins with a BULLISH raw signal.</p>
<table class="guide"><thead><tr><th>Classification</th><th>Meaning</th><th>Production action</th></tr></thead><tbody>
<tr><td><b>Strong Yellow</b></td><td>SC_LOW and SP_HIGH</td><td><span class="yes">SHORT QQQ</span></td></tr>
<tr><td><b>Reliable Yellow</b></td><td>SC_LOW and not SP_HIGH</td><td><span class="yes">SHORT QQQ</span></td></tr>
<tr><td><b>Mixed / Weak Yellow</b></td><td>SC is not low</td><td><span class="no">NO TRADE</span></td></tr>
<tr><td><b>Reversal Green</b></td><td>Bullish signal after negative prior five-session NQ return</td><td><span class="yes">BUY −1% DIP, then D3 FALLBACK</span></td></tr>
<tr><td><b>Normal Green</b></td><td>Bullish signal after positive prior five-session NQ return</td><td><span class="yes">BUY D3 03:30 ET</span></td></tr>
</tbody></table><p class="muted">Tradable Yellow means Strong Yellow or Reliable Yellow. Mixed and Weak Yellow are filtered out.</p></section>"""


def render_html_report(
    store: StrategyStore,
    strategy_version: str,
    live_nq: dict[str, Any] | None = None,
    qqq_reference: dict[str, Any] | None = None,
    archive_links: list[Any] | None = None,
    focus_date: Any = None,
    report_as_of: date | None = None,
    generated_at: datetime | None = None,
) -> str:
    snapshot = store.snapshot()
    signals = store.recent_signals(200, strategy_version=strategy_version)
    cutoff_date = _parse_date(focus_date) if focus_date is not None else None
    if cutoff_date is not None:
        signals = [
            row for row in signals
            if (_parse_date(_row_value(row, "observation_date")) or date.min) <= cutoff_date
        ]
    focus_signal = signals[0] if signals else None
    if focus_date is not None:
        wanted = str(focus_date)
        focus_signal = next(
            (row for row in signals if str(_row_value(row, "observation_date", "")) == wanted),
            focus_signal,
        )
    focus_plan = _plan_for_signal(store, focus_signal) if focus_signal is not None else None
    if focus_signal is not None:
        derived_reference = _reference_details(focus_signal, qqq_reference)
        if qqq_reference is None and derived_reference["price"] is not None:
            qqq_reference = {
                "reference_price": derived_reference["price"],
                "reference_timestamp": derived_reference["timestamp"],
                "reference_source": derived_reference["source"],
                "reference_rule": derived_reference["rule"],
            }

    trades = store.list_trades()
    closed = [trade for trade in trades if trade["status"] == "CLOSED"]
    returns = [float(trade["return_pct"]) for trade in closed if trade["return_pct"] is not None]
    wins = sum(value > 0 for value in returns)
    profit = sum(float(trade["pnl_usd"] or 0) for trade in closed if float(trade["pnl_usd"] or 0) > 0)
    loss = abs(sum(float(trade["pnl_usd"] or 0) for trade in closed if float(trade["pnl_usd"] or 0) < 0))
    win_rate = wins / len(returns) if returns else 0.0
    focus_classification = str(_row_value(focus_signal, "classification", "") or "") if focus_signal is not None else ""

    if focus_signal is not None:
        explanation = _signal_meaning(focus_signal)
        if focus_classification.endswith("_YELLOW"):
            explanation_html = _yellow_explanation(focus_signal)
        else:
            explanation_html = f"<section class=\"explanation\"><div class=\"section-kicker\">SIGNAL MEANING</div><h2>What this signal means</h2><p>{explanation}</p></section>"
        action_html = _action_plan_section(focus_signal, focus_plan, qqq_reference)
    else:
        explanation_html = ""
        action_html = "<section class=\"action-section\"><h2>No current signal</h2><p class=\"decision blocked\"><b>DO NOT PLACE AN ORDER.</b> No signal has been recorded.</p></section>"

    nq_html = ""
    if live_nq:
        nq_html = (
            f"<div class=\"market-strip\"><span><b>NQMAIN proxy</b> {_money(live_nq.get('price'))}</span>"
            f"<span>Yesterday close {_money(live_nq.get('previous_close'))}</span>"
            f"<span>Move {_pct(live_nq.get('move_fraction'))}</span>"
            f"<span>Source {escape(str(live_nq.get('source') or 'N/A'))}</span></div>"
        )
    qqq_html = ""
    if focus_signal is not None:
        reference = _reference_details(focus_signal, qqq_reference)
        reference_source = reference.get("source") or ("Manual price required" if reference.get("price") is None else "N/A")
        qqq_html = (
            f"<div class=\"quote-card\"><span class=\"section-kicker\">QQQ ORDER REFERENCE</span>"
            f"<strong>{_money(reference.get('price'))}</strong>"
            f"<span>{escape(str(reference_source))}</span>"
            f"<small>{escape(str(reference.get('timestamp') or 'N/A'))}</small></div>"
        )

    signal_rows = "".join(
        "<tr>"
        f"<td>{escape(str(row['observation_date'] or ''))}</td>"
        f"<td><b>{escape(str(row['classification'] or ''))}</b></td>"
        f"<td class={'yes' if row['trade_allowed'] else 'no'}>{'YES' if row['trade_allowed'] else 'NO'}</td>"
        f"<td class='why'>{escape(_signal_rule_summary(row))}</td>"
        f"<td>{escape(str(row['actionable_at'] or 'N/A'))}</td>"
        "</tr>"
        for row in signals
    ) or "<tr><td colspan='5'>No signals recorded yet.</td></tr>"
    trade_rows = "".join(
        "<tr>"
        + "".join(
            f"<td>{escape(str(value or ''))}</td>"
            for value in (
                row["trade_id"], row["signal_type"], row["entry_timestamp"], row["exit_timestamp"], _pct(row["return_pct"]), _money(row["pnl_usd"])
            )
        )
        + "</tr>"
        for row in reversed(trades[-50:])
    ) or "<tr><td colspan='6'>No shadow trades recorded yet.</td></tr>"
    comparisons = store.recent_strategy_comparisons(200)
    if cutoff_date is not None:
        comparisons = [
            row for row in comparisons
            if (_parse_date(_row_value(row, "observation_date")) or date.min) <= cutoff_date
        ]
    shadow_version = str(comparisons[0]["shadow_strategy_version"] if comparisons else "v1.1.0-shadow")
    production_signals_by_id = {
        str(_row_value(row, "signal_id")): row
        for row in signals
        if _row_value(row, "signal_id")
    }

    def _comparison_production_value(comparison: Any, key: str, fallback: Any) -> Any:
        signal = production_signals_by_id.get(str(_row_value(comparison, "production_signal_id", "")))
        value = _row_value(signal, key) if signal is not None else None
        return fallback if value is None else value

    comparison_rows = "".join(
        "<tr>"
        f"<td>{escape(str(row['observation_date'] or ''))}</td>"
        f"<td>{escape(str(_comparison_production_value(row, 'classification', row['production_classification']) or ''))}</td>"
        f"<td>{'YES' if _comparison_production_value(row, 'trade_allowed', row['production_trade_allowed']) else 'NO'}</td>"
        f"<td>{escape(str(row['shadow_classification'] or ''))}</td>"
        f"<td>{'YES' if row['shadow_trade_allowed'] else 'NO'}</td>"
        f"<td>{escape(str(row['shadow_outcome_status'] or ''))}</td>"
        f"<td>{escape(_comparison_return(row))}</td></tr>"
        for row in comparisons
    ) or "<tr><td colspan='7'>No production/shadow comparisons recorded yet.</td></tr>"

    archive_rows = "".join(
        f"<li><a href=\"{escape(str(_row_value(row, 'url') or '#'), quote=True)}\">{escape(str(_row_value(row, 'report_date', 'N/A')))}</a> <small>generated {escape(str(_row_value(row, 'generated_at', 'N/A')))}</small></li>"
        for row in (archive_links or [])
    ) or "<li>No historical snapshots recorded yet.</li>"
    report_metadata = ""
    if report_as_of is not None or generated_at is not None:
        report_metadata = (
            f"<div class=\"metadata\"><b>As-of:</b> {escape(str(report_as_of or 'N/A'))} &nbsp; "
            f"<b>Observation:</b> {escape(str(focus_date or 'N/A'))} &nbsp; "
            f"<b>Generated:</b> {escape(generated_at.isoformat() if generated_at else 'N/A')}</div>"
        )

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>SPX GEX Signal Report</title>
<style>
:root{{--ink:#172033;--muted:#60708a;--line:#dce5f0;--card:#fff;--bg:#f4f7fb;--green:#08783e;--red:#b42318;--blue:#155eef;--amber:#b54708}}
*{{box-sizing:border-box}}body{{font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;margin:0;line-height:1.5;color:var(--ink);background:var(--bg)}}main{{max-width:1180px;margin:auto;padding:28px 18px 60px}}h1{{font-size:clamp(1.7rem,3vw,2.5rem);margin:.1rem 0 .2rem;letter-spacing:-.03em}}h2{{font-size:1.15rem;margin:.25rem 0 .7rem}}p{{margin:.55rem 0}}section{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:20px;margin:16px 0;box-shadow:0 5px 18px rgba(16,42,75,.04)}}.hero{{display:flex;justify-content:space-between;gap:18px;align-items:flex-start;background:linear-gradient(135deg,#102a56,#1858a8);color:#fff;border:0}}.hero p,.hero .muted{{color:#d9e7ff}}.hero-side{{min-width:220px}}.quote-card{{display:flex;flex-direction:column;gap:2px;background:#edf5ff;color:var(--ink);border-radius:14px;padding:14px 16px;min-width:210px}}.quote-card strong{{font-size:1.55rem}}.quote-card span:not(.section-kicker){{color:var(--muted);font-size:.86rem}}.section-kicker{{font-size:.72rem;font-weight:800;letter-spacing:.1em;color:var(--blue);text-transform:uppercase}}.hero .section-kicker{{color:#b9d4ff}}.metadata,.muted{{font-size:.84rem;color:var(--muted)}}.market-strip{{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0}}.market-strip span{{background:#eaf2fc;border:1px solid #d8e7f8;border-radius:999px;padding:6px 11px;font-size:.84rem}}.metrics,.history-grid,.action-grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px}}.metric,.history-card,.action-grid>div{{background:#f7faff;border:1px solid #e1ebf7;border-radius:12px;padding:13px}}.metric .label,.action-grid .label,.history-card .label{{display:block;color:var(--muted);font-size:.78rem}}.metric .value,.history-card strong,.action-grid strong{{display:block;font-size:1.17rem;font-weight:800;margin-top:3px}}.history-card strong{{font-size:1.55rem;color:var(--blue)}}.history-card small,.action-grid small{{display:block;color:var(--muted);font-size:.78rem;margin-top:4px}}.decision{{border-radius:12px;padding:13px 15px;background:#fff8eb;border:1px solid #f7d9a7}}.decision.approved{{background:#eaf8ef;border-color:#b7e3c5;color:#075e31}}.decision.blocked{{background:#fff0ef;border-color:#f4c7c3;color:#8d1c16}}.rule-checks{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px;margin:14px 0}}.rule-check{{display:flex;flex-direction:column;gap:4px;background:#f8fafc;border-left:4px solid #f59e0b;border-radius:9px;padding:13px}}.rule-name{{font-weight:800}}.steps{{padding-left:22px}}table{{border-collapse:collapse;width:100%;font-size:.86rem}}th,td{{border-bottom:1px solid #e5eaf2;text-align:left;padding:9px 8px;vertical-align:top}}th{{background:#f1f5f9;font-size:.77rem;text-transform:uppercase;letter-spacing:.04em}}td{{white-space:nowrap}}td.why{{white-space:normal;min-width:310px}}.yes{{color:var(--green);font-weight:800}}.no{{color:var(--red);font-weight:800}}a{{color:#155eef;text-decoration:none}}a:hover{{text-decoration:underline}}ul{{margin-top:.6rem}}@media(max-width:700px){{main{{padding:18px 10px 40px}}section{{padding:15px;border-radius:12px}}.hero{{display:block}}.hero-side{{margin-top:14px}}table{{display:block;overflow-x:auto}}}}
</style><style>.hero .market-strip span{{color:var(--ink)}}.hero .metadata{{color:#d9e7ff}}</style></head><body><main>
<section class="hero"><div><div class="section-kicker">SPX GEX SIGNAL ASSISTANT</div><h1>Production decision report</h1><p>Strategy version: <b>{escape(strategy_version)}</b></p>{nq_html}{report_metadata}</div><div class="hero-side">{qqq_html}</div></section>
<section><div class="section-kicker">PORTFOLIO</div><div class="metrics"><div class="metric"><span class="label">State</span><span class="value">{escape(snapshot.state.value)}</span></div><div class="metric"><span class="label">Shadow NAV</span><span class="value">{_money(snapshot.shadow_nav)}</span></div><div class="metric"><span class="label">Closed trades</span><span class="value">{len(closed)}</span></div><div class="metric"><span class="label">Live-ledger win rate</span><span class="value">{win_rate:.1%}</span></div><div class="metric"><span class="label">Profit factor</span><span class="value">{(profit / loss) if loss else ('N/A' if not profit else '∞')}</span></div></div><p class="muted">Live-ledger metrics describe this portfolio only. See the historical evidence section for the Reversal Green backtest.</p></section>
{explanation_html}
{action_html}
{_historical_performance_section(focus_classification)}
{_yellow_guide()}
<section><div class="section-kicker">AUDIT TRAIL</div><h2>Recent signals</h2><table><thead><tr><th>Observation</th><th>Classification</th><th>Prod allowed</th><th>Reason / action</th><th>Actionable at</th></tr></thead><tbody>{signal_rows}</tbody></table></section>
<section><div class="section-kicker">PAPER LEDGER</div><h2>Shadow trades</h2><table><thead><tr><th>Trade ID</th><th>Type</th><th>Entry</th><th>Exit</th><th>Return</th><th>P&amp;L</th></tr></thead><tbody>{trade_rows}</tbody></table></section>
<section><div class="section-kicker">FORWARD TEST</div><h2>Production vs {escape(shadow_version)} shadow</h2><p>This is a same-observation comparison between the production classifier and a research-only shadow classifier. <b>Prod allowed</b> is the production classifier decision for that date; it is not a statement that an order was filled. The shadow column is hypothetical and never executes. Outcome and return are the shadow NQ-proxy result when enough future bars are available.</p><table><thead><tr><th>Observation</th><th>Production</th><th>Prod allowed</th><th>Shadow</th><th>Shadow allowed</th><th>Shadow outcome</th><th>Shadow return</th></tr></thead><tbody>{comparison_rows}</tbody></table></section>
<section><div class="section-kicker">ARCHIVE</div><h2>Historical reports</h2><ul>{archive_rows}</ul></section>
</main></body></html>"""
