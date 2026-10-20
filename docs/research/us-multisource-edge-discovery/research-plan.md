# Research plan: US multi-source edge discovery

## 1. Objective and research questions

Build an evidence-backed strategy research programme, not an indicator shopping list. Explore useful StockDB_US sources broadly, form competing hypotheses, create temporary causal features, test them chronologically, and report successful **and failed** ideas.

Answer:

1. Do price-only, option-only, GEX-only, or combined features predict executable D1/D3/D5 directional returns beyond simple benchmarks?
2. Which features add value **beyond** the existing GEX signals, rather than merely select a lucky subgroup?
3. Are effects portable across dates, sectors, tickers, and volatility regimes?
4. Is the benefit entry selection, direction, exit timing, position sizing, or loss reduction?
5. Does the effect survive costs, overlapping positions, missing data, and realistic capital limits?
6. Which promising short-history sources deserve ongoing collection despite insufficient evidence for deployment?

Price outcomes refer to underlying stock/ETF trades. An option signal does not imply buying an option; option-execution research requires a separate option-pricing and execution contract.

## 2. Non-negotiable research governance

### Time boundaries

- Development data and resolved labels end on **2026-08-31**.
- A D0 observation is not eligible merely because D0 is before cutoff: its entire entry/exit label must also resolve by cutoff.
- No new feature fitting, threshold tuning, universe selection, early stopping, or model ranking uses September/October outcomes.
- September 1–October 15 has been repeatedly examined. Report the distinction between a chronological backtest and a genuinely untouched test. Ideas originating from that inspection are new research hypotheses, not pre-registered successes.
- Before claiming a fresh forward result, freeze a model/configuration hash and identify dates not previously consulted. Do not assume October 16–31 is untouched without checking prior access/artifacts. Otherwise use future dates after freeze.
- Pending trades stay pending; no zero substitution, favorable interim exit, or hypothetical completion.

### Existing research is evidence to audit, not ground truth

- Keep original packets and event files immutable.
- Keep the <=25% frequency comparator fixed; the field was measured before cutoff, but its apparent OOS benefit was discovered after inspection. That does not make the filtered OOS result unbiased confirmation.
- Previously selected GEX predicates already used pre-cutoff outcomes. Re-splitting their triggered trades does **not** turn their train/validation tails into independently untouched evidence.
- Previous 60/20/20 signal-count splits and tiny final samples are exploratory. Replace them with global chronological folds and label-aware purging.
- No hard-coded exclusion of META/AMD/MU/MRVL based on inspected losses.
- All table exploration is permitted; not every table is a safe predictor. Outcomes, backtest P&L, future-gain tables, mutable recommendations, user/account/authentication data, and operational state are not automatically input features.

### Authority and safety

SQL is read-only. No schema mutations, inserts into live TradingSignal tables, production activation, external notifications, broker calls, scheduled tasks, or destructive file operations. Inspect local instructions before touching another repository. Keep secrets out of artifacts and logs. Use one-physical-line PowerShell/CLI commands in this workspace.

## 3. Phase A — trust the data and execution labels first

### A1. Inventory the whole database

Start from `backend/data/strategy_runtime/20261018/stockdb-us-table-inventory.csv` and `stockdb-us-research-map.md`. They contain a prior inventory of 419 objects; revalidate current metadata, do not assume unchanged counts or coverage. The earlier map is a triage aid, not a complete understanding of every source.

For **every** table/view record:

- semantic family and purpose, key, symbol convention, timestamp/date columns;
- raw versus derived versus duplicated/cache/archive/operational object;
- upstream source/view/procedure lineage when available;
- point-in-time status: append-only, revised history, current snapshot, unknown;
- expected availability, update frequency, units, historical membership;
- useful feature ideas or reason for exclusion/deprioritisation;
- research status: inventoried, schema-read, sampled, profiled, tested, blocked.

Use metadata first. Do not scan 100M-row quote tables or 250M-row trade tables repeatedly just to learn row counts. For relevant candidates use indexed symbol/date slices, query timeouts, small concurrency, cache/resume, and exact counts only where needed. Never extract credential/user/message bodies just to fulfil an inventory.

Build coverage by **distinct observation dates**, before cutoff separately from total history, after joins separately from raw presence. Include valid-IV, OI, volume, executable-bar, and resolved-label counts. The user's approximately 140 long-history instruments are a strong reason to expand beyond 58 symbols; the count and pre-cutoff eligibility still require verification.

### A2. Audit outcomes, especially suspicious cross-ticker similarities

The prior event file contains repeated identical directional/raw returns across different stocks and opposite directions on identical dates. Examples visible in prior extracts include SOXL/XOM on September 1 and AMD/META on October 8. These coincidences are **audit flags, not proof of a bug**.

Independently trace at least 30 stratified finalized events, including these flags, all D1/D3/D5 horizons present, both directions, and at least ten tickers:

- StrategyCode -> subject -> execution instrument binding;
- source SQL parameters include the correct `.US` symbol;
- exact entry and exit bar timestamps, source row keys, raw prices;
- timezone meaning of TimeIntervalStart and ObservationDate;
- canonical exchange calendar, holidays, DST, half days;
- D0 signal date versus D1 execution date versus exit date;
- long return = 100*(exit/entry-1); short gross underlying return = negative raw return under the existing convention;
- no unintended benchmark price used for every ticker;
- HorizonCode, outcome revisions and duplicate joins do not multiply signals.

Also test missing bars: do not silently substitute the next observed 07:30 bar and shift D3/D5 forward. Exit horizons are **scheduled exchange sessions**, not the nth available data row. Half-day final bars must reflect the real session close.

Recalculate the 58-packet and 40-packet aggregate metrics from independently reconciled event rows. If a binding, label, symbol, or aggregation defect is found, quarantine dependent metrics, preserve old artifacts, document impact, and stop strategy ranking until corrected research labels are tested. Do not patch live runtime code under this research brief without a separately scoped approval.

### A3. Audit feature correctness

- Verify units and upstream calculations of GEX, GEXDelta, NoOfOption, IV, Greeks and capital categories. Names are not sufficient proof of financial meaning.
- Verify if GEX_Volatility is a time-series statistic, not implied volatility.
- Verify price swing flags: centered or future-confirmed definitions cannot appear at the pivot date.
- Find duplicate quote rows/snapshots by underlying, ObservationDate, OptionSymbol and snapshot identity. Choose a documented available-at-decision snapshot; never sum repeated snapshots or select a future revision.
- Exclude expired contracts; use split-adjusted contract/price conventions consistently.
- Preserve missing values. `NaN > threshold` must not become a valid low-regime observation through boolean defaulting.
- Weighted IV = sum(IV*weight for valid IV and weight)/sum(weight for those same valid rows). The denominator must not include invalid-IV rows. Apply the same principle to Greeks and spreads.
- Validate bid/ask constraints, crossed markets, stale quotes, nonpositive prices, IV scales, and outlier handling. OI is a stock; volume is a flow; NoOfOption is not necessarily traded volume.
- Volume-weighted absolute gamma/delta/vega are not automatically dollar GEX/DEX exposures. State multipliers, underlying-price factors, contract counts and sign conventions; avoid unsupported dealer-position inference.

**Gate A:** emit `data-audit-report.md`, `reconciled-events.csv`, `coverage-by-source-symbol.csv`, `source-catalog.csv`, and automated audit tests. Do not proceed past a material outcome defect. Inventory-only status does not count as testing all data.

## 4. Phase B — define the data and feature contracts

### Universe

Maintain separate, explicit universes:

1. Original 58/40 candidate symbols for comparator replication only.
2. The complete point-in-time pre-cutoff quote/price intersection, including symbols outside the earlier August GEX universe. No dependence on having won an old GEX search.
3. Short-history instruments retained for pooled/exploratory work.
4. Context instruments: SPX/SPXW/VIX and market/sector proxies; an index or option root is not automatically an executable equity instrument.

Use point-in-time memberships when available. A universe defined by symbols observed late in the sample carries survivorship bias; disclose it if historical membership cannot be reconstructed. Preserve dots in symbols such as BRK.B.US. Never split blindly at the first dot.

### Availability

Represent each feature with `observation_date`, `available_at`, `decision_at`, source, formula version and quality flags.

For OptionDelayedQuote_V2, use the user-supplied convention: D0 snapshot available about 07:00 on D1 in **America/New_York**. Interpret ET with DST, not fixed UTC-5 unless the operator specifically confirms fixed EST. Proposed default decision/entry is D1 07:30 ET. Account for actual late collection using a readiness flag, not by discarding options globally.

For historical data without snapshot publication timestamps, mark `OPERATOR_ASSUMED_AVAILABILITY` and test a one-session-lag sensitivity. Do not silently call the historical database a perfect immutable point-in-time tape.

Do not use a full D1 opening range, D1 volume, or D1 VWAP at 07:30. A later decision family must have a separately timed entry and matched benchmark. A 07:30 bar's opening print may not be executable after a 07:30 evaluation; include a decision/latency buffer or explicit optimistic-open comparator.

### Temporary causal features

Create a feature dictionary with formula, unit, lookback, minimum history, source lineage, availability, null rule, and causal proof for each feature. Preserve raw inputs alongside derived values. Normalisers, imputers, winsorisation thresholds, feature selection and model calibration fit on training only.

Suggested initial families, not an exclusive whitelist:

| Family | Initial features |
|---|---|
| Moving averages | SMA/EMA 10/20/50; price distance in % and ATR units; slopes; alignment; crossovers; prior trend length |
| Momentum | RSI 7/14/21; change/slope; MACD line/signal/histogram; returns over 1/3/5/10/20 sessions; relative strength |
| Bollinger structure | 20-session mean/std; %B; signed distance to lower/upper band in ATR; bandwidth; squeeze rank; expansion; breakout/re-entry |
| Volatility/range | ATR 14/20; realised vol 10/20/60; vol ratio; overnight gap; intraday range; close location; drawdown |
| Support/resistance | prior rolling 10/20/60 highs/lows; confirmed pivots; prior-session/week/month classic pivots and CPR; distance/room to levels in ATR |
| Trendlines/divergences | fixed-window trailing regressions; confirmed-pivot lines using only known anchors; RSI/MACD/GEX divergence at confirmation time |
| Price/volume | relative volume; dollar volume; OBV slope; close-versus-VWAP; prior anchored VWAP with deterministic anchors; breakout volume confirmation |
| Delayed options | call/put volume and OI; VOI; matched-contract OI changes; volume shocks; IV level/change/rank; near-ATM IV; IV skew/term structure; DTE/moneyness buckets; spreads/liquidity |
| Exposure/walls | GEX/DEX levels, change, concentration and sign; expiry-weighted exposure; gamma-wall/flip distance; price position relative to walls |
| Option trades | signed premium/size if inferable, sweep/block/large-flow measures where fields support them; last-hour flow; direction confidence |
| Market/sector | SPY/QQQ and sector trend/volatility; VIX; breadth; CLV; ETF flows; relative momentum; correlation/beta |
| Other sources | inspect events, fundamentals, money flow and existing analyses where historical availability and semantics support causal use |

No hindsight trendline drawing. A centered pivot needing k right bars becomes usable only k bars later. Prior-period pivots use the **completed** previous period; do not use the future high/low of the current week/month. Short histories may use shorter declared lookbacks; compare only matched coverage and report confidence.

**Gate B:** tests must prove future-data perturbations cannot change past features or decisions; null values, DST, calendar gaps, duplicate snapshots, symbol aliases and minimum-history boundaries are covered.

## 5. Phase C — pre-register experiments before broad search

Use the companion hypothesis register. Every test gets an `experiment_id`, parent hypothesis, exact configuration, direction, decision time, feature formula hashes, split IDs, costs, horizon, universe, and model version before its results are inspected.

Use staged budgets to balance breadth with false discoveries:

1. **Discovery screen:** up to 2,000 prespecified feature/threshold/direction/horizon variants, trained/scored only inside inner chronological folds. Count ALL trials, failures and abandoned runs. Do not repeatedly read a final tail.
2. **Confirmatory shortlist:** maximum 20 frozen candidates selected from inner folds by a fixed net-risk-adjusted rule, not largest PF. Group near-duplicate thresholds into families.
3. **Outer evaluation:** evaluate only the locked inner selection procedure on outer dates. Do not use outer results to iterate and still label that same run untouched.
4. **Research extension:** novel ideas may be proposed from findings, but register them as new rounds with an updated tested-trial count and new validation allocation. Reused outer data is development thereafter.

Starting thresholds should be economically interpretable and coarse, for example RSI 30/50/70; %B .1/.5/.9; ATR distances .5/1/2; prior percentile .2/.5/.8. Do not enumerate every conceivable combination. A null result is a valid output.

Compare each hypothesis against both sides where economically reasonable: trend-following versus mean reversion; high versus low IV; near support versus breakdown continuation. This prevents assuming lower-band buying, low volatility, or high OI is inherently better.

## 6. Phase D — chronological experimental design

### Global time folds, not a different signal-count tail per ticker

Choose split boundaries using available calendar coverage **before looking at returns**. Write `split-manifest.json` with actual dates. Example geometry for approximately nine months of common history:

- outer training minimum 80 sessions, outer test 20 sessions, roll 20;
- inner expanding training minimum 40 sessions, validation 15–20 sessions;
- use earlier additional history where reliable, but compare models on identical outer dates;
- purge training events whose actual exit/label interval reaches the validation/test decision boundary;
- embargo at least the maximum 5-session label horizon when a split construction could otherwise allow adjacent-window leakage; record exactly which rows were removed and why;
- weekly/monthly and longer-horizon labels require longer purges if introduced.

If that geometry cannot yield at least three meaningful outer folds, use a smaller predeclared exploratory design and label the evidence limited. Do not pretend three trades constitute a stable fold. Include alternate lookback/lag configurations as sensitivity tests, counted as trials.

Evaluate chronological transfer **and** ticker-held-out transfer. Use correlated-sector/instrument-family groups for ticker holdout so leveraged inverse versions of the same exposure do not create an easy pseudo-independent test. Shared benchmark features are permitted only as lagged causal context.

### Baselines and incremental comparisons

On the same symbol/date/label-availability intersection compare:

- unconditional direction and buy-and-hold over matched horizons;
- simple trend and simple reversion;
- GEX-only;
- technical-only;
- option-quote-only;
- option-flow/wall-only where coverage supports it;
- GEX + technical;
- GEX + quotes;
- technical + quotes;
- combined GEX + technical + quotes, then flow/wall/context ablations.

Also run a **standalone discovery arm** without the existing GEX trigger. Otherwise a valuable option-only or technical-only edge is invisible. Include both long and short. Tune in inner training only.

Start with transparent rules and regularised linear/logistic models. A small constrained tree/boosting model is optional after simple models. Report feature-family ablation, not only model feature importance. All models share folds, costs and trial accounting. No huge per-ticker optimisations on 15 trades.

For incremental feature tests, show baseline on the exact same available-data subset, added-feature result, removed-feature result, coverage lost, turnover, risk and return. Higher PF with one-tenth the observations is not automatically an improvement.

### Short history and collection value

Do not discard quote data wholesale because some tickers are short. Report three separate properties:

1. data quality/coverage and live collection value;
2. predictive/economic usefulness in retrospective experiments;
3. deployment readiness under genuinely independent evidence.

For short histories use raw features without rank warmup when meaningful, pooled models, shorter predeclared ranks, and family-level shrinkage. Do not backfill missing history or train a ticker on future dates through another ticker. Label each result adequately sampled, exploratory, or insufficient.

## 7. Phase E — exits and executable portfolio replay

### Entries and labels

- Primary family: D0 completed data -> next session premarket decision -> explicit D1 executable entry convention.
- Fixed exits D1/D3/D5 at scheduled regular close, including half days.
- A later 09:45/10:00 confirmation arm is optional and separate. Features become available only once their bars close; execution is after decision.
- Baselines and enriched strategies must use identical entry/exit bars for valid comparisons.

### Path-dependent exits

After label reconciliation, use chronological intraday OHLCV for:

- fixed D1/D3/D5;
- ATR stop + fixed time exit;
- ATR trailing stop, activated/tightened only after completed bars;
- predeclared support/VWAP failure;
- MAE/MFE research, never using completed-trade future MAE as an entry feature;
- optional partial-profit exit plus remainder, with fill/cost accounting.

For gaps through stops fill at the worse executable price, not the stop level. If a bar hits stop and target and order cannot be resolved, use conservative stop-first or finer data; report ambiguity. A high set during a bar cannot tighten a trail before a low earlier in that same bar without an explicit conservative rule. Missing bars flag uncertainty, not free favorable fills.

### Overlap policies

Report all three, keeping signal quality separate from capital use:

1. independent D5 tranches (comparable to the old instance ledger);
2. one open position per ticker, skip additional signals until exit;
3. capped pyramiding, maximum 1/3/5 tranches per ticker as prespecified simulation policies.

D5 means entry on session 1 and scheduled close on session 5; at most five daily tranches per ticker is conditional on one entry/day, no extended holds and fixed D5 exits. Intraday occupancy differs from end-of-day occupancy.

Add fixed gross/net exposure budgets, maximum ticker/sector/correlated-cluster exposure, deterministic signal tie-breaks known at decision time, short-borrow availability assumptions, and no reuse of capital before a close exit. Compute marked-to-market NAV, drawdown, turnover, peak concurrent trades and cash usage. Daily averaging of forward returns is **not** portfolio P&L.

### Costs

Apply underlying stock/ETF spread, slippage, fees and short borrow/financing as appropriate. Start with sensitivity 10/25/50/100 bps round trip, then replace with source-supported class/ticker costs. Premarket execution may require higher costs than RTH. Include entry latency and liquidity constraints. Option bid/ask spread can be an information/liquidity feature; do not charge it as the underlying trade spread. Option purchases require a different execution model.

## 8. Phase F — statistical standards and decisions

Every result needs N, unique tickers, unique dates, overlap-policy count, wins/losses/breakevens, mean/median return, PF, worst loss, tail loss, turnover and coverage. Portfolio results additionally need NAV/drawdown/exposure metrics. PF is sum of positive net returns divided by absolute negative net returns on an explicitly stated weighting basis. A no-loss tiny sample is undefined/unbounded, not PF=0 and not a reliable very high finite PF.

Use paired date/block bootstrap comparisons, with blocks no shorter than the largest holding horizon and cross-sectional dates sampled jointly. Serial/sector dependence means hundreds of overlapping trades are not hundreds of independent bets. Include multiple-testing controls (e.g. family-level FDR for formal screening tests) and display the number of attempted trials. Bootstrap intervals after selection are descriptive unless selection is included inside resampling or validated in untouched outer data.

Predeclare a provisional **shadow-candidate** gate before search:

- at least three outer folds if coverage permits;
- at least 50 finalized outer trades, 30 distinct signal dates and meaningful representation across folds for pooled claims;
- net aggregate PF >=1.2 under the base cost case, positive net expectancy, positive incremental improvement on matched coverage for added-feature claims;
- positive net expectancy in at least two-thirds of evaluable outer folds;
- not dependent on one date, ticker, or single winning trade; report leave-largest-winner and leave-ticker-out sensitivity;
- adjacent-threshold, extra-lag, higher-cost and overlap-policy sensitivity do not reveal a knife-edge artifact;
- data and causal audits passed, no future-label inputs;
- uncertainty and selection risk reported, not concealed by an arbitrary PF cutoff.

These are governance filters, not statistical proof. Ticker-specific and short-history results may be promising without satisfying this gate; label them **EXPLORATORY**, never auto-approve them. Do not tune the gate after seeing results. Only genuinely fresh forward validation plus review can support promotion beyond shadow research.

## 9. Concrete outputs and execution sequence

New artifact root: `backend/data/strategy_runtime/20261018-b-research/`.

| Stage | Output | Next-stage gate |
|---|---|---|
| 0 | immutable input hashes, state/repo instructions, audit scope | no destructive/live operations |
| 1 | full source catalogue; coverage; independently reconciled outcomes; audit tests | no material label defect |
| 2 | causal feature dictionary/cache; tests; operator availability assumption | causal/time/unit tests pass |
| 3 | hypothesis registry; split manifest; trial budget; baseline reports | splits/config frozen |
| 4 | standalone and incremental screens; complete trial ledger | train/inner selection only |
| 5 | frozen shortlisted rules/models; outer fold reports; ablations | no outer-feedback retuning |
| 6 | path exits, net-cost stress, portfolio replay | trade/NAV reconciliation |
| 7 | analyst report; candidate/rejected/insufficient decisions; collection priorities | no fabricated promotion |

Required machine-readable files: `source-catalog.csv`, `coverage-by-source-symbol.csv`, `feature-dictionary.csv`, `hypotheses.jsonl`, `split-manifest.json`, `experiments.jsonl`, `results-by-fold.csv`, `results-by-symbol.csv`, `results-by-family.csv`, `trade-ledger.csv`, `portfolio-daily.csv`, `candidate-decisions.csv`, and `reproducibility-manifest.json`.

Required final narrative: distinguish **what was actually tested**, **what remains a hypothesis**, and **what is blocked by data**. Provide an indicator-family decision table: source, valid coverage, test count, baseline, incremental net effect, stability, failure modes, and use recommendation (entry/filter/exit/sizing/context/not useful yet). Do not promise that combining all families must outperform.

No new packet production in this execution. If a shadow candidate passes, output a frozen research specification with enough information to generate a new version later, but wait for explicit approval before descriptor generation or provisioning.

## 10. Local primary references

- `backend/data/strategy_runtime/20261018/strategy-summary.csv` and `oos-backtest-events.csv`: original candidate metadata and historical outcome extract.
- `backend/data/strategy_runtime/20261018/option_quote_research/`: preliminary quote features/screens; exploratory only.
- `backend/tools/august_strategy_improvements.py`, `option_quote_research.py`, `option_quote_walkforward.py`: inspect/audit, do not trust their prior splits or joins without tests.
- `DatabaseSchema/StockDB_US/`: owning table/view/procedure definitions; inspect upstream feature semantics.
- `C:/Repo/stocks_collecting/src/strategy_runtime/`: source and outcome implementation when tracing execution; obey that repository's instructions first.

Schema existence is not proof of populated usable history. Saved CSV existence is not proof of causal correctness. Every promoted claim must trace to verified source records and a reproducible experiment.
