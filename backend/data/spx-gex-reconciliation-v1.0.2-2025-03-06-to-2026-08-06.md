# SPX GEX v1.0.2 reconciliation

Research window: **2025-03-06 through 2026-08-06**, inclusive. No strategy thresholds or D1/D3/D5 timing rules were changed.

The complete signal ledger, blocker evidence, Yellow audit, canonical diff, trades, roll adjustments, and mark-to-market calculations are in the [full JSON audit](spx-gex-reconciliation-v1.0.2-2025-03-06-to-2026-08-06.json).

## Portfolio result

- Executed trades: **56**
- Ending NAV: **$147,322.09**
- Overall profit factor: **2.5712**
- Realized exit-to-exit max drawdown: **6.6425%**
- Mark-to-market max drawdown: **15.9244%**
- NQ roll gaps neutralized: **yes**
- Historical quantity: **null**; NQ is only a percentage-path proxy for QQQ and P&L uses `NAV × exposure_factor × return_pct`.

## Reconciliation by classification

| Classification | Candidates | Candidate-only win / avg / PF | Executed | Executed win / avg / PF | Skipped | Hypothetical skipped win / avg / PF |
|---|---:|---|---:|---|---:|---|
| Strong Yellow | 8 | 87.50% / 0.63% / 6.0138 | 5 | 100.00% / 0.80% / n/a | 3 | 66.67% / 0.34% / 2.0138 |
| Reliable Yellow | 17 | 88.24% / 0.26% / 3.7500 | 10 | 90.00% / 0.28% / 4.5000 | 7 | 85.71% / 0.23% / 3.0000 |
| Reversal Green | 42 | 78.57% / 1.46% / 4.1355 | 24 | 70.83% / 0.90% / 2.3304 | 18 | 88.89% / 2.21% / 12.9138 |
| Normal Green | 26 | 72.00% / 0.51% / 2.1701 | 17 | 76.47% / 0.68% / 2.4936 | 8 | 62.50% / 0.15% / 1.3734 |

Candidate-only and hypothetical-skipped metrics use completed hypothetical outcomes; their denominators are recorded in the JSON (`candidate_outcome_count` and `hypothetical_skipped_outcome_count`).

## Scheduling audit

- Corrected action-time scheduler conflicts: **36**.
- Legacy observation-date scheduler signals incorrectly blocked by a future Normal Green: **3**.
- Corrected scheduler signals incorrectly blocked by a future Normal Green: **0**.
- Every corrected existing-position skip includes intended entry, blocker signal/date, blocker entry, blocker exit, and blocker state at the skip timestamp in the JSON ledger.
- Reversal Green reserves from D1 because its dip order is active. Normal Green reserves only at D3 03:30 and is rechecked then.

## Yellow audit

All 15 executed Yellow trades are listed in `yellow_audit` in the JSON with D1 entry, D2 cash close, actual exit, exit reason, and `exit_after_D2`. No Yellow D2 time exit was added; TP/SL-only behavior remains in force.

## Canonical signal diff

The canonical CSV contains **67 Green** signals; the SQL reconstruction contains **68**. The JSON lists all 7 broad-class mismatches in the window, including the 2025-03-06 SQL Green versus canonical blank signal and the six dates where the SQL reconstruction has insufficient history while the canonical file has a Yellow signal.

