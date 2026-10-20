# Improvement decisions — 2026-10-18

## Decisions made

### 1. Freeze candidate frequency at <=25%

**Adopt for the next shadow/research basket.** This is a pre-cutoff rule and is not retuned on September/October outcomes. It reduces the 58 packet archive to 40 packets.

The original 58-packet archive is unchanged. The frequency-capped archive is:

`../selected_gex_frequency_capped_contracts_2026-10-18`

It has passed offline descriptor validation and has not been provisioned or activated.

### 2. Prefer D5 in the next research selection

**Adopt as a research preference, not an immediate contract rewrite.** On the frequency-capped August signal population:

| Exit | PF | Mean return | Final research-tail PF |
|---|---:|---:|---:|
| D1 | 1.46 | 0.22% | 0.99 |
| D3 | 2.28 | 1.45% | 1.43 |
| D5 | 3.22 | 2.73% | 1.98 |

D5 has the strongest chronological evidence. D1 should require additional justification. This does not override the current OOS result; exit changes must be tested on a new untouched window.

### 3. Add signal-strength tiers

**Adopt as notification confidence tiers, not as a hard live filter yet.** A fixed minimum strength of 0.05 improved the August final-tail PF from 1.92 to 2.03 while retaining 160 observations. Strength >=0.20 produced PF 3.02, but only 34 final-tail observations, so it is too small for promotion.

Use strength to prioritize review and paper plans first. Do not remove weaker signals until another forward period confirms the benefit.

### 4. Test a weak-market regime gate

**Keep as a research candidate only.** `QQQ_GEX_ZScore_60day < 0` and `SPY_GEX_ZScore_60day < 0` were the strongest broad partitions in the August research tail (PF 2.45 and 2.33 respectively). The opposite QQQ trend partition was nearly flat in the tail (PF 1.03).

This is promising, but it must be tested with direction/sector interactions and a new unseen period before becoming a production predicate.

### 5. Portfolio controls

**Adopt for portfolio simulation.** Daily signal caps and strength ranking should be evaluated with correlation, sector, leveraged-ETF, and direction limits. The current daily-cap file is only a diagnostic because daily averaging can hide overlapping D5 exposure.

No live contract should be enabled based on the current cap table alone.

### 6. Costs and slippage

**Adopt immediately in all future research.** The capped basket remains positive at 50 bps round-trip, but the edge compresses materially. Future results should use ticker-specific spread/slippage assumptions, especially for leveraged ETFs and less liquid names.

### 7. Trailing and MAE exits

**Do not infer them from daily returns.** A proper test requires point-in-time 30-minute path replay, conservative intrabar stop ordering, and a prior-volatility estimate. This is the next implementation task rather than a rule to add now.

### 8. Weak-symbol review and source coverage

**Do not retire symbols based on the current OOS period.** AMD, MU, SPY, META, MRVL, and XOM remain review candidates only.

The historical replay still reports source-readiness gaps for COHR, IGV, MOD, S, SPXU, plus partial SNDK/TXN coverage. These must be diagnosed and fixed before using coverage-sensitive conclusions.

## Artifacts

- `exit-comparison.csv`
- `regime-filter-comparison.csv`
- `signal-strength-comparison.csv`
- `portfolio-cap-comparison.csv`
- `cost-sensitivity.csv`
- `frequency-capped-signals.csv`
- `../selected_gex_frequency_capped_contracts_2026-10-18/`

All artifacts use the August 31, 2026 cutoff. September and October 2026 remain reserved for forward validation.
