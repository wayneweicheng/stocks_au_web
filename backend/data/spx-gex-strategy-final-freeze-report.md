# SPX GEX Strategy Final Freeze Report

Research window: **2025-03-06 through 2026-08-06**.

No parameter search or Green-rule modification was performed for this freeze.

## 1. Frozen strategy rules

- Green uses NQ cash-session `Close(D0) / Close(D-5) - 1`: `<= 0` is Reversal Green; `> 0` is Normal Green.
- Reversal Green: exact D1 03:30 New York reference, -1% dip strictly before D3 03:30, cancel dip at D3 before fallback buy, D5 official cash close exit.
- Normal Green: exact D3 03:30 entry, +2.5% TP, otherwise D5 official cash close.
- Yellow A and B use the frozen SC P50 rule; only SP lookback/percentile differs.
- NQ is a historical percentage-path proxy. Live QQQ sizing and order levels use an actual QQQ quote.

## 2. Production A vs Shadow B

| Variant | Version | SC | SP | Role |
|---|---|---|---|---|
| A | v1.0.3-production | 60D P50 | 60D P75 | Production decision rule |
| B | v1.1.0-shadow | 60D P50 | 120D P60 | Forward-test shadow only |

A controls recommendations and portfolio reservation. B is classified in parallel and records separate hypothetical outcomes/NAV state.

## 3. Requested-window historical benchmarks

Source history begins at **2024-04-19**; requested backtest start is **2025-03-06**. Common valid-history start is **2024-10-15**.

| Metric | A causal | B causal | A canonical-compatible | B canonical-compatible |
|---|---:|---:|---:|---:|
| Green base count | 68 | 68 | 67 | 67 |
| Reversal Green count | 42 | 42 | 41 | 41 |
| Normal Green count | 26 | 26 | 26 | 26 |
| Strong Yellow candidate / executed | 10 / 6 | 15 / 8 | 10 / 6 | 15 / 8 |
| Reliable Yellow candidate / executed | 21 / 13 | 16 / 11 | 21 / 14 | 16 / 12 |
| Total executed trades | 59 | 59 | 59 | 59 |
| Ending NAV | 156,341.09 | 157,589.32 | 166,052.58 | 167,378.35 |
| Total return | 56.34% | 57.59% | 66.05% | 67.38% |
| Win rate | 79.66% | 79.66% | 83.05% | 83.05% |
| Profit factor | 3.067 | 3.100 | 3.686 | 3.721 |
| Realized max DD | 6.08% | 6.08% | 6.08% | 6.08% |
| MTM max DD | 11.51% | 11.51% | 11.51% | 11.51% |
| 2025 return / PF | 36.61% / 5.011 | 37.16% / 5.063 | 45.10% / 9.456 | 45.68% / 9.536 |
| 2026 return / PF | 14.44% / 2.088 | 14.90% / 2.118 | 14.44% / 2.088 | 14.90% / 2.118 |
| Worst trade | -4.21% | -4.21% | -4.21% | -4.21% |
| Worst losing streak | 3 | 3 | 3 | 3 |
| Green lost to Yellow occupancy | 3 | 3 | 3 | 3 |

Production-realistic benchmark: **A_CAUSAL_COMPLETE**.
Canonical CSV reconciliation benchmark: **A_CANONICAL_EXPORT_COMPAT**.

## 4. Common-valid-history comparison

The same frozen A/B variants are rerun beginning at the first date where both have valid causal SC and SP thresholds and current SC GEX.

| Metric | A causal | B causal | A canonical-compatible | B canonical-compatible |
|---|---:|---:|---:|---:|
| Green base count | 78 | 78 | 77 | 77 |
| Reversal Green count | 46 | 46 | 45 | 45 |
| Normal Green count | 32 | 32 | 32 | 32 |
| Strong Yellow candidate / executed | 13 / 8 | 20 / 11 | 13 / 8 | 20 / 11 |
| Reliable Yellow candidate / executed | 27 / 17 | 20 / 14 | 27 / 18 | 20 / 15 |
| Total executed trades | 70 | 70 | 70 | 70 |
| Ending NAV | 166,900.17 | 167,893.52 | 177,267.56 | 178,322.62 |
| Total return | 66.90% | 67.89% | 77.27% | 78.32% |
| Win rate | 75.71% | 75.71% | 78.57% | 78.57% |
| Profit factor | 3.043 | 3.052 | 3.584 | 3.589 |
| Realized max DD | 6.08% | 6.08% | 6.08% | 6.08% |
| MTM max DD | 11.94% | 11.94% | 11.51% | 11.51% |
| 2025 return / PF | 38.07% / 5.127 | 38.62% / 5.179 | 46.65% / 9.654 | 47.23% / 9.734 |
| 2026 return / PF | 14.44% / 2.088 | 14.90% / 2.118 | 14.44% / 2.088 | 14.90% / 2.118 |
| Worst trade | -4.21% | -4.21% | -4.21% | -4.21% |
| Worst losing streak | 3 | 3 | 3 | 3 |
| Green lost to Yellow occupancy | 5 | 5 | 5 | 5 |

## 5. The 2025-03-06 source-boundary difference

The canonical CSV stores blank `Signal`, `CloseChangePct`, and `PCRChangePct` on 2025-03-06. CAUSAL_COMPLETE reconstructs BULLISH from pre-window SQL history (`CloseChangePct = -2.4332%`, `PCRChangePct = -33.4138%`), producing one additional Reversal Green. CANONICAL_EXPORT_COMPAT leaves the fields blank and does not manufacture a signal.

This is a source-boundary difference, not a Green-rule mismatch. The canonical sample is 67 Green = 41 Reversal / 26 Normal; the causal SQL sample is 68 Green = 42 Reversal / 26 Normal.

## 6. Green alignment evidence

All 67 canonical Green rows reproduce their expected subtype under the frozen rule. Green classification is independent of Yellow A/B thresholds, so A and B produce the same Green result. Existing DST, early-close, D3 ordering, D5 cash-close, and NQ roll-gap regression coverage remains enabled.

## 7. Yellow A/B comparison

### CAUSAL_COMPLETE

| Date | Base signal | A classification | B classification | A allowed | B allowed | A decision | B decision |
|---|---|---|---|---|---|---|---|
| 2025-05-12 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2025-06-04 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2025-11-03 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | TRADED | TRADED |
| 2025-11-10 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2025-11-12 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2026-01-12 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | TRADED | TRADED |
| 2026-02-18 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | SKIPPED_EXISTING_POSITION | SKIPPED_EXISTING_POSITION |
| 2026-03-17 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | SKIPPED_EXISTING_POSITION | SKIPPED_EXISTING_POSITION |
| 2026-03-25 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | SKIPPED_EXISTING_POSITION | SKIPPED_EXISTING_POSITION |

### CANONICAL_EXPORT_COMPAT

| Date | Base signal | A classification | B classification | A allowed | B allowed | A decision | B decision |
|---|---|---|---|---|---|---|---|
| 2025-05-12 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2025-06-04 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2025-11-03 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | TRADED | TRADED |
| 2025-11-10 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2025-11-12 | BEARISH | WEAK_YELLOW | MIXED_YELLOW | False | False | NON_TRADABLE_CLASSIFICATION | NON_TRADABLE_CLASSIFICATION |
| 2026-01-12 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | TRADED | TRADED |
| 2026-02-18 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | SKIPPED_EXISTING_POSITION | SKIPPED_EXISTING_POSITION |
| 2026-03-17 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | SKIPPED_EXISTING_POSITION | SKIPPED_EXISTING_POSITION |
| 2026-03-25 | BEARISH | RELIABLE_YELLOW | STRONG_YELLOW | True | True | SKIPPED_EXISTING_POSITION | SKIPPED_EXISTING_POSITION |

## 8. Provenance and risk metrics

Every benchmark result carries `strategy_version`, `git_commit`, `config_hash`, `data_hash`, `base_signal_source_mode`, source-history start, and requested start. Both realized exit-to-exit drawdown and mark-to-market drawdown are reported above.

| Run | Version | Source mode | Git commit | Config hash | Data hash |
|---|---|---|---|---|---|
| A_CAUSAL_COMPLETE | v1.0.3-production | CAUSAL_COMPLETE | 5326ecd9e059103c486844d8e1e43f22e96f7f6e | 7fc548df1cc9ebefb6542036776f0ba8524a2bae14aa78a155b54dd7a13a4ce5 | 1e58e741e5de997946c7af6a9d69011fa8fddba67b25082e4c687d6a9e248800 |
| B_CAUSAL_COMPLETE | v1.1.0-shadow | CAUSAL_COMPLETE | 5326ecd9e059103c486844d8e1e43f22e96f7f6e | 1afaaa21ffa9a674f4a38c0174bfe51ca23a95e1805ac8024745f4ebf2d4a35c | 1e58e741e5de997946c7af6a9d69011fa8fddba67b25082e4c687d6a9e248800 |
| A_CANONICAL_EXPORT_COMPAT | v1.0.3-production | CANONICAL_EXPORT_COMPAT | 5326ecd9e059103c486844d8e1e43f22e96f7f6e | 837c2a89db153b6d2e14a6f2b9dbf7857221308c4de68f7a45867ba73e0b924c | 5dbb675426ce624996c568ee2b7e742762a13137c97403c58b1875b5d0eb7d6b |
| B_CANONICAL_EXPORT_COMPAT | v1.1.0-shadow | CANONICAL_EXPORT_COMPAT | 5326ecd9e059103c486844d8e1e43f22e96f7f6e | a98a83c1fd3d0afe23047b1435ec2e838cc2000c2ddf07386169fdee360755dd | 5dbb675426ce624996c568ee2b7e742762a13137c97403c58b1875b5d0eb7d6b |

## 9. Production/shadow architecture

Each future signal is persisted as an A/B pair with current SC GEX, both SC thresholds, both SP thresholds, both classifications, a classification-changed flag, provenance, and separate `portfolio_A` / `portfolio_B` hypothetical NAV/occupancy snapshots. A remains the only production recommendation and reservation path.

For every signal, hypothetical outcomes under both variants are recorded, including entry, TP/SL behavior, first-touch result, return, and status. Green outcomes are identical under A and B.

## 10. Remaining known limitations

- Historical P&L is an NQ percentage-path proxy for QQQ; it is not a historical QQQ execution ledger.
- Live QQQ prices are fetched for sizing and order levels, while NQ remains the signal/percentage-path reference.
- The 2025-03-06 canonical blank remains a documented source-boundary difference.
- Forward shadow NAV is hypothetical and should be evaluated after a meaningful number of new Yellow observations; it does not promote B automatically.
- No Yellow variant was selected by highest NAV or profit factor.
