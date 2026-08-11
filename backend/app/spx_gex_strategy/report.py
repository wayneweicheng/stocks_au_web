from __future__ import annotations

import json
from datetime import date, datetime
from html import escape
from typing import Any

from .storage import StrategyStore


def _money(value: Any) -> str:
    try:
        return f"${float(value):,.2f}"
    except (TypeError, ValueError):
        return "n/a"


def _pct(value: Any) -> str:
    try:
        return f"{float(value):+.2%}"
    except (TypeError, ValueError):
        return "n/a"


def _unsigned_pct(value: Any) -> str:
    try:
        return f"{float(value):.2%}"
    except (TypeError, ValueError):
        return "n/a"


def _number(value: Any) -> str:
    try:
        return f"{float(value):,.2f}"
    except (TypeError, ValueError):
        return "n/a"


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
    outcome = _metrics({"metrics_json": _row_value(row, "shadow_outcome_json", "")})
    return _pct(outcome.get("return_pct"))


def _yellow_explanation(row: Any) -> str:
    metrics = _metrics(row)
    classification = str(_row_value(row, "classification", "YELLOW"))
    label = classification.replace("_", " ").title()
    observation_date = escape(str(_row_value(row, "observation_date", "")))
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
    sp_percentile_label = f"P{int(sp_quantile * 100)}"
    if None in (sc_current, sc_threshold, sp_current, sp_threshold):
        return (
            f"<section><h2>Why this is {escape(label)}</h2>"
            f"<p>The {observation_date} raw signal was <b>BEARISH</b>, so it entered the Yellow classifier. "
            "The saved signal does not contain all four threshold values needed for a detailed comparison.</p></section>"
        )

    sc_low = float(sc_current) <= float(sc_threshold)
    sp_high = float(sp_current) > float(sp_threshold)
    sc_operator = "&le;" if sc_low else "&gt;"
    sp_operator = "&gt;" if sp_high else "&le;"
    sc_status = "TRUE" if sc_low else "FALSE"
    sp_status = "TRUE" if sp_high else "FALSE"
    allowed = bool(_row_value(row, "trade_allowed", False))
    decision = (
        f"This combination produces <b>{escape(classification)}</b>. "
        + ("It is tradable in strategy v1 as a SHORT QQQ setup." if allowed else "It is filtered out and is not tradable in strategy v1.")
    )
    return f"""
<section><h2>Why this is {escape(label)}</h2>
<p>The {observation_date} raw signal was <b>BEARISH</b>, so it entered the Yellow classifier. Each threshold uses only the configured completed US-session lookback before that observation date.</p>
<div class="rule-checks">
<div class="rule-check"><span class="rule-name">SC_LOW = {sc_status}</span><span>SC current GEX level: <b>{_number(sc_current)}</b></span><span>SC current GEXDelta: <b>{_number(sc_delta)}</b></span><span>Prior-{sc_lookback} SC GEX median: <b>{_number(sc_threshold)}</b></span><span>Level check: {_number(sc_current)} {sc_operator} {_number(sc_threshold)}.</span></div>
<div class="rule-check"><span class="rule-name">SP_HIGH = {sp_status}</span><span>SP current GEX level: <b>{_number(sp_level)}</b></span><span>SP current GEXDelta: <b>{_number(sp_delta)}</b></span><span>SP delta share: <b>{_unsigned_pct(sp_current)}</b></span><span>Prior-{sp_lookback} SP share {sp_percentile_label}: <b>{_unsigned_pct(sp_threshold)}</b></span><span>Share check: {_unsigned_pct(sp_current)} {sp_operator} {_unsigned_pct(sp_threshold)}.</span></div>
</div>
<p class="decision">{decision}</p></section>"""


def _signal_rule_summary(row: Any) -> str:
    classification = str(_row_value(row, "classification", ""))
    metrics = _metrics(row)
    if classification.endswith("_YELLOW"):
        sc_current = metrics.get("SC_GEX_current")
        sc_threshold = metrics.get("SC_GEX_threshold")
        sp_current = metrics.get("SP_delta_share_current")
        sp_threshold = metrics.get("SP_delta_share_threshold")
        sc_lookback = int(metrics.get("SC_lookback_days", 60) or 60)
        sp_lookback = int(metrics.get("SP_lookback_days", 60) or 60)
        sp_quantile = float(metrics.get("SP_threshold_quantile", 0.75) or 0.75)
        if None not in (sc_current, sc_threshold, sp_current, sp_threshold):
            sc_low = float(sc_current) <= float(sc_threshold)
            sp_high = float(sp_current) > float(sp_threshold)
            return (
                f"SC_LOW {str(sc_low).upper()} (SC GEX level {_number(sc_current)} "
                f"{'<=' if sc_low else '>'} {_number(sc_threshold)}); "
                f"SP_HIGH {str(sp_high).upper()} ({_unsigned_pct(sp_current)} "
                f"{'>' if sp_high else '<='} {_unsigned_pct(sp_threshold)}). "
                f"Lookbacks SC {sc_lookback}D / SP {sp_lookback}D, SP P{int(sp_quantile * 100)}. "
                f"This combination gives {classification}; "
                f"{'tradable SHORT QQQ' if bool(_row_value(row, 'trade_allowed', False)) else 'not tradable in v1'}."
            )
    if classification in {"NORMAL_GREEN", "REVERSAL_GREEN"}:
        return f"Prior five-session NQ return: {_pct(metrics.get('prior_5d_nq_return'))}; tradable LONG QQQ."
    return str(_row_value(row, "skip_reason", "") or classification.replace("_", " ").title())


def _latest_signal_explanation(signals: list[Any], focus_date: Any = None) -> str:
    if not signals:
        return ""
    latest = signals[0]
    if focus_date is not None:
        wanted = str(focus_date)
        latest = next(
            (row for row in signals if str(_row_value(row, "observation_date", "")) == wanted),
            latest,
        )
    classification = str(_row_value(latest, "classification", ""))
    if classification.endswith("_YELLOW"):
        return _yellow_explanation(latest)
    label = classification.replace("_", " ").title()
    observation_date = escape(str(_row_value(latest, "observation_date", "")))
    if classification in {"NORMAL_GREEN", "REVERSAL_GREEN"}:
        prior_return = _metrics(latest).get("prior_5d_nq_return")
        comparison = "above 0%" if classification == "NORMAL_GREEN" else "at or below 0%"
        return (
            f"<section><h2>Why this is {escape(label)}</h2><p>The {observation_date} raw signal was "
            f"<b>BULLISH</b>. Its prior five-session NQ return was <b>{_pct(prior_return)}</b>, {comparison}; "
            "this Green classification is tradable in strategy v1.</p></section>"
        )
    if classification == "NO_SIGNAL":
        return f"<section><h2>Why there is no signal</h2><p>No BULLISH or BEARISH raw signal was recorded for {observation_date}.</p></section>"
    if classification == "INSUFFICIENT_HISTORY":
        reason = escape(str(_row_value(latest, "skip_reason", "Insufficient prior observations")))
        return f"<section><h2>Why the signal is not classified</h2><p>{reason}. The Yellow rules require 60 prior US sessions.</p></section>"
    return ""


def _yellow_guide() -> str:
    return """
<section><h2>Yellow classification guide</h2>
<p>Every Yellow starts with a <b>BEARISH</b> raw signal. <b>SC_LOW</b> compares the current SC <b>GEX level</b> with the prior-60 SC GEX-level median. <b>SP_HIGH</b> remains delta-based: SP GEXDelta as a share of total absolute BC/BP/SC/SP GEXDelta, compared with its prior-60 75th percentile.</p>
<table class="guide"><thead><tr><th>Classification</th><th>SC_LOW</th><th>SP_HIGH</th><th>Tradable in v1?</th><th>Action</th></tr></thead><tbody>
<tr><td><b>Strong Yellow</b></td><td>TRUE</td><td>TRUE</td><td><span class="yes">YES</span></td><td>SHORT QQQ</td></tr>
<tr><td><b>Reliable Yellow</b></td><td>TRUE</td><td>FALSE</td><td><span class="yes">YES</span></td><td>SHORT QQQ</td></tr>
<tr><td><b>Mixed Yellow</b></td><td>FALSE</td><td>TRUE</td><td><span class="no">NO</span></td><td>Filtered out</td></tr>
<tr><td><b>Weak Yellow</b></td><td>FALSE</td><td>FALSE</td><td><span class="no">NO</span></td><td>Filtered out</td></tr>
</tbody></table>
<p><small>“Tradable Yellow” is not a separate classification: it means either <b>Strong Yellow</b> or <b>Reliable Yellow</b>.</small></p>
</section>"""


def render_html_report(
    store: StrategyStore,
    strategy_version: str,
    live_nq: dict[str, Any] | None = None,
    archive_links: list[Any] | None = None,
    focus_date: Any = None,
    report_as_of: date | None = None,
    generated_at: datetime | None = None,
) -> str:
    snapshot = store.snapshot()
    signals = store.recent_signals(50, strategy_version=strategy_version)
    trades = store.list_trades()
    closed = [trade for trade in trades if trade["status"] == "CLOSED"]
    returns = [float(trade["return_pct"]) for trade in closed if trade["return_pct"] is not None]
    wins = sum(value > 0 for value in returns)
    profit = sum(float(trade["pnl_usd"] or 0) for trade in closed if float(trade["pnl_usd"] or 0) > 0)
    loss = abs(sum(float(trade["pnl_usd"] or 0) for trade in closed if float(trade["pnl_usd"] or 0) < 0))
    win_rate = wins / len(returns) if returns else 0.0
    latest_signal_explanation = _latest_signal_explanation(signals, focus_date)
    comparisons = store.recent_strategy_comparisons(50)
    shadow_version = str(comparisons[0]["shadow_strategy_version"] if comparisons else "v1.1.0-shadow")
    signal_rows = "".join(
        "<tr>"
        f"<td>{escape(str(row['observation_date'] or ''))}</td>"
        f"<td>{escape(str(row['classification'] or ''))}</td>"
        f"<td>{'YES' if row['trade_allowed'] else 'NO'}</td>"
        f"<td class='why'>{escape(_signal_rule_summary(row))}</td>"
        f"<td>{escape(str(row['actionable_at'] or ''))}</td>"
        + "</tr>"
        for row in signals
    ) or "<tr><td colspan='5'>No signals recorded yet.</td></tr>"
    trade_rows = "".join(
        "<tr>"
        + "".join(
            f"<td>{escape(str(value or ''))}</td>"
            for value in (
                row["trade_id"],
                row["signal_type"],
                row["entry_timestamp"],
                row["exit_timestamp"],
                _pct(row["return_pct"]),
                _money(row["pnl_usd"]),
            )
        )
        + "</tr>"
        for row in reversed(trades[-50:])
    ) or "<tr><td colspan='6'>No shadow trades recorded yet.</td></tr>"
    comparison_rows = "".join(
        "<tr>"
        f"<td>{escape(str(row['observation_date'] or ''))}</td>"
        f"<td>{escape(str(row['production_classification'] or ''))}</td>"
        f"<td>{'YES' if row['production_trade_allowed'] else 'NO'}</td>"
        f"<td>{escape(str(row['shadow_classification'] or ''))}</td>"
        f"<td>{'YES' if row['shadow_trade_allowed'] else 'NO'}</td>"
        f"<td>{escape(str(row['shadow_outcome_status'] or ''))}</td>"
        f"<td>{escape(_comparison_return(row))}</td>"
        "</tr>"
        for row in comparisons
    ) or "<tr><td colspan='7'>No production/shadow comparisons recorded yet.</td></tr>"
    nq_html = ""
    if live_nq:
        nq_html = (
            f"<p><b>Live NQMAIN:</b> {_money(live_nq.get('price'))} &nbsp; "
            f"<b>Yesterday close:</b> {_money(live_nq.get('previous_close'))} &nbsp; "
            f"<b>Move:</b> {_pct(live_nq.get('move_fraction'))} &nbsp; "
            f"<b>Source:</b> {escape(str(live_nq.get('source') or 'n/a'))}</p>"
        )
    archive_rows = ""
    for row in archive_links or []:
        report_date = str(_row_value(row, "report_date", ""))
        report_id = str(_row_value(row, "report_id", ""))
        archive_url = _row_value(row, "url") or f"/api/spx-gex/reports/{report_date}.html?report_id={report_id}"
        archive_rows += (
            "<li>"
            f"<a href=\"{escape(str(archive_url), quote=True)}\">"
            f"{escape(report_date)}</a>"
            f" <small>generated {escape(str(_row_value(row, 'generated_at', '')))}</small>"
            "</li>"
        )
    archive_html = (
        "<section><h2>Historical reports</h2><ul>"
        + (archive_rows or "<li>No historical snapshots recorded yet.</li>")
        + "</ul></section>"
    )
    report_metadata = ""
    if report_as_of is not None or generated_at is not None:
        generated_text = generated_at.isoformat() if generated_at is not None else "n/a"
        observation_text = str(focus_date or "n/a")
        report_metadata = (
            "<p>"
            f"<b>As-of date:</b> {escape(str(report_as_of or 'n/a'))} &nbsp; "
            f"<b>Observation date:</b> {escape(observation_text)} &nbsp; "
            f"<b>Generated:</b> {escape(generated_text)}"
            "</p>"
        )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>SPX GEX Signal Report</title>
<style>
body{{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:2rem;line-height:1.4;color:#172033;background:#f8fafc}}
main{{max-width:1100px;margin:auto}} section{{background:#fff;border:1px solid #dbe3ef;border-radius:10px;padding:1rem;margin:1rem 0;overflow:auto}}
h1{{margin-bottom:.25rem}} h2{{font-size:1.1rem}} .metrics{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:.75rem}}
.metric{{background:#eef6ff;border-radius:8px;padding:.75rem}} .label{{display:block;color:#526078;font-size:.8rem}} .value{{font-weight:700;font-size:1.1rem}}
table{{border-collapse:collapse;width:100%;font-size:.88rem}}th,td{{border-bottom:1px solid #e5eaf2;text-align:left;padding:.5rem;white-space:nowrap}}th{{background:#f1f5f9}}
.rule-checks{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:.75rem;margin:.75rem 0}}.rule-check{{display:flex;flex-direction:column;gap:.35rem;background:#f8fafc;border-left:4px solid #f59e0b;border-radius:6px;padding:.75rem}}.rule-name{{font-weight:750}}.decision{{background:#fff7ed;border-radius:6px;padding:.75rem}}.yes{{color:#08783e;font-weight:700}}.no{{color:#b42318;font-weight:700}}.guide td:first-child{{white-space:nowrap}}td.why{{white-space:normal;min-width:340px}}
</style></head><body><main>
<h1>SPX GEX Signal Report</h1><p>Production strategy version: <b>{escape(strategy_version)}</b></p>{nq_html}
{report_metadata}
<section><h2>Portfolio</h2><div class="metrics">
<div class="metric"><span class="label">State</span><span class="value">{escape(snapshot.state.value)}</span></div>
<div class="metric"><span class="label">Shadow NAV</span><span class="value">{_money(snapshot.shadow_nav)}</span></div>
<div class="metric"><span class="label">Closed trades</span><span class="value">{len(closed)}</span></div>
<div class="metric"><span class="label">Win rate</span><span class="value">{win_rate:.1%}</span></div>
<div class="metric"><span class="label">Profit factor</span><span class="value">{(profit / loss) if loss else ('n/a' if not profit else '∞')}</span></div>
</div></section>
{latest_signal_explanation}
{_yellow_guide()}
<section><h2>Recent signals</h2><table><thead><tr><th>Observation</th><th>Classification</th><th>Tradable</th><th>Why</th><th>Actionable at</th></tr></thead><tbody>{signal_rows}</tbody></table></section>
<section><h2>Shadow trades</h2><table><thead><tr><th>Trade ID</th><th>Type</th><th>Entry</th><th>Exit</th><th>Return</th><th>P&amp;L</th></tr></thead><tbody>{trade_rows}</tbody></table></section>
<section><h2>Production vs {escape(shadow_version)} shadow</h2><p>Production remains {escape(strategy_version)} and is the only strategy allowed to reserve or execute the portfolio. {escape(shadow_version)} is classification-only and follows a separate hypothetical NQ percentage-path outcome.</p><table><thead><tr><th>Observation</th><th>{escape(strategy_version)}</th><th>Prod allowed</th><th>{escape(shadow_version)}</th><th>Shadow allowed</th><th>Shadow outcome</th><th>Return</th></tr></thead><tbody>{comparison_rows}</tbody></table></section>
{archive_html}
</main></body></html>"""
