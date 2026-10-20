# Checkpoint 04 — corrected conjunctions, robustness and entry/capacity sensitivities

Research only. Cutoff **2026-08-31**; no September/October selection or fresh forward test. SQL queries used SELECT only; no production changes. Previous 20261018/20261018-a artifacts and first-run screen preserved. All analyses below are **post-inspection development** and may not be cited as independently confirmed.

## 1. Screen regression fixed

The original eight combined conditions specified human-readable strings like `BB20PercentB+GEX_ZScore`. `fixed_hypothesis_screen.py` used `panel[feature].notna()` only if a *literal column* with that name existed. Thus all eight matched populations were empty, even though the predicates had qualifying rows. Added a regression test that reproduced the unavailable-conjunction symptom before fixing it. Condition input columns are now explicitly registered as tuples and availability requires each constituent to be non-null. Old results remain in `fixed_hypothesis_screen/`; corrected rerun is `fixed_hypothesis_screen_v2/`. Original first-screen and checkpoint-03 reports carry errata.

Corrected combined D5, **25 bps net**, with label-boundary purging:

| Combined LONG unless SHORT noted | Train N/PF | Validation N/PF | Final-tail N/PF |
|---|---:|---:|---:|
| Lower Bollinger %B + low GEX | 386 / 1.11 | 141 / 0.76 | 165 / 7.08 |
| Lower Bollinger %B + high GEX | 11 / 0.01 | 1 / 0.00 | 5 / 1.24 |
| Lower Bollinger %B + high IV rank | 200 / 1.17 | 35 / 1.47 | 84 / 6.64 |
| Lower Bollinger %B + low IV rank | 31 / 0.73 | 49 / 0.90 | 25 / 2.99 |
| RSI14 oversold + low GEX | 74 / 1.45 | 20 / 0.68 | 6 / 18.99 |
| Support near + high OI rank | 53 / 0.75 | 68 / 1.09 | 76 / 1.80 |
| Resistance near + high IV rank, SHORT | 74 / 1.23 | 53 / 0.53 | 43 / 0.64 |
| MACD positive + high option volume rank | 388 / 1.18 | 256 / 0.93 | 344 / 0.59 |

The lower-band/high-IV result is a **follow-up lead only**: its train PF <1.2; final tail was already viewed; overlapping episodes and outliers remain. None meet a robust promotion standard. A huge PF on six trades has little meaning. The registry in v2 records exact source expressions and input columns; it is a retrospective fix, not a newly untouched preregistration.

## 2. Spread-rank lead: matched controls and stress

`spread_robustness/`: fixed high prior-60 option spread rank >=.8, underlying LONG D5 at 25 bps. Same-date matched **non-trigger** controls use predeclared broad ATR14% bins and prior-only within-ticker stock volume-rank thirds. Missing/unmatched signals are counted, not imputed. Historical stock `Volume` units are **not independently verified**, so this is a relative turnover control, not a calibrated dollar-liquidity cost model. No sector, price or borrow matching yet.

| Split | Signals with ATR/volume rank | Paired to controls | Per-date equal-weight excess (percentage points) | Descriptive 5-date-block 95% interval |
|---|---:|---:|---:|---:|
| Train | 816 | 698 | +0.33 | [-0.21, +0.87] |
| Validation | 594 | 557 | +0.31 | [-0.51, +1.16] |
| Final research tail | 818 | 799 | +0.07 | [-0.61, +0.84] |

All intervals cross zero; they are descriptive and do **not** account for choosing this feature after screening. Selection and repeated same-ticker events remain concerns. Leaving out each split's five largest *return contributors* (post-hoc influence diagnostic only) changes signal PF to **0.98/0.89/1.07** for train/validation/tail. These exclusions are not tradable rules. The final tail's original PF 1.34 drops to 1.22 without SNDU; clipping each raw return to +/-20% gives PF 1.23. A strictly previous-XNYS-session quote-rank lag produced PF 1.24/1.30/1.27 on 822/549/830 signals but has a different selected set; this does not verify historical 07:00 quote readiness or independent predictive value.

## 3. Executable-universe reality check

`executable_universe_coverage.py` writes `expanded-universe-entry-coverage.csv/json`. Of **145** option symbols with >=120 quote days by cutoff, only **55** had *any* 30M price bars and **42** had >=120 30M bar dates. The only three 30M symbols outside the existing corrected 87-label equity universe were **SPX.US, SPXW.US, _VIX.US**—context instruments, not automatically stock/ETF executions. **Do not claim a broader 145-stock 07:30 backtest is possible from this source.** A new 09:30/daily-open execution family might support wider coverage, but must be separately specified, labeled, audited and compared; it has not been built.

## 4. Entry-time sensitivity and price QA

`entry_latency_sensitivity.py` pulled raw 30M bars with read-only SQL; its 10,591 original 07:30 entry opens all matched the corrected labels. For the spread signal, D5 25-bp PF at 07:30 bar open / 07:30 bar close / 08:00 bar open / 09:30 bar open is:

- train: 1.18 / 1.19 / 1.18 / 1.19;
- validation: 1.31 / 1.32 / 1.32 / 1.32;
- final research tail: 1.34 / 1.32 / 1.32 / 1.31.

No missing bars in those comparison rows. These are **price proxies, not achievable fills**. At a 07:30 evaluation, the 07:30 open may already have passed, and its close is not known until 08:00; the 08:00/09:30 opens have the same decision/latency caveat. Same-close D5 exit and fixed 25-bp underlying trading cost were held constant; no depth, broker order model, publication readiness, capacity or slippage confirmation. Operator assumes D0 option observations available around 07:00 ET next session; historical first-readiness still unverified and future live readiness must be logged.

`inspect_extreme_returns.py` saved **24 D5 events across 8 symbols with |gross return| >=40%** with raw daily-price context. SNDU.US Aug 10 D0 -> Aug 11 entry 14.94 -> Aug 17 daily close 29.75 is corroborated by the daily close *direction*, but that alone cannot establish share-adjustment consistency, symbol identity, tradeable 07:30 liquidity or achievable exit. PriceHistory daily `Volume` examples are extraordinarily high relative to recorded `Trades`; source unit/adjustment semantics must be verified before any dollar-volume or liquidity assumptions. Do not delete exceptional trades selectively after observing their returns.

## 5. Overlap/capacity selection, not NAV

`overlap_sensitivity.py` applies D1 entry, D5 close occupancy to the high spread signal. Deterministic ticker ordering and a close-day morning still occupied by an earlier tranche are tested. One position per ticker (versus unlimited signal tranches) reduces train / validation / final-tail N from **816/594/818** to **385/278/390**, with instance-weighted PF **1.16/1.20/1.09** versus **1.18/1.31/1.34**. A global 10-position cap reduces admitted events to 194/90/80, with PF 1.08/1.14/1.19 under the arbitrary ticker tie-break. These are **admission diagnostics, not capital-weighted portfolio returns**; there is no interim mark-to-market, NAV, financing, realistic fills or drawdown. Changing the tie-break or correlated exposure caps can change which signals are admitted.

## Decision and next gates

**No confirmed edge or production authorization.** The corrected combined screens do not change that conclusion. High spread rank's small matched excess and dependence on concentrated outcomes/overlap justify further collection, not a packet.

Prioritize (a) trace OptionDelayedQuote_V2 first-ready/revision times and its bid/ask quality and source volume units; (b) independent symbol/corporate-action checks for extremes; (c) a distinct 09:30 label family only if broader standalone option tests are desired; (d) sector/price/confounder controls and a genuinely prospective frozen test; (e) actual fills/costs and marked-to-market NAV if a frozen candidate survives. No rolling outer folds, complete sector matching, fresh forward confirmation, or full portfolio NAV were performed here. The already viewed final tail cannot be reused as pristine confirmation.

Run tests: from `C:/Repo/stocks_collecting`, `.venv/Scripts/python.exe -m pytest C:/Repo/stocks_au_web/backend/tools/multisource_research/test_*.py -q` — **22 passed**. New work did not edit collecting or database state.
