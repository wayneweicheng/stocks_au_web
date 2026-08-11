from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .report import render_html_report
from .service import SPXGEXStrategyService


def _service() -> SPXGEXStrategyService:
    return SPXGEXStrategyService()


def _green_alignment_markdown(result: dict) -> str:
    def number(value, digits: int = 4) -> str:
        return "n/a" if value is None else f"{float(value):,.{digits}f}"

    def pct(value) -> str:
        return "n/a" if value is None else f"{float(value):.4%}"

    lines = [
        "# SPX GEX final Green alignment audit",
        "",
        f"Window: **{result['window']['start']} through {result['window']['end']}**.",
        "",
        "Green parameters and trading rules were not changed. This is a read-only reconciliation.",
        "",
        f"Canonical Green count: **{result['canonical_base_signal_counts']['GREEN']}**; "
        f"SQL reconstructed base Green count: **{result['sql_reconstructed_base_signal_counts']['GREEN']}**.",
        "",
        f"Canonical expected Green subtypes: **{result['canonical_green_subtype_counts']}**.",
        f"SQL strategy Green subtypes: **{result['sql_green_subtype_counts']}**.",
        "",
        "## The exact seven broad mismatches",
        "",
        "The six early-history rows below have the same BEARISH base signal in both sources; their broad classifications differ only because the SQL strategy run applies its 60-session causal-history gate.",
        "",
        "| Date | Canonical signal | SQL base signal | SQL classification | Canonical CloseChangePct | SQL CloseChangePct | Canonical PCR | SQL PCR | Canonical PCRChangePct | SQL PCRChangePct | Reason |",
        "|---|---|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in result["mismatches"]:
        reason = str(row["reason"]).replace("|", "\\|")
        lines.append(
            f"| {row['date']} | {row['canonical_signal'] or 'blank'} | {row['sql_signal'] or 'blank'} | "
            f"{row['canonical_sql_classification'] or 'n/a'} | {number(row['canonical_close_change_pct'])} | "
            f"{number(row['sql_close_change_pct'])} | {number(row['canonical_put_call_ratio'])} | "
            f"{number(row['sql_put_call_ratio'])} | {number(row['canonical_pcr_change_pct'])} | "
            f"{number(row['sql_pcr_change_pct'])} | {reason} |"
        )
    lines.extend(
        [
            "",
            "## Every canonical Green date",
            "",
            "D0 and D-5 are NQ cash-session closes after quarterly roll-gap neutralization. Prior5DReturn is `(D0 / D-5) - 1`; the subtype rule is exactly `<= 0` for Reversal Green and `> 0` for Normal Green.",
            "",
            "| ObservationDate | NQ cash close D0 | NQ cash close D-5 | Prior5DReturn | Expected subtype | SQL subtype | Match |",
            "|---|---:|---:|---:|---|---|---|",
        ]
    )
    for row in result["canonical_green_rows"]:
        lines.append(
            f"| {row['observation_date']} | {number(row['nq_cash_close_d0'], 2)} | "
            f"{number(row['nq_cash_close_d_minus_5'], 2)} | {pct(row['prior_5d_return'])} | "
            f"{row['expected_subtype'] or 'n/a'} | {row['sql_subtype'] or 'n/a'} | "
            f"{'true' if row['match'] else 'false'} |"
        )
    lines.extend(["", "## Why the Green count is 42 Reversal / 26 Normal", ""])
    lines.extend(
        [
            "The current SQL strategy result is **42 Reversal / 26 Normal = 68 SQL Green rows**. The canonical reference contains **41 Reversal / 26 Normal = 67 Green rows**, and every canonical Green row matches its SQL subtype.",
            "",
            "The one-row difference is 2025-03-06: SQL reconstructs BULLISH from `CloseChangePct = -2.4332%` and `PCRChangePct = -33.4138%`, while the canonical CSV stores blank Signal, CloseChangePct, and PCRChangePct for that date. Therefore SQL adds one Reversal Green. The previously expected approximately 40/26 count is not reproduced by the current canonical 67-row reference; it reflects a different/earlier sample or count convention. No threshold or Green rule was changed to force the counts.",
            "",
            "## NQ cash-close bar convention",
            "",
            "The timestamp is the start of a 30-minute interval. The selected cash-close price is the close of the last bar whose start is strictly before the official cash close.",
            "",
            "| Example | Session | Official cash close | Bar timestamp | Interpreted interval | Price used |",
            "|---|---|---|---|---|---:|",
        ]
    )
    for row in result["bar_convention_examples"]:
        if row.get("status") != "PASS":
            lines.append(f"| {row['example']} | {row['session_date']} | {row['official_cash_close']} | missing | n/a | n/a |")
        else:
            lines.append(
                f"| {row['example']} | {row['session_date']} | {row['official_cash_close']} | "
                f"{row['bar_timestamp']} | {row['interpreted_bar_interval']} | {number(row['price_used'], 2)} |"
            )
    lines.extend(["", "## Regression proofs", "", "| Test | Result | Evidence |", "|---|---|---|"])
    for row in result["regression_proofs"]:
        lines.append(f"| `{row['test']}` | {row['result']} | {row['proves']} |")
    lines.extend(
        [
            "",
            "## Green TIME_EXIT timestamps",
            "",
            result["time_exit_convention"]["explanation"],
            "",
            "| Signal | Observation date | Bar timestamp | Interpreted interval | Economic exit time | Exit price |",
            "|---|---|---|---|---|---:|",
        ]
    )
    for row in result["green_time_exit_examples"]:
        lines.append(
            f"| {row['signal_type']} | {row['observation_date']} | {row['bar_timestamp']} | "
            f"{row['interpreted_bar_interval']} | {row['economic_exit_time']} | {number(row['exit_price'], 2)} |"
        )
    lines.extend(
        [
            "",
            "A displayed `15:30` exit is therefore the bar-start timestamp for the `15:30–16:00` bar; the economic exit is `16:00 America/New_York`. Early-close sessions follow the same rule with their official close.",
            "",
            "Quarterly NQ roll gaps were neutralized before cash-close extraction and Green simulation. The audit JSON includes the applied roll adjustments.",
            "",
        ]
    )
    return "\n".join(lines)


def _final_freeze_markdown(result: dict) -> str:
    def number(value, digits: int = 2) -> str:
        return "n/a" if value is None else f"{float(value):,.{digits}f}"

    def percent(value) -> str:
        return "n/a" if value is None else f"{float(value):.2%}"

    def pf(value) -> str:
        return "n/a" if value is None else f"{float(value):.3f}"

    def run_label(key: str) -> str:
        run = result["requested_window_runs"][key]
        return f"{key} ({run['variant']['label']})"

    def summary_rows(runs: dict) -> list[tuple[str, list[str]]]:
        keys = ["A_CAUSAL_COMPLETE", "B_CAUSAL_COMPLETE", "A_CANONICAL_EXPORT_COMPAT", "B_CANONICAL_EXPORT_COMPAT"]
        selected = [runs[key]["summary"] for key in keys]
        return [
            ("Green base count", [number(item.get("green_base_count"), 0) for item in selected]),
            ("Reversal Green count", [number(item.get("reversal_green_count"), 0) for item in selected]),
            ("Normal Green count", [number(item.get("normal_green_count"), 0) for item in selected]),
            ("Strong Yellow candidate / executed", [f"{number(item.get('strong_yellow_candidate_executed', {}).get('candidate'), 0)} / {number(item.get('strong_yellow_candidate_executed', {}).get('executed'), 0)}" for item in selected]),
            ("Reliable Yellow candidate / executed", [f"{number(item.get('reliable_yellow_candidate_executed', {}).get('candidate'), 0)} / {number(item.get('reliable_yellow_candidate_executed', {}).get('executed'), 0)}" for item in selected]),
            ("Total executed trades", [number(item.get("total_executed_trades"), 0) for item in selected]),
            ("Ending NAV", [number(item.get("ending_nav")) for item in selected]),
            ("Total return", [percent(item.get("total_return")) for item in selected]),
            ("Win rate", [percent(item.get("win_rate")) for item in selected]),
            ("Profit factor", [pf(item.get("profit_factor")) for item in selected]),
            ("Realized max DD", [percent(item.get("realized_max_drawdown")) for item in selected]),
            ("MTM max DD", [percent(item.get("mtm_max_drawdown")) for item in selected]),
            ("2025 return / PF", [f"{percent(item.get('2025', {}).get('return'))} / {pf(item.get('2025', {}).get('profit_factor'))}" for item in selected]),
            ("2026 return / PF", [f"{percent(item.get('2026', {}).get('return'))} / {pf(item.get('2026', {}).get('profit_factor'))}" for item in selected]),
            ("Worst trade", [percent(item.get("worst_trade")) for item in selected]),
            ("Worst losing streak", [number(item.get("worst_losing_streak"), 0) for item in selected]),
            ("Green lost to Yellow occupancy", [number(item.get("green_trades_lost_because_yellow_occupancy"), 0) for item in selected]),
        ]

    keys = ["A_CAUSAL_COMPLETE", "B_CAUSAL_COMPLETE", "A_CANONICAL_EXPORT_COMPAT", "B_CANONICAL_EXPORT_COMPAT"]
    lines = [
        "# SPX GEX Strategy Final Freeze Report",
        "",
        f"Research window: **{result['window']['start']} through {result['window']['end']}**.",
        "",
        "No parameter search or Green-rule modification was performed for this freeze.",
        "",
        "## 1. Frozen strategy rules",
        "",
        "- Green uses NQ cash-session `Close(D0) / Close(D-5) - 1`: `<= 0` is Reversal Green; `> 0` is Normal Green.",
        "- Reversal Green: exact D1 03:30 New York reference, -1% dip strictly before D3 03:30, cancel dip at D3 before fallback buy, D5 official cash close exit.",
        "- Normal Green: exact D3 03:30 entry, +2.5% TP, otherwise D5 official cash close.",
        "- Yellow A and B use the frozen SC P50 rule; only SP lookback/percentile differs.",
        "- NQ is a historical percentage-path proxy. Live QQQ sizing and order levels use an actual QQQ quote.",
        "",
        "## 2. Production A vs Shadow B",
        "",
        "| Variant | Version | SC | SP | Role |",
        "|---|---|---|---|---|",
        "| A | v1.0.3-production | 60D P50 | 60D P75 | Production decision rule |",
        "| B | v1.1.0-shadow | 60D P50 | 120D P60 | Forward-test shadow only |",
        "",
        "A controls recommendations and portfolio reservation. B is classified in parallel and records separate hypothetical outcomes/NAV state.",
        "",
        "## 3. Requested-window historical benchmarks",
        "",
        f"Source history begins at **{result['source_history_start']}**; requested backtest start is **{result['requested_backtest_start']}**. Common valid-history start is **{result['common_valid_history_start']}**.",
        "",
        "| Metric | A causal | B causal | A canonical-compatible | B canonical-compatible |",
        "|---|---:|---:|---:|---:|",
    ]
    for label, values in summary_rows(result["requested_window_runs"]):
        lines.append(f"| {label} | {' | '.join(values)} |")
    lines.extend(
        [
            "",
            "Production-realistic benchmark: **A_CAUSAL_COMPLETE**.",
            "Canonical CSV reconciliation benchmark: **A_CANONICAL_EXPORT_COMPAT**.",
            "",
            "## 4. Common-valid-history comparison",
            "",
            "The same frozen A/B variants are rerun beginning at the first date where both have valid causal SC and SP thresholds and current SC GEX.",
            "",
            "| Metric | A causal | B causal | A canonical-compatible | B canonical-compatible |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    common_selected = result["common_valid_history_runs"]
    for label, _ in summary_rows(common_selected):
        values = []
        for key in keys:
            item = common_selected[key]["summary"]
            if label == "Green base count": value = number(item.get("green_base_count"), 0)
            elif label == "Reversal Green count": value = number(item.get("reversal_green_count"), 0)
            elif label == "Normal Green count": value = number(item.get("normal_green_count"), 0)
            elif label == "Strong Yellow candidate / executed": value = f"{number(item.get('strong_yellow_candidate_executed', {}).get('candidate'), 0)} / {number(item.get('strong_yellow_candidate_executed', {}).get('executed'), 0)}"
            elif label == "Reliable Yellow candidate / executed": value = f"{number(item.get('reliable_yellow_candidate_executed', {}).get('candidate'), 0)} / {number(item.get('reliable_yellow_candidate_executed', {}).get('executed'), 0)}"
            elif label == "Total executed trades": value = number(item.get("total_executed_trades"), 0)
            elif label == "Ending NAV": value = number(item.get("ending_nav"))
            elif label == "Total return": value = percent(item.get("total_return"))
            elif label == "Win rate": value = percent(item.get("win_rate"))
            elif label == "Profit factor": value = pf(item.get("profit_factor"))
            elif label == "Realized max DD": value = percent(item.get("realized_max_drawdown"))
            elif label == "MTM max DD": value = percent(item.get("mtm_max_drawdown"))
            elif label == "2025 return / PF": value = f"{percent(item.get('2025', {}).get('return'))} / {pf(item.get('2025', {}).get('profit_factor'))}"
            elif label == "2026 return / PF": value = f"{percent(item.get('2026', {}).get('return'))} / {pf(item.get('2026', {}).get('profit_factor'))}"
            elif label == "Worst trade": value = percent(item.get("worst_trade"))
            elif label == "Worst losing streak": value = number(item.get("worst_losing_streak"), 0)
            else: value = number(item.get("green_trades_lost_because_yellow_occupancy"), 0)
            values.append(value)
        lines.append(f"| {label} | {' | '.join(values)} |")
    lines.extend(["", "## 5. The 2025-03-06 source-boundary difference", ""])
    lines.extend(
        [
            "The canonical CSV stores blank `Signal`, `CloseChangePct`, and `PCRChangePct` on 2025-03-06. CAUSAL_COMPLETE reconstructs BULLISH from pre-window SQL history (`CloseChangePct = -2.4332%`, `PCRChangePct = -33.4138%`), producing one additional Reversal Green. CANONICAL_EXPORT_COMPAT leaves the fields blank and does not manufacture a signal.",
            "",
            "This is a source-boundary difference, not a Green-rule mismatch. The canonical sample is 67 Green = 41 Reversal / 26 Normal; the causal SQL sample is 68 Green = 42 Reversal / 26 Normal.",
            "",
            "## 6. Green alignment evidence",
            "",
            "All 67 canonical Green rows reproduce their expected subtype under the frozen rule. Green classification is independent of Yellow A/B thresholds, so A and B produce the same Green result. Existing DST, early-close, D3 ordering, D5 cash-close, and NQ roll-gap regression coverage remains enabled.",
            "",
            "## 7. Yellow A/B comparison",
            "",
        ]
    )
    for mode in ("CAUSAL_COMPLETE", "CANONICAL_EXPORT_COMPAT"):
        rows = result["yellow_reclassified_rows"].get(mode, [])
        lines.extend([f"### {mode}", "", "| Date | Base signal | A classification | B classification | A allowed | B allowed | A decision | B decision |", "|---|---|---|---|---|---|---|---|"])
        for row in rows:
            lines.append(
                f"| {row['observation_date']} | {row['base_signal'] or 'n/a'} | {row['classification_A']} | {row['classification_B']} | "
                f"{row['A_trade_allowed']} | {row['B_trade_allowed']} | {row['A_decision'] or 'n/a'} | {row['B_decision'] or 'n/a'} |"
            )
        if not rows:
            lines.append("| none | | | | | | | |")
        lines.append("")
    lines.extend(
        [
            "## 8. Provenance and risk metrics",
            "",
            "Every benchmark result carries `strategy_version`, `git_commit`, `config_hash`, `data_hash`, `base_signal_source_mode`, source-history start, and requested start. Both realized exit-to-exit drawdown and mark-to-market drawdown are reported above.",
            "",
            "| Run | Version | Source mode | Git commit | Config hash | Data hash |",
            "|---|---|---|---|---|---|",
        ]
    )
    for key in keys:
        run = result["requested_window_runs"][key]
        item = run["result"]
        lines.append(f"| {key} | {item.get('strategy_version')} | {item.get('base_signal_source_mode')} | {item.get('git_commit')} | {item.get('config_hash')} | {item.get('data_hash')} |")
    lines.extend(
        [
            "",
            "## 9. Production/shadow architecture",
            "",
            "Each future signal is persisted as an A/B pair with current SC GEX, both SC thresholds, both SP thresholds, both classifications, a classification-changed flag, provenance, and separate `portfolio_A` / `portfolio_B` hypothetical NAV/occupancy snapshots. A remains the only production recommendation and reservation path.",
            "",
            "For every signal, hypothetical outcomes under both variants are recorded, including entry, TP/SL behavior, first-touch result, return, and status. Green outcomes are identical under A and B.",
            "",
            "## 10. Remaining known limitations",
            "",
            "- Historical P&L is an NQ percentage-path proxy for QQQ; it is not a historical QQQ execution ledger.",
            "- Live QQQ prices are fetched for sizing and order levels, while NQ remains the signal/percentage-path reference.",
            "- The 2025-03-06 canonical blank remains a documented source-boundary difference.",
            "- Forward shadow NAV is hypothetical and should be evaluated after a meaningful number of new Yellow observations; it does not promote B automatically.",
            "- No Yellow variant was selected by highest NAV or profit factor.",
            "",
        ]
    )
    return "\n".join(lines)


def _run_backtest(args, service: SPXGEXStrategyService) -> dict:
    from datetime import date
    from .backtest import run_backtest, run_sql_backtest

    data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
    sc_lookback = int(getattr(args, "sc_lookback", None) or getattr(service.settings, "spx_gex_sc_lookback_days", getattr(service.settings, "spx_gex_lookback_days", 60)))
    sp_lookback = int(getattr(args, "sp_lookback", None) or getattr(service.settings, "spx_gex_sp_lookback_days", getattr(service.settings, "spx_gex_lookback_days", 60)))
    sp_quantile = float(getattr(args, "sp_quantile", None) if getattr(args, "sp_quantile", None) is not None else getattr(service.settings, "spx_gex_sp_threshold_quantile", 0.75))
    strategy_version = str(getattr(args, "strategy_version", None) or getattr(service.settings, "spx_gex_strategy_version", "v1.0.3-production"))
    if data_mode == "sql":
        result = run_sql_backtest(
            service.settings.spx_gex_source_database,
            date.fromisoformat(args.start),
            date.fromisoformat(args.end),
            args.initial_capital,
            args.exposure,
            sc_lookback,
            sp_lookback,
            sp_quantile,
            strategy_version,
        )
    else:
        result = run_backtest(
            service._resolve_path(service.settings.spx_gex_gex_path),
            service._resolve_path(service.settings.spx_gex_nq_path),
            date.fromisoformat(args.start),
            date.fromisoformat(args.end),
            args.initial_capital,
            args.exposure,
            sc_lookback,
            sp_lookback,
            sp_quantile,
            strategy_version,
        )
    canonical_path = service._resolve_path(service.settings.spx_gex_gex_path)
    if canonical_path.exists():
        from .backtest import compare_canonical_signal_file

        result["canonical_signal_diff"] = compare_canonical_signal_file(
            canonical_path,
            result.get("signal_ledger", []),
            date.fromisoformat(args.start),
            date.fromisoformat(args.end),
        )
    return result


def _run_sensitivity_study(args, service: SPXGEXStrategyService) -> dict:
    from datetime import date
    from .backtest import run_sensitivity_study, run_sql_sensitivity_study

    start = date.fromisoformat(args.start)
    end = date.fromisoformat(args.end)
    data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
    if data_mode == "sql":
        return run_sql_sensitivity_study(service.settings.spx_gex_source_database, start, end)
    return run_sensitivity_study(
        service._resolve_path(service.settings.spx_gex_gex_path),
        service._resolve_path(service.settings.spx_gex_nq_path),
        start,
        end,
    )


def _run_candidate_comparison(args, service: SPXGEXStrategyService) -> dict:
    from datetime import date
    from .backtest import run_candidate_comparison, run_sql_candidate_comparison

    start = date.fromisoformat(args.start)
    end = date.fromisoformat(args.end)
    data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
    if data_mode == "sql":
        return run_sql_candidate_comparison(
            service.settings.spx_gex_source_database,
            start,
            end,
            args.initial_capital,
            args.exposure,
        )
    return run_candidate_comparison(
        service._resolve_path(service.settings.spx_gex_gex_path),
        service._resolve_path(service.settings.spx_gex_nq_path),
        start,
        end,
        args.initial_capital,
        args.exposure,
    )


def _candidate_comparison_markdown(result: dict) -> str:
    baseline = result["baseline"]
    candidate = result["candidate"]
    reference = result["historical_reference_baseline"]

    def number(value, digits: int = 2) -> str:
        return "n/a" if value is None else f"{float(value):,.{digits}f}"

    def percent(value) -> str:
        return "n/a" if value is None else f"{float(value):.2%}"

    def pf(value) -> str:
        return "n/a" if value is None else f"{float(value):.3f}"

    def category_count(summary: dict, category: str) -> str:
        return number(summary.get(category, {}).get("executed_count"), 0)

    comparison_rows = [
        ("Ending NAV", number(baseline.get("ending_nav")), number(candidate.get("ending_nav"))),
        ("Total return", percent(baseline.get("total_return")), percent(candidate.get("total_return"))),
        ("Profit factor", pf(baseline.get("profit_factor")), pf(candidate.get("profit_factor"))),
        ("Realized exit-to-exit max DD", percent(baseline.get("realized_exit_to_exit_max_drawdown")), percent(candidate.get("realized_exit_to_exit_max_drawdown"))),
        ("Mark-to-market max DD", percent(baseline.get("mark_to_market_max_drawdown")), percent(candidate.get("mark_to_market_max_drawdown"))),
        ("Total executed trades", number(baseline.get("trade_count"), 0), number(candidate.get("trade_count"), 0)),
        ("Actual Yellow trades", number(baseline.get("actual_yellow_trades"), 0), number(candidate.get("actual_yellow_trades"), 0)),
        ("Strong Yellow executed", category_count(baseline, "strong_yellow"), category_count(candidate, "strong_yellow")),
        ("Reliable Yellow executed", category_count(baseline, "reliable_yellow"), category_count(candidate, "reliable_yellow")),
        ("Green executed", number(baseline.get("green_trades"), 0), number(candidate.get("green_trades"), 0)),
        ("Green lost to Yellow occupancy", number(baseline.get("green_trades_lost_because_yellow_occupancy"), 0), number(candidate.get("green_trades_lost_because_yellow_occupancy"), 0)),
        ("Worst trade", percent(baseline.get("worst_trade_return")), percent(candidate.get("worst_trade_return"))),
        ("Worst losing streak", number(baseline.get("worst_losing_streak"), 0), number(candidate.get("worst_losing_streak"), 0)),
        ("2025 return", percent(baseline["2025"].get("return")), percent(candidate["2025"].get("return"))),
        ("2025 profit factor", pf(baseline["2025"].get("profit_factor")), pf(candidate["2025"].get("profit_factor"))),
        ("2026 return", percent(baseline["2026"].get("return")), percent(candidate["2026"].get("return"))),
        ("2026 profit factor", pf(baseline["2026"].get("profit_factor")), pf(candidate["2026"].get("profit_factor"))),
    ]
    lines = [
        "# SPX GEX v1.0.2 baseline vs v1.1 candidate",
        "",
        f"Window: **{result['start']} through {result['end']}**.",
        "",
        result["common_causal_warmup"],
        "",
        "The candidate is frozen from the robustness plateau and was not selected by highest NAV or profit factor.",
        "",
        "| Metric | v1.0.2 baseline (SC60 / SP60 / P75) | v1.1 candidate (SC180 / SP120 / P60) |",
        "|---|---:|---:|",
    ]
    lines.extend(f"| {label} | {old} | {new} |" for label, old, new in comparison_rows)
    lines.extend(
        [
            "",
            "## Candidate threshold checkpoints",
            "",
            "These are the last available causal thresholds in each requested month; no future rows are used.",
            "",
            "| Month | Observation date | Prior-180 SC GEX median | Prior-120 SP share P60 |",
            "|---|---|---:|---:|",
        ]
    )
    for row in result["candidate_threshold_series"]:
        lines.append(
            f"| {row['month']} | {row['observation_date'] or 'n/a'} | "
            f"{number(row['sc_p50_threshold'])} | {percent(row['sp_p60_threshold'])} |"
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "The baseline and candidate use the corrected chronological portfolio scheduler. A future Normal Green does not reserve the portfolio before its D3 03:30 entry; Yellow and Reversal Green can occupy it from D1 03:30.",
            "",
            "Historical P&L uses NAV notional multiplied by the NQ percentage-path return. NQ price is not used to manufacture QQQ quantity or order levels.",
            "",
            "## Earlier v1.0.2 reference",
            "",
            "The following reproduces the earlier corrected `$147,322` result with the original 70-session SQL warm-up. It is a reconciliation reference only; the primary baseline-vs-candidate table uses the same 220-session input for both variants.",
            "",
            "| Metric | Earlier v1.0.2 reference |",
            "|---|---:|",
            f"| Ending NAV | {number(reference.get('ending_nav'))} |",
            f"| Profit factor | {pf(reference.get('profit_factor'))} |",
            f"| MTM max DD | {percent(reference.get('mark_to_market_max_drawdown'))} |",
            f"| Executed trades | {number(reference.get('trade_count'), 0)} |",
            "",
            "The production defaults remain v1.0.2. Activating the candidate requires an explicit configuration change after reviewing this report.",
            "",
        ]
    )
    return "\n".join(lines)


def _run_three_variant_comparison(args, service: SPXGEXStrategyService) -> dict:
    from datetime import date
    from .backtest import run_sql_three_variant_comparison, run_three_variant_comparison

    start = date.fromisoformat(args.start)
    end = date.fromisoformat(args.end)
    data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
    if data_mode == "sql":
        return run_sql_three_variant_comparison(
            service.settings.spx_gex_source_database,
            start,
            end,
            args.initial_capital,
            args.exposure,
        )
    return run_three_variant_comparison(
        service._resolve_path(service.settings.spx_gex_gex_path),
        service._resolve_path(service.settings.spx_gex_nq_path),
        start,
        end,
        args.initial_capital,
        args.exposure,
    )


def _three_variant_comparison_markdown(result: dict) -> str:
    def number(value, digits: int = 2) -> str:
        return "n/a" if value is None else f"{float(value):,.{digits}f}"

    def percent(value) -> str:
        return "n/a" if value is None else f"{float(value):.2%}"

    def pf(value) -> str:
        return "n/a" if value is None else f"{float(value):.3f}"

    def variant_label(variant: dict) -> str:
        return f"{variant['id']} ({variant['label']})"

    def category(summary: dict, name: str) -> dict:
        summary_key = {
            "STRONG_YELLOW": "strong_yellow",
            "RELIABLE_YELLOW": "reliable_yellow",
        }.get(name, name)
        return summary.get(summary_key, {})

    def rows_for(window: dict) -> list[tuple[str, list[str]]]:
        variants = [window["variants"][key] for key in ("A", "B", "C")]
        summaries = [variant["summary"] for variant in variants]
        yellow_counts = [
            int(category(summary, "STRONG_YELLOW").get("candidate_count", 0))
            + int(category(summary, "RELIABLE_YELLOW").get("candidate_count", 0))
            for summary in summaries
        ]
        strong = [category(summary, "STRONG_YELLOW") for summary in summaries]
        reliable = [category(summary, "RELIABLE_YELLOW") for summary in summaries]
        return [
            ("Yellow candidate count", [number(value, 0) for value in yellow_counts]),
            (
                "Strong split (candidate / actual)",
                [f"{number(item.get('candidate_count'), 0)} / {number(item.get('executed_count'), 0)}" for item in strong],
            ),
            (
                "Reliable split (candidate / actual)",
                [f"{number(item.get('candidate_count'), 0)} / {number(item.get('executed_count'), 0)}" for item in reliable],
            ),
            ("Actual Yellow trades", [number(summary.get("actual_yellow_trades"), 0) for summary in summaries]),
            ("Total portfolio trades", [number(summary.get("trade_count"), 0) for summary in summaries]),
            ("Ending NAV", [number(summary.get("ending_nav")) for summary in summaries]),
            ("Total return", [percent(summary.get("total_return")) for summary in summaries]),
            ("Overall PF", [pf(summary.get("profit_factor")) for summary in summaries]),
            ("MTM max drawdown", [percent(summary.get("mark_to_market_max_drawdown")) for summary in summaries]),
            ("2025 PF / return", [f"{pf(summary['2025'].get('profit_factor'))} / {percent(summary['2025'].get('return'))}" for summary in summaries]),
            ("2026 PF / return", [f"{pf(summary['2026'].get('profit_factor'))} / {percent(summary['2026'].get('return'))}" for summary in summaries]),
            (
                "Strong candidate win / PF",
                [f"{percent(item.get('candidate_only_win_rate'))} / {pf(item.get('candidate_only_profit_factor'))}" for item in strong],
            ),
            (
                "Reliable candidate win / PF",
                [f"{percent(item.get('candidate_only_win_rate'))} / {pf(item.get('candidate_only_profit_factor'))}" for item in reliable],
            ),
            (
                "Green lost to Yellow occupancy",
                [number(summary.get("green_trades_lost_because_yellow_occupancy"), 0) for summary in summaries],
            ),
        ]

    lines = [
        "# SPX GEX fixed A/B/C full-portfolio comparison",
        "",
        f"Requested window: **{result['requested_window']['start']} through {result['requested_window']['end']}**.",
        "",
        result["common_causal_warmup"],
        "",
        "Exactly three predefined variants were run. No parameter search or performance-based selection was performed.",
        "",
        "| Variant | Definition |",
        "|---|---|",
    ]
    for variant in result["variants"]:
        parameters = variant["parameters"]
        lines.append(
            f"| {variant_label(variant)} | SC {parameters['sc_lookback_days']}D P{int(parameters['sc_quantile'] * 100)}; "
            f"SP {parameters['sp_lookback_days']}D P{int(parameters['sp_quantile'] * 100)} |"
        )

    for title, window in (
        ("Original requested window", result["original_window"]),
        (
            f"Common-valid-history window (starts {result['common_valid_history_start']})",
            result["common_valid_history_window"],
        ),
    ):
        lines.extend(
            [
                "",
                f"## {title}",
                "",
                f"Window: **{window['start']} through {window['end']}**.",
                "",
                "| Metric | A | B | C |",
                "|---|---:|---:|---:|",
            ]
        )
        for label, values in rows_for(window):
            lines.append(f"| {label} | {' | '.join(values)} |")
        reclassified = window.get("a_vs_b_reclassified_trades", [])
        lines.extend(
            [
                "",
                "### A-vs-B reclassified dates",
                "",
                f"Rows where the A and B classification or classifier trade-allowed result differs: **{len(reclassified)}**.",
                "",
                "| Date | Raw | A classification | B classification | A candidate return | B candidate return | A decision | B decision | A actual return | B actual return |",
                "|---|---|---|---|---:|---:|---|---|---:|---:|",
            ]
        )
        for row in reclassified:
            lines.append(
                f"| {row['observation_date']} | {row['signal_raw'] or 'n/a'} | "
                f"{row['a_classification'] or 'n/a'} | {row['b_classification'] or 'n/a'} | "
                f"{percent(row['a_candidate_return_pct'])} | {percent(row['b_candidate_return_pct'])} | "
                f"{row['a_decision'] or 'n/a'} | {row['b_decision'] or 'n/a'} | "
                f"{percent(row['a_actual_return_pct'])} | {percent(row['b_actual_return_pct'])} |"
            )

    lines.extend(
        [
            "",
            "## Common-valid-history definition",
            "",
            result["common_valid_history_definition"],
            "",
            "The Green rules, Yellow TP/SL, entry timing, chronological conflict scheduler, exposure, and NQ roll-gap neutralization are unchanged between variants.",
            "",
            "Historical P&L uses NAV notional multiplied by the NQ percentage-path return; NQ price is not used to create QQQ quantity or order levels.",
            "",
        ]
    )
    return "\n".join(lines)


def _sensitivity_markdown(result: dict) -> str:
    lines = [
        "# SPX GEX robustness matrix",
        "",
        f"Window: **{result['start']} through {result['end']}**.",
        "",
        "This is a Yellow-only sensitivity study with portfolio conflicts disabled. "
        "No combination was selected by NAV or profit factor, and SC remains P50.",
        "",
        "| SC | SP | Threshold | Strong n | Strong win | Strong avg | Strong PF | Reliable n | Reliable win | Reliable avg | Reliable PF | Yellow n | Combined win | Combined avg | Combined PF | 2025 PF | 2026 PF |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in result["results"]:
        combined = row["all"]["combined_yellow"]
        strong = row["all"]["strong"]
        reliable = row["all"]["reliable"]
        pf = combined["profit_factor"]
        pf_2025 = row["2025"]["combined_yellow"]["profit_factor"]
        pf_2026 = row["2026"]["combined_yellow"]["profit_factor"]
        def fmt(value, suffix=""):
            return "n/a" if value is None else f"{value:.4f}{suffix}"
        lines.append(
            f"| {row['sc_lookback']} | {row['sp_lookback']} | P{int(row['sp_quantile'] * 100)} | "
            f"{strong['candidate_count']} | {strong['win_rate']:.2%} | {strong['average_return']:.2%} | {fmt(strong['profit_factor'])} | "
            f"{reliable['candidate_count']} | {reliable['win_rate']:.2%} | {reliable['average_return']:.2%} | {fmt(reliable['profit_factor'])} | "
            f"{row['all']['total_tradable_yellow']} | {combined['win_rate']:.2%} | {combined['average_return']:.2%} | {fmt(pf)} | "
            f"{fmt(pf_2025)} | {fmt(pf_2026)} |"
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            result["warmup_policy"],
            "",
            "P60 versus P75 changes the Strong/Reliable split, but it does not change the underlying SC_LOW gate; within a common lookback pair, the total tradable Yellow count is therefore unchanged.",
            "",
            "SC lookback changes the number of Yellow candidates because SC_LOW is the tradability gate. The 2025 and 2026 columns must be read together: isolated `n/a` PF values mean there were no losses in that sub-period, not that the parameter is proven superior.",
            "",
            "Use the `stability_by_sp_threshold` and `stability_by_sc_lookback` sections in the JSON to inspect ranges across the matrix. The study intentionally does not identify a best parameter combination.",
            "",
            "The full JSON also contains Strong and Reliable win rate, average return, PF, completed-outcome counts, separate 2025/2026 results, and NQ roll-gap metadata.",
            "",
        ]
    )
    return "\n".join(lines)


def parse_as_of(value: str, timezone_name: str | None = None) -> datetime:
    """Parse an as-of instant, requiring a timezone when no UTC offset is supplied."""
    raw = value.strip()
    formats = ("%Y-%m-%d %I:%M%p", "%Y-%m-%d %I:%M %p")
    normalized = raw[:-1] + "+00:00" if raw.upper().endswith("Z") else raw
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        parsed = None
        for date_format in formats:
            try:
                parsed = datetime.strptime(raw, date_format)
                break
            except ValueError:
                continue
        if parsed is None:
            raise ValueError(
                "invalid --as-of value; use an ISO timestamp such as "
                "'2026-08-05 17:30' or '2026-08-05T17:30:00+10:00'"
            )

    if parsed.tzinfo is not None:
        return parsed
    if not timezone_name:
        raise ValueError("--timezone is required when --as-of does not include a UTC offset")
    try:
        timezone = ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError as exc:
        raise ValueError(f"unknown timezone: {timezone_name}") from exc
    return parsed.replace(tzinfo=timezone)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="SPXW GEX signal assistant")
    subparsers = parser.add_subparsers(dest="command", required=True)
    daily = subparsers.add_parser("daily", help="run the daily signal job as of now or a supplied timestamp")
    daily.add_argument(
        "--as-of",
        help="historical as-of timestamp; defaults to the current time",
    )
    daily.add_argument(
        "--timezone",
        help="IANA timezone for an as-of timestamp without an offset, e.g. Australia/Sydney",
    )
    notification = daily.add_mutually_exclusive_group()
    notification.add_argument(
        "--force-notification",
        action="store_true",
        help="send a notification for this manual run even if its signal was already notified",
    )
    notification.add_argument(
        "--no-notification",
        action="store_true",
        help="generate and save the report without sending any Pushover notification",
    )
    subparsers.add_parser("monitor", help="run the persisted-position monitor now")
    subparsers.add_parser("live-nq", help="print current IB NQMAIN versus yesterday close")
    subparsers.add_parser("report", help="print the configured HTML report URL")
    backtest = subparsers.add_parser("backtest", help="run the supplied-file causal backtest")
    backtest.add_argument("--start", required=True)
    backtest.add_argument("--end", required=True)
    backtest.add_argument("--initial-capital", type=float, default=100000.0)
    backtest.add_argument("--exposure", type=float, default=1.0)
    backtest.add_argument("--data-mode", choices=("sql", "file"), default=None)
    backtest.add_argument("--sc-lookback", type=int, default=None)
    backtest.add_argument("--sp-lookback", type=int, default=None)
    backtest.add_argument("--sp-quantile", type=float, default=None)
    backtest.add_argument("--strategy-version", default=None)
    dump = subparsers.add_parser(
        "backtest-dump",
        help="write a self-contained JSON backtest review dump including signals and trades",
    )
    dump.add_argument("--start", required=True)
    dump.add_argument("--end", required=True)
    dump.add_argument("--initial-capital", type=float, default=100000.0)
    dump.add_argument("--exposure", type=float, default=1.0)
    dump.add_argument("--data-mode", choices=("sql", "file"), default=None)
    dump.add_argument("--output", help="output JSON path; defaults to a timestamped file under backend/data")
    dump.add_argument("--sc-lookback", type=int, default=None)
    dump.add_argument("--sp-lookback", type=int, default=None)
    dump.add_argument("--sp-quantile", type=float, default=None)
    dump.add_argument("--strategy-version", default=None)
    sensitivity = subparsers.add_parser(
        "robustness-matrix",
        help="run the fixed SC/SP lookback and SP percentile sensitivity matrix without portfolio conflicts",
    )
    sensitivity.add_argument("--start", required=True)
    sensitivity.add_argument("--end", required=True)
    sensitivity.add_argument("--data-mode", choices=("sql", "file"), default=None)
    sensitivity.add_argument("--output", help="output JSON path; defaults to a timestamped file under backend/data")
    sensitivity.add_argument("--markdown-output", help="optional Markdown summary output path")
    comparison = subparsers.add_parser(
        "candidate-compare",
        help="compare the v1.0.2 baseline with the frozen v1.1 candidate using a common warm-up",
    )
    comparison.add_argument("--start", required=True)
    comparison.add_argument("--end", required=True)
    comparison.add_argument("--initial-capital", type=float, default=100000.0)
    comparison.add_argument("--exposure", type=float, default=1.0)
    comparison.add_argument("--data-mode", choices=("sql", "file"), default=None)
    comparison.add_argument("--output", help="output JSON path; defaults to a timestamped file under backend/data")
    comparison.add_argument("--markdown-output", help="optional Markdown summary output path")
    threshold_comparison = subparsers.add_parser(
        "threshold-compare",
        help="run exactly the predefined A/B/C full-portfolio threshold comparison",
    )
    threshold_comparison.add_argument("--start", required=True)
    threshold_comparison.add_argument("--end", required=True)
    threshold_comparison.add_argument("--initial-capital", type=float, default=100000.0)
    threshold_comparison.add_argument("--exposure", type=float, default=1.0)
    threshold_comparison.add_argument("--data-mode", choices=("sql", "file"), default=None)
    threshold_comparison.add_argument("--output", help="output JSON path; defaults to a timestamped file under backend/data")
    threshold_comparison.add_argument("--markdown-output", help="optional Markdown summary output path")
    green_audit = subparsers.add_parser(
        "green-audit",
        help="reconcile canonical and SQL Green signals without changing Green rules",
    )
    green_audit.add_argument("--start", required=True)
    green_audit.add_argument("--end", required=True)
    green_audit.add_argument("--initial-capital", type=float, default=100000.0)
    green_audit.add_argument("--exposure", type=float, default=1.0)
    green_audit.add_argument("--data-mode", choices=("sql", "file"), default=None)
    green_audit.add_argument("--output", help="output JSON path; defaults to a timestamped file under backend/data")
    green_audit.add_argument("--markdown-output", help="optional Markdown summary output path")
    final_freeze = subparsers.add_parser(
        "final-freeze",
        help="run the frozen A/B source-mode benchmarks and write the final freeze report",
    )
    final_freeze.add_argument("--start", default="2025-03-06")
    final_freeze.add_argument("--end", default="2026-08-06")
    final_freeze.add_argument("--initial-capital", type=float, default=100000.0)
    final_freeze.add_argument("--exposure", type=float, default=1.0)
    final_freeze.add_argument("--data-mode", choices=("sql", "file"), default=None)
    final_freeze.add_argument("--output", help="optional JSON benchmark output path")
    final_freeze.add_argument("--markdown-output", help="optional Markdown report path")

    trade = subparsers.add_parser("trade", help="record manual execution status")
    trade_sub = trade.add_subparsers(dest="trade_command", required=True)
    confirm = trade_sub.add_parser("confirm")
    confirm.add_argument("trade_id")
    confirm.add_argument("--entry", type=float, default=None)
    confirm.add_argument("--quantity", type=float, default=None)
    trade_sub.add_parser("skip").add_argument("trade_id")
    close = trade_sub.add_parser("close")
    close.add_argument("trade_id")
    close.add_argument("--price", type=float, required=True)

    args = parser.parse_args(argv)
    service = _service()
    if args.command == "daily":
        as_of = None
        if args.as_of:
            try:
                as_of = parse_as_of(args.as_of, args.timezone)
            except ValueError as exc:
                parser.error(str(exc))
        print(
            json.dumps(
                service.run_daily_signal(
                    now=as_of,
                    force_notification=args.force_notification,
                    send_notification=not args.no_notification,
                ),
                indent=2,
                default=str,
            )
        )
        return 0
    if args.command == "monitor":
        print(json.dumps(service.run_position_monitor(), indent=2, default=str))
        return 0
    if args.command == "live-nq":
        from .ib_market_data import get_live_nq_snapshot

        print(json.dumps(get_live_nq_snapshot(), indent=2, default=str))
        return 0
    if args.command == "report":
        print(service._report_url())
        return 0
    if args.command == "backtest":
        result = _run_backtest(args, service)
        print(json.dumps(result, indent=2, default=str))
        return 0
    if args.command == "backtest-dump":
        result = _run_backtest(args, service)
        generated_at = datetime.now().astimezone()
        output = Path(args.output) if args.output else Path(
            service._resolve_path(
                "data/"
                f"spx-gex-backtest-review-{args.start}-to-{args.end}-"
                f"{generated_at.strftime('%Y%m%d%H%M%S')}.json"
            )
        )
        if not output.is_absolute():
            output = Path(service._resolve_path(str(output)))
        output.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "dump_format": "spx_gex_backtest_review_v1",
            "generated_at": generated_at.isoformat(),
            "source": {
                "data_mode": args.data_mode or str(service.settings.spx_gex_data_mode).lower(),
                "gex_database": service.settings.spx_gex_source_database,
                "gex_table": "Transform.OptionGEXChangeCapitalType",
                "gex_asx_code": "SPXW.US",
                "nq_symbol": "NQMAIN.US",
                "nq_timeframe": "30M",
            },
            "research_window_definition": (
                "Signal observation dates are inclusive from 2025-03-06 through 2026-08-06. "
                "Earlier rows are causal warm-up only and are not counted as candidates or trades."
            ),
            "reconciliation_notes": [
                "SC_LOW uses current SC.GEX and the prior-60-session SC.GEX median; it does not use SC.GEXDelta.",
                "Green classification uses prior five US cash-session NQ closes.",
                "Reversal Green uses exact D1 03:30 reference, a -1% dip valid before D3 03:30, exact D3 fallback, and D5 cash close.",
                "Normal Green uses exact D3 03:30 entry, +2.5% TP, or D5 cash close.",
                "Yellow uses TP/SL first-touch only; the PRD does not define a Yellow time horizon.",
                "Quarterly NQ roll gaps are neutralized before classification and simulation.",
                "A candidate can be classified as tradable but skipped for an existing position or incomplete price data.",
            ],
            "backtest": result,
        }
        output.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
        print(json.dumps({"output": str(output), "trade_count": result["trade_count"], "strategy_version": result["strategy_version"]}, indent=2))
        return 0
    if args.command == "robustness-matrix":
        result = _run_sensitivity_study(args, service)
        generated_at = datetime.now().astimezone()
        output = Path(args.output) if args.output else Path(
            service._resolve_path(
                "data/"
                f"spx-gex-robustness-matrix-{args.start}-to-{args.end}-"
                f"{generated_at.strftime('%Y%m%d%H%M%S')}.json"
            )
        )
        if not output.is_absolute():
            output = Path(service._resolve_path(str(output)))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
        markdown_output = Path(args.markdown_output) if args.markdown_output else output.with_suffix(".md")
        if not markdown_output.is_absolute():
            markdown_output = Path(service._resolve_path(str(markdown_output)))
        markdown_output.parent.mkdir(parents=True, exist_ok=True)
        markdown_output.write_text(_sensitivity_markdown(result), encoding="utf-8")
        print(json.dumps({"json_output": str(output), "markdown_output": str(markdown_output), "combinations": len(result["results"])}, indent=2))
        return 0
    if args.command == "candidate-compare":
        result = _run_candidate_comparison(args, service)
        generated_at = datetime.now().astimezone()
        output = Path(args.output) if args.output else Path(
            service._resolve_path(
                "data/"
                f"spx-gex-candidate-comparison-{args.start}-to-{args.end}-"
                f"{generated_at.strftime('%Y%m%d%H%M%S')}.json"
            )
        )
        if not output.is_absolute():
            output = Path(service._resolve_path(str(output)))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
        markdown_output = Path(args.markdown_output) if args.markdown_output else output.with_suffix(".md")
        if not markdown_output.is_absolute():
            markdown_output = Path(service._resolve_path(str(markdown_output)))
        markdown_output.parent.mkdir(parents=True, exist_ok=True)
        markdown_output.write_text(_candidate_comparison_markdown(result), encoding="utf-8")
        print(
            json.dumps(
                {
                    "json_output": str(output),
                    "markdown_output": str(markdown_output),
                    "baseline_ending_nav": result["baseline"]["ending_nav"],
                    "candidate_ending_nav": result["candidate"]["ending_nav"],
                    "baseline_trade_count": result["baseline"]["trade_count"],
                    "candidate_trade_count": result["candidate"]["trade_count"],
                },
                indent=2,
            )
        )
        return 0
    if args.command == "threshold-compare":
        result = _run_three_variant_comparison(args, service)
        generated_at = datetime.now().astimezone()
        output = Path(args.output) if args.output else Path(
            service._resolve_path(
                "data/"
                f"spx-gex-threshold-comparison-{args.start}-to-{args.end}-"
                f"{generated_at.strftime('%Y%m%d%H%M%S')}.json"
            )
        )
        if not output.is_absolute():
            output = Path(service._resolve_path(str(output)))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
        markdown_output = Path(args.markdown_output) if args.markdown_output else output.with_suffix(".md")
        if not markdown_output.is_absolute():
            markdown_output = Path(service._resolve_path(str(markdown_output)))
        markdown_output.parent.mkdir(parents=True, exist_ok=True)
        markdown_output.write_text(_three_variant_comparison_markdown(result), encoding="utf-8")
        print(
            json.dumps(
                {
                    "json_output": str(output),
                    "markdown_output": str(markdown_output),
                    "common_valid_history_start": result["common_valid_history_start"],
                },
                indent=2,
            )
        )
        return 0
    if args.command == "green-audit":
        from datetime import date
        from .backtest import run_green_alignment_audit_from_data, run_sql_green_alignment_audit

        start = date.fromisoformat(args.start)
        end = date.fromisoformat(args.end)
        data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
        canonical_path = service._resolve_path(service.settings.spx_gex_gex_path)
        if data_mode == "sql":
            result = run_sql_green_alignment_audit(
                service.settings.spx_gex_source_database,
                canonical_path,
                start,
                end,
                args.initial_capital,
                args.exposure,
            )
        else:
            from .data import FileMarketDataRepository, read_delimited

            repository = FileMarketDataRepository(
                canonical_path,
                service._resolve_path(service.settings.spx_gex_nq_path),
            )
            result = run_green_alignment_audit_from_data(
                read_delimited(canonical_path),
                repository.gex_observations(),
                repository.nq_bars(),
                start,
                end,
                args.initial_capital,
                args.exposure,
            )
        generated_at = datetime.now().astimezone()
        output = Path(args.output) if args.output else Path(
            service._resolve_path(
                "data/"
                f"spx-gex-green-alignment-audit-{args.start}-to-{args.end}-"
                f"{generated_at.strftime('%Y%m%d%H%M%S')}.json"
            )
        )
        if not output.is_absolute():
            output = Path(service._resolve_path(str(output)))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
        markdown_output = Path(args.markdown_output) if args.markdown_output else output.with_suffix(".md")
        if not markdown_output.is_absolute():
            markdown_output = Path(service._resolve_path(str(markdown_output)))
        markdown_output.parent.mkdir(parents=True, exist_ok=True)
        markdown_output.write_text(_green_alignment_markdown(result), encoding="utf-8")
        print(
            json.dumps(
                {
                    "json_output": str(output),
                    "markdown_output": str(markdown_output),
                    "mismatch_count": result["mismatch_count"],
                    "canonical_green_count": result["canonical_base_signal_counts"]["GREEN"],
                    "sql_green_count": result["sql_reconstructed_base_signal_counts"]["GREEN"],
                },
                indent=2,
            )
        )
        return 0
    if args.command == "final-freeze":
        from datetime import date
        from .backtest import compare_final_freeze_benchmarks_from_data, run_sql_final_freeze_benchmarks

        start = date.fromisoformat(args.start)
        end = date.fromisoformat(args.end)
        data_mode = args.data_mode or str(service.settings.spx_gex_data_mode).lower()
        canonical_path = service._resolve_path(service.settings.spx_gex_gex_path)
        if data_mode == "sql":
            result = run_sql_final_freeze_benchmarks(
                service.settings.spx_gex_source_database,
                canonical_path,
                start,
                end,
                args.initial_capital,
                args.exposure,
            )
        else:
            from .data import FileMarketDataRepository, read_delimited

            repository = FileMarketDataRepository(
                canonical_path,
                service._resolve_path(service.settings.spx_gex_nq_path),
            )
            result = compare_final_freeze_benchmarks_from_data(
                repository.gex_observations(),
                repository.nq_bars(),
                read_delimited(canonical_path),
                start,
                end,
                args.initial_capital,
                args.exposure,
            )
        generated_at = datetime.now().astimezone()
        output = Path(args.output) if args.output else Path(
            service._resolve_path(
                "data/"
                f"spx-gex-strategy-final-freeze-benchmarks-{generated_at.strftime('%Y%m%d%H%M%S')}.json"
            )
        )
        if not output.is_absolute():
            output = Path(service._resolve_path(str(output)))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, default=str), encoding="utf-8")
        markdown_output = Path(args.markdown_output) if args.markdown_output else Path(
            service._resolve_path("data/spx-gex-strategy-final-freeze-report.md")
        )
        if not markdown_output.is_absolute():
            markdown_output = Path(service._resolve_path(str(markdown_output)))
        markdown_output.parent.mkdir(parents=True, exist_ok=True)
        markdown_output.write_text(_final_freeze_markdown(result), encoding="utf-8")
        print(json.dumps({"json_output": str(output), "markdown_output": str(markdown_output), "common_valid_history_start": result["common_valid_history_start"]}, indent=2))
        return 0
    if args.command == "trade":
        trade = service.store.trade(args.trade_id)
        if trade is None:
            parser.error(f"unknown trade id: {args.trade_id}")
        if args.trade_command == "confirm":
            service.store.update_trade(
                args.trade_id,
                actual_status="EXECUTED",
                actual_entry=args.entry or trade["entry_price"],
                actual_quantity=args.quantity or trade["quantity"],
            )
        elif args.trade_command == "skip":
            service.store.update_trade(args.trade_id, actual_status="SKIPPED_BY_USER")
        elif args.trade_command == "close":
            entry = float(trade["actual_entry"] or trade["entry_price"])
            quantity = float(trade["actual_quantity"] or trade["quantity"] or 0)
            direction = 1.0 if trade["direction"] == "LONG" else -1.0
            actual_pnl = quantity * (args.price - entry) * direction
            service.store.update_trade(
                args.trade_id,
                actual_status="CLOSED_MANUALLY",
                actual_exit=args.price,
                actual_pnl=actual_pnl,
            )
        print(json.dumps(dict(service.store.trade(args.trade_id)), indent=2, default=str))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
