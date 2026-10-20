# Independent AI review brief — US stock strategy discovery

**As of:** 2026-10-18 research snapshot. **Purpose:** obtain an independent critique and a defensible next research plan. This document reports what was actually measured, what is only a hypothesis, and what is currently unsafe. It is **not** a request to provision, trade, retune on the examined September–October period, or modify SQL.

## Executive answer to the 92-versus-40 question

**No: we have not established that the other 52 instruments are useless or that they lack reliable strategies.** The number 52 is `92 − 40`, but the repository does **not** yet contain a verified, point-in-time list of 92 executable *stocks* matching that definition. The reproducible August `Analysis.GEX_Features` universe contains **90 symbols after excluding `_VIX.US`**, and includes **SPXW.US**, an option root/context instrument, not an ordinary executable stock. The August query originally returned 91 including `_VIX.US`; a separate SPX.US context symbol also has 30-minute price history. Adding SPX.US and `_VIX.US` to the 90 happens to make 92, but **do not assume this is the user's intended 92** without receiving and reconciling their authoritative list. [U1, U2, U3]

Among the **90 August symbols**, **87** have corrected eligible 07:30-entry labels. The frozen 40 are a subset; therefore **47 other symbols have corrected labels**, while **C.US, CAT.US and SPXW.US** have no eligible labels under that exact convention. Of the 47, **20** have *at least one* candidate from a limited corrected GEX rule search and **27** have none under those searched rules/eligibility criteria. “No candidate” is **not** “no possible strategy.” Only 18 of the 47 had been among the *older* 58 selected ticker set; the 40 were retained using a historically measured `frequency_pct ≤25%` cap whose apparent advantage was noticed after looking at the September–October period. After correction, BAC, COST and PLTR no longer even satisfy that cap, but were retained to keep the comparator frozen. [U1, U2, U4, P5]

The wider database supports substantial research beyond that GEX search; however, option-only/technical-only results so far were tested on the **87-symbol label intersection**, not on the entire quote universe. The 47 were **not subjected to a fair, full multi-source, runtime-parity, nested walk-forward, portfolio-cost candidate search**. The previous 40 *did* fail a corrected retrospective September–October aggregate test; that result cannot be extrapolated to the remaining 47. [D1, S1, P5, P6]

## 1. Application, repositories, data sources and coverage

The application is a Next.js frontend and FastAPI backend using `StockDB_US` (SQL Server). Strategy source loading, descriptor validation, calendar, feature calculation, provisioning and outcome processing live separately under `C:/Repo/stocks_collecting/src/strategy_runtime/`; research scripts and artifacts are in this web repository. SQL research queries were read-only. Historical archive discovery in the collecting runtime recursively scans unpacked `strategy.descriptor.json` files below `backend/data/strategy_runtime`; research review packs must remain ZIP-only there to avoid accidental registry conflicts. [A1, P5]

An October 2026 metadata inventory identified **419 StockDB_US tables/views and 6,859 columns**. Approximate row counts in the map below are metadata estimates, not audited usable as-of history or proven predictor quality. Do **not** infer causal availability from a table name or count. [D1]

| Family / purpose | Concrete source(s) | What has actually been used or checked |
|---|---|---|
| GEX and capital classifications | `Analysis.GEX_Features`; `Transform.OptionGEXChangeCapitalType` with BC/BP/SC/SP rows | Current frozen rules use GEX, historical ranks, z-scores, capital shares/changes and some price context. SQL source requires complete four-capital-type D0/prior history. Rough inventory: ~245k GEX-feature and ~2.38m capital-type rows. Runtime/source parity problems were found and separately corrected in the *research* replay. [D1, C1, P5] |
| Stock/ETF execution bars | `StockData.PriceHistoryTimeFrame` (`30M`), `StockData.PriceHistory` (daily) | Exact subject-specific D1 07:30 ET 30M opens and scheduled D1/D3/D5 close bars underpin the corrected labels; 30M source ~6.68m table rows in the old inventory. Daily source supported causal technical indicators for 156 symbols/63,056 rows. An indexed 30M coverage profile contained 90 symbols including context instruments, only 42 with ≥120 observation dates. [D1, P2, P3, P4] |
| Delayed option chain | `StockData.OptionDelayedQuote_V2` | Approximately 97.7m rows in the old inventory. Through **2026-08-31**, 956 roots have records, 145 have ≥120 quote observation dates, 133 ≥180 and only 7 ≥208; 180 roots were processed into 30,533 valid US-session daily feature rows. Summaries include put/call volume/OI, IV, Greeks, DTE shares, bid/ask spread and prior-only ranks. User operating assumption: D0 delayed quotes ready on D1 about **07:00 America/New_York**, before a 07:30 decision; actual first-ready/revisions not proven. 494 non-session symbol/date records were excluded; SPXW duplicate contracts on a non-session date require investigation. This is information for **underlying** trades, not an option execution model. [D1, P2, P3, S1] |
| Option trades, flow, exposures and walls | `StockData.OptionTrade`, `SignificantOptionTrade`, `Analysis.OptionTradeSideInference`, `Transform.OptionFlowContractDaily`, `OptionFlowTradeDaily`, `OptionDEXByPutCall`, `OptionGEXByPutCall`, `OptionNetExposureAggregate`; inspect gamma-wall and OI views | Inventoried as possible sources; their point-in-time semantics, historic coverage, signed-premium/side confidence, wall creation and contribution to executable edge **have not been adequately tested in this programme**. Old inventory estimates ~255m raw option-trade rows and ~0.91m significant trades. Avoid treating absolute Greek magnitudes as signed dealer inventory. [D1, H1] |
| Market, sector, volatility, breadth, flows | `UnderlyingVolatilityHistory`, `RelativePriceStrength`, ETF/money-flow, breadth/CLV tables; SPY/QQQ/VIX context | Some VIX/QQQ conditions and lagged price context have been screened; broader sector/breadth/flow joins, source timing, historical membership and incremental tests are **not complete**. [D1, H1, S1] |
| Events/fundamentals/derived scores | `CompanyInfo`, announcements, recommendations, signal tables | Schema/inventory only for most. Many objects have sparse/zero historic rows or current/revised/future-labeled semantics. Do not ingest future labels or operational outcomes as predictors. [D1, H1] |

### Coverage is not eligibility

- August GEX-universe extract: **90** symbols after `_VIX.US` removal; 88 had some 30M bars, **87** had at least one corrected exact-entry/resolved-label candidate row; C.US, CAT.US and SPXW.US have no corrected eligible labeled row. Counts depend on the August observation window and specified trade convention. [U1, U2]
- Corrected panel: **10,591 D0 symbol/date rows across 87 symbols**, D1 10,591 resolved, D3 10,422, D5 10,250, all exits at/before 2026-08-31. All entries and resolved returns independently matched raw subject bars to floating-point tolerance. This does **not** independently verify feature publication/availability, premarket fills or old candidate selection. [P2]
- Only **55/145** long-quote-history symbols had *any* profiled 30M price history and **42** had ≥120 30M dates. The only long-quote 30M names outside the 87-symbol equity-label universe were **SPX.US, SPXW.US and `_VIX.US`**, all context/nonstandard executions. A full 145-symbol underlying 07:30 strategy test cannot be claimed from the existing price source; a broader **09:30/daily-open** experiment must be separately defined and audited, with different fills/benchmark and point-in-time source joins. [P4]
- The other 47 eligible tickers have **3,310 corrected D0 symbol/date rows altogether**, unevenly distributed (22–214 dates/ticker; median 51). The raw number of quote days is not equivalent to 60 complete BC/BP/SC/SP history days, exact D1 bars, usable IV, or resolved returns. [U1, U2]

## 2. How strategies have been discovered and tested — not an ML training result

There has **not** been a comprehensive trained ML model, nested multi-fold selection over all 92, sector-held-out confirmation, or a complete marked-to-market portfolio test. The original effort enumerated thousands of hand-written GEX rule/horizon/direction combinations, ranked per ticker on pre-cutoff historical returns using relatively small chronological signal-count splits, and kept one best row per ticker. That yielded an older 58-ticker selected set; a later 40-ticker frequency-capped subset was retained as a **frozen comparator**, not an optimally proven basket. Corrected-source discovery contains **3,078 exploratory GEX candidate rows and 60 candidate tickers**, not 60 independently validated strategies; of those candidate tickers 20 are outside the frozen 40. No absence-of-alpha theorem follows for the other 27 label-supported symbols. [U2, U4, P5]

**Causal label/feature clock:** a completed US D0 GEX/price observation forms the signal; delayed D0 quotes, when used, are *assumed* ready on D1 about 07:00 ET; evaluate at D1 07:30 ET; price entry is the **open of the 07:30 30M bar**, which may already have occurred by evaluation (optimistic proxy). Fixed exits use XNYS scheduled D1/D3/D5 regular close, with holidays/DST/half-days and exact required bars. A completed D1 opening range or D1 daily volume cannot be used at 07:30. Missing bars and cutoff-crossing labels are not silently rolled forward or called zero. Source SQL `TimeIntervalStart` is **New York wall time**, not UTC; the old research misread it, shifting entry bars roughly four hours. [P1, P2, P4, P6, C1]

**Technical/option exploratory screens:** a research-only causal daily panel built SMA/EMA, ATR/realised volatility, RSI, MACD, Bollinger **location and bandwidth separately**, prior support/resistance/weekly/monthly pivots, confirmed rather than backdated swings, relative volume and option-quote aggregates. A first fixed-threshold screen registered **62 conditions**: 30 technical, 20 option, 8 combined, 4 market-context; D1/D3/D5 with 0/10/25/50-bp round-trip sensitivities, chronologically split globally into train (before Apr 23), validation (Apr 23–Jun 29) and a final **already-inspected** Jun 30–Aug 28 research tail. Labels crossing splits were purged. It did **not** run nested outer folds or properly correct selection uncertainty across families. The first combined-screen run had an availability bug that scored eight composite conditions as zero; `fixed_hypothesis_screen_v2/` is the corrected output, and none qualifies for promotion. [S1, P3, P4]

**Runtime parity matters:** the old candidate generator's historical feature ranks used different warm-up/rolling eligibility from the live feature implementation. An initial price-corrected 40-pack had **458/1,298 mismatched feature/trigger rows** plus one incomplete source day when compared to the current runtime path. A second review-only 40 pack recomputed the same frozen 40 rule identities with the runtime implementation on D0 + 60 prior complete source observations. Rebuilding labels from raw bars alone would not have repaired this mismatch. [P5, C1]

**Repeated signals and economics:** current PF is usually `sum(positive net per-instance returns) / abs(sum(nonpositive net per-instance returns))`, not NAV. Repeated D5 signals in a single ticker overlap; unlimited tranches versus one open ticker position have substantially different admission and exposure. Costs are assumed flat bps, **not** sourced premarket stock spread/slippage/borrow; option bid/ask spreads are option-feature inputs, *not* the underlying execution charge. Long and short fills and corporate-action/stock-volume units need further audit. [P4, P5, P6]

## 3. Quantified results and how to interpret them

| Result | Measured figure | Interpretation |
|---|---|---|
| Original old 40-packet ledger | 869 trades, **1/869** old entry prices and **0/869** returns matching corrected stock labels | Old selected research packet historical PFs invalid as subject-stock evidence. [P5] |
| Old 40 replay, Sep–Oct | Previously touted **PF 2.11**; all old finalized proxy outcomes match **NQMAIN**, not the signaled stocks | **Invalid performance.** Old signal identities can match even while old returns are wrong. [P1, P5, P6] |
| Runtime-aligned frozen 40, through Aug 31 | 7,127 price-labeled D0s examined, 6,755 runtime-feature-ready, 1,224 triggered; **25-bp net PF 1.81**, mean +1.29% per overlapping signal | Selected development history, **not independent validation or portfolio PF**. Purged research split PFs **1.02** train (626), **3.83** validation (245), **2.13** final tail (275); rule search and earlier inspection invalidate unbiased claims. [P5] |
| Corrected frozen 40 Sep 1–Oct 15 D0 replay | **221 signals; 165 finalized by Oct 15, 39 pending exit, 17 pending next-session entry; net PF 0.77**, mean −0.462%, 44.2% net wins (25 bp) | 165/165 returns independently reconcile to exact raw subject bars. September PF **0.71** (115/115 finalized); Oct 1–15 PF **0.91** (50/106 finalized). At 0/50/100 bp combined PF is 0.89/0.67/0.50. This window had already been consulted, **not clean OOS**. [P6] |
| Same-ready unconditional comparator, Sep–Oct | PF **1.01** at 25 bp, 987 finalized ticker/date directional observations | Comparator uses each frozen ticker's declared LONG/SHORT/horizon every runtime-ready date, **not a funded portfolio**. [P6] |
| Overlap admission, Sep–Oct | One open position/ticker: 88 finalized selected, PF **1.03** at 25 bp | Admission/instance statistic only, no cash NAV; pending later trades excluded from this diagnostic. [P6] |
| Pooled exploratory option spread-rank LONG D5 | Train/validation/late-tail PF ~**1.18/1.31/1.34** at 25 bp; same-date volatility/relative-volume-matched late-tail excess **+0.07 pp per date**, descriptive 95% interval **[−0.61,+0.84]** | Weak, concentration-sensitive *research lead*, not a reliable edge. Removing five largest late-tail ticker contributors leaves PF ~1.07. Quote screen labels cover 87 symbols, not all 180 profiled. [S1, P4] |
| Bollinger lower-band LONG D5 | PF **1.15/0.91/5.63** train/validation/late-tail | Contradictory splits; not evidence for universal lower-band buying. High OI-rank LONG D5 **1.46/1.29/0.94**; high IV-rank **0.98/1.67/0.97**. No source family promoted. [S1] |

**Risk concentration:** In the corrected Sep–Oct 40 replay, frozen META SHORT alone had 23 finalized events, net mean −3.73%, PF ~0.11. Dropping META *after seeing this result* raises the basket's finalized PF to ~1.04, but is **not** a valid strategy-selection rule or unbiased confirmation. SQQQ's `Is_Swing_Down` chronology is still unverified; excluding its one finalized event changes PF negligibly. Do not turn these diagnostics into a post-hoc optimized basket. [P6]

## 4. What is wrong or unfinished

1. **Universe ambiguity:** obtain the exact authoritative 92-instrument list and mark ordinary stock/ETF versus context/index/option roots. Reconcile every symbol to August GEX coverage, causal feature coverage, exact executable entry bars and resolved labels; do not infer 52 failed strategies from `92−40`. [U1, U3]
2. **Selection and feature leakage risk:** original candidates were ranked after a broad rule search on defective labels/time mapping; old packet statistics are invalid. Runtime/source feature ranks differ unless actually recalculated via runtime code. Verify every derived flag's publication/confirmation timestamp (`Is_Swing_Down` especially) and historical revisions/splits. The operator's quote D0→D1 ~07:00 ET readiness is a working assumption, not a proven historical snapshot timestamp. [P1, P2, P5, C1]
3. **OOS contamination:** Sep 1–Oct 15 and the August final research tail were repeatedly inspected. No fresh forward period is certified untouched; a new model or ticker filter inspired by those returns needs a newly frozen prospective validation period. Resolved labels must end inside the chosen cutoff; pending remain pending. [P4, P6, H1]
4. **Coverage limits:** many of the 47 other label-supported symbols have only ~22–51 D0s; per-ticker thresholds or 3-fold tests may be statistically impossible. Broader quote data cannot be used with the exact 07:30 label convention where underlying 30M price bars are missing. A new 09:30/daily-open family needs its own timing, baseline, readiness, price adjustment and cost model. [U1, P4]
5. **Execution and portfolio realism:** 07:30 bar-open after evaluation is optimistic; 25 bps costs not empirically calibrated for premarket/shorting; no corporate-action/instrument-identity, source daily volume units, premarket depth or borrow verification. Current PFs are instance-weighted, not NAV, turnover, drawdown, cash/exposure or correlated-sector capacity. [P4, P5, P6]
6. **Multiple testing and confounding:** first-screen 62 conditions are exploratory, and the first combined-availability bug was corrected retrospectively. No consistent nested multi-fold selection, ticker/sector-held-out transfer, family-level multiplicity adjustment or robust path-dependent exit simulation. Quote spread may proxy for volatility/illiquidity rather than directional information. [S1, P4]
7. **Operational safety — time-sensitive:** read-only SQL state audit at 2026-10-18 10:14 UTC found the **old 40 `1.0.0-production` strategies already have 40 enabled LIVE_MANUAL deployments, notifications enabled and 80 enabled EVALUATE/MONITOR schedules; `ExecutionEnabled=0` for all**. This contradicted an earlier research assumption. The new review-only ZIP is **not provisioned**. No live state was changed; disabling schedules/notifications requires explicit operator approval. Do not assume `HARD_DISABLED` broker execution disables erroneous alerts. [P5, O1]

## 5. Suggested independent-AI review questions (do not execute automatically)

- Is our **92-instrument denominator** meaningful for a 07:30 underlying strategy? Which symbols are viable under a separate 09:30 family? How should point-in-time universe membership and ETF/inverse/leveraged exposure be represented?
- Given the **47 non-40 label-supported symbols** and the 20 exploratory candidate tickers among them, how would you compare **GEX-only vs technical-only vs quote-only vs joined** approaches on identical causal/symbol/date/entry/exit coverage without inheriting the old selected-40 bias? How should short histories be pooled rather than overfit per ticker?
- What exact **source/publication-time and corporate-action audits** would close the runtime-parity, swing confirmation, delayed-quote-readiness, stock-volume-unit and 07:30-fill gaps?
- What predeclared **multi-testing, nested chronological + ticker/sector holdout, pending-label, cost and portfolio/NAV** rules are feasible with limited common history? What minimum evidence would justify only *shadowing* a rule, and what untouched future window can actually be reserved?
- What **operational risk action** is appropriate for the old 40 notification-enabled live deployments, pending operator authorization? Do not propose that this research note itself triggers SQL provisioning or unapproved live changes.

**Requested output from reviewing AI:** identify incorrect assumptions with source-specific citations, rank the top 3–5 *research* designs by expected information value and feasibility, specify stop/falsification criteria and a genuinely prospective validation protocol, and separate near-term live-alert safety decisions from long-run strategy research. Do not claim an edge for the 47 or promote a filtered 40 from inspected dates.

## Appendix A — the 47 August label-supported instruments outside the 40

“Candidate” means **at least one row** in the corrected simple GEX `best-by-ticker.csv` screen, **not** a production-ready, verified edge. D0 counts are corrected price-eligible observation dates by 2026-08-31, **not** runtime-feature-ready trading opportunities. `Prior 58` indicates old selected-research membership only. [U1, U2, U4]

| Symbol | Eligible D0 dates | Exploratory corrected GEX candidate? | Prior 58? |
|---|---:|---|---|
| ADBE.US | 78 | Yes | Yes |
| ADI.US | 50 | No | No |
| AKAM.US | 49 | No | No |
| AMZN.US | 208 | Yes | Yes |
| ASML.US | 51 | No | No |
| CEG.US | 49 | No | No |
| CIEN.US | 51 | No | No |
| COHR.US | 51 | Yes | Yes |
| CRWV.US | 51 | No | No |
| DDOG.US | 51 | Yes | No |
| DELL.US | 51 | No | No |
| DRAM.US | 51 | No | No |
| EWY.US | 51 | No | No |
| FCX.US | 213 | Yes | Yes |
| FLEX.US | 41 | No | No |
| FORM.US | 36 | No | No |
| GDX.US | 212 | Yes | Yes |
| GEV.US | 49 | No | No |
| GLD.US | 212 | Yes | Yes |
| GOOG.US | 209 | Yes | Yes |
| HPE.US | 51 | No | No |
| IGV.US | 51 | Yes | Yes |
| INTC.US | 78 | Yes | Yes |
| KLAC.US | 47 | Yes | No |
| LITE.US | 51 | No | No |
| LRCX.US | 78 | Yes | Yes |
| METU.US | 33 | No | No |
| MOD.US | 37 | No | Yes |
| MULL.US | 29 | No | No |
| NVDL.US | 37 | No | No |
| NXT.US | 40 | No | No |
| OKTA.US | 51 | No | No |
| PANW.US | 78 | Yes | Yes |
| PWR.US | 37 | No | No |
| QCOM.US | 78 | Yes | Yes |
| S.US | 51 | Yes | Yes |
| SKHY.US | 31 | No | No |
| SMCI.US | 51 | No | No |
| SNDU.US | 22 | No | No |
| SPCX.US | 51 | No | No |
| SPXL.US | 42 | No | No |
| SPXU.US | 45 | Yes | Yes |
| TSLA.US | 214 | Yes | Yes |
| TSLL.US | 37 | No | No |
| TXN.US | 76 | Yes | Yes |
| WDC.US | 50 | Yes | No |
| ZS.US | 50 | Yes | Yes |

## Source key (repo-relative unless noted)

- **[U1]** `backend/data/strategy_runtime/20261018-b-research/research_corrected/data-audit.json` and `eligible-outcomes.csv`: August source universe and corrected label population.
- **[U2]** `backend/data/strategy_runtime/20261018-b-research/research_corrected/all-candidates.csv`, `best-by-ticker.csv`, `BASELINE-STATUS.md`; `backend/data/strategy_runtime/20261017/research_all_august_universe/distinct-stocks.csv`: exploratory search counts and earlier 58 membership.
- **[U3]** `backend/data/strategy_runtime/20261018-b-research/intraday-30m-coverage-through-cutoff.csv` and `expanded-universe-entry-coverage.json`.
- **[U4]** `backend/data/strategy_runtime/20261018-a/selected_gex_live_production_contracts_2026-10-18-a/master-manifest.json`: frozen 40 identities/cap provenance; old performance in this archive **must not be cited as valid**.
- **[D1]** `backend/data/strategy_runtime/20261018/stockdb-us-table-inventory.csv`, `stockdb-us-research-map.md` (approximate snapshot counts); owning schemas under `DatabaseSchema/StockDB_US/`.
- **[C1]** `backend/tools/us_gex_sql_research.py`, `backend/tools/all_us_gex_discovery.py`; `C:/Repo/stocks_collecting/src/strategy_runtime/strategies/capital_type_gex/{features.py,implementation.py}` and `strategies/gex_sql_source.py`: research versus runtime feature implementation.
- **[S1]** `backend/data/strategy_runtime/20261018-b-research/first-screen-analysis.md`, `fixed_hypothesis_screen_v2/`, `spread_robustness/`, `checkpoint-04.md`.
- **[P1]** `backend/data/strategy_runtime/20261018-b-research/stage-1-data-audit.md`, `reconciled-events.csv`, `outcome-audit-metadata.json`: legacy proxy-return error.
- **[P2]** `backend/data/strategy_runtime/20261018-b-research/checkpoint-02.md`, `august-label-audit.csv`, `research_corrected/BASELINE-STATUS.md`: raw-bar label reconciliation.
- **[P3]** `backend/data/strategy_runtime/20261018-b-research/checkpoint-03.md`, `technical_features/`, `option_features/`, `option-quote-universe-coverage-through-cutoff.csv`.
- **[P4]** `backend/data/strategy_runtime/20261018-b-research/checkpoint-04.md`, `entry_latency_sensitivity/`, `overlap_sensitivity/`, `expanded-universe-entry-coverage.json`.
- **[P5]** `backend/data/strategy_runtime/20261018-b-research/checkpoint-05.md`, `baseline_40_runtime_aligned_review_packets_2026-10-18-b.zip`, `baseline_40_legacy_ledger_audit.json`, `baseline_40_runtime_parity.json`, `baseline_40_runtime_aligned_split_comparison.csv`.
- **[P6]** `backend/data/strategy_runtime/20261018-b-research/checkpoint-06.md`, `frozen_40_sep01_oct15_replay/` (221 signals, independent 165-trade raw-bar audit, cost/ticker/overlap files).
- **[O1]** `backend/data/strategy_runtime/20261018-b-research/baseline_40_live_state_read_only.json` and `.csv`: sanitized read-only SQL snapshot of existing deployment/schedule state (checked_at_utc in JSON).
- **[H1]** `docs/research/us-multisource-edge-discovery/research-plan.md` and `hypothesis-register.md`: desired tests and governance **not yet completed**.
