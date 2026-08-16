# SPXW GEX → QQQ Strategy (NQ Proxy)

**Strategy code:** `SPX_GEX_QQQ_V1`  
**Version:** `1.0.2-contract`  
**Status:** `REVIEW_READY`  
**Implementation key:** `spx_gex_qqq_v1_0_2_contract`  
**Owner:** `US_STOCKS_INDEXES_STRATEGY_RESEARCH`  
**Research date:** 2026-08-16  
**Superseded strategy/version:** `SPX GEX v1.0.2 research/backtest reference (formalized by this contract)`

## 1. Identity and rationale

**Purpose.** Generate QQQ notification-only plans from SPXW capital-type GEX data, using NQMain percentage path as the historical 03:30 proxy.

**Rationale.** Combines price/PCR quadrant base signals with sell-call level and sell-put share for Yellow quality, and uses prior-five-session NQ regime for Green timing.

**Change summary.** Contract formalization of the SPX GEX v1.0.2 research/backtest logic; no intended threshold/entry/exit change. Any logic, source dependency, threshold, entry time, exit, slippage or enablement change requires a new version.

**Validation method.** Prior historical v1.0.2 common-warmup backtest aggregate reference; full ledger/NQ source unavailable for independent reproduction in this packet.

**Known limitations.** ["NQMain raw source/hash unavailable", "Per-instance v1.0.2 ledger unavailable", "No strict OOS claim", "Future paper slippage convention not frozen"]

**Research window.** `2025-03-06` through `2026-08-06`.  
**Strict out-of-sample window.** `NOT_AVAILABLE` to `NOT_AVAILABLE` — Prior results are a historical research/backtest reference, not an untouched OOS study.

**Bias controls.** Causal thresholds always exclude D0 and use only the 60 prior valid observations. D1+ prices are outcome-only. Symbols are fixed before each strategy run, so no dynamic survivor universe is used. No corporate-universe survivorship adjustment is needed for a single fixed subject, but delisting/corporate-action history would still need adjustment if the subject changed. Data snooping/multiple testing is explicitly disclosed; SPY/META keep push disabled pending forward paper, and SPX lacks a strict OOS claim. Selection bias is controlled operationally by logging every evaluated date after readiness and by computing historical candidate stats without manual-trade filtering.

## 2. Instruments

```json
[
  {
    "role": "SUBJECT",
    "code": "SPXW",
    "market": "US",
    "exchange": "NYSE/Nasdaq consolidated US equity market",
    "currency": "USD",
    "timezone": "America/New_York",
    "market_date_convention": "XNYS cash-session label",
    "calendar": "XNYS",
    "holiday_handling": "Skip non-XNYS sessions; Dn counts cash sessions only.",
    "daylight_saving_handling": "Use IANA America/New_York; never fixed UTC offset.",
    "early_close_handling": "Use official XNYS early close as cash-close terminal time."
  },
  {
    "role": "SOURCE",
    "code": "SPXW",
    "market": "US options-derived GEX",
    "exchange": "Derived source",
    "currency": "USD",
    "timezone": "America/New_York",
    "market_date_convention": "ObservationDate is the completed underlying US cash session D0.",
    "calendar": "XNYS",
    "holiday_handling": "No row expected for holidays/weekends.",
    "daylight_saving_handling": "ObservationDate is date-only; scheduling uses America/New_York.",
    "early_close_handling": "D0 remains that XNYS session date."
  },
  {
    "role": "PROXY",
    "code": "NQMain",
    "market": "CME futures continuous-series proxy",
    "exchange": "CME",
    "currency": "USD",
    "timezone": "America/New_York",
    "market_date_convention": "Bars normalized to America/New_York; Dn still defined by XNYS sessions.",
    "calendar": "XNYS for strategy day numbering; futures bars for path",
    "holiday_handling": "Use XNYS session map and require the requested proxy bar.",
    "daylight_saving_handling": "America/New_York IANA conversion.",
    "early_close_handling": "Cash-session D5 close follows XNYS; futures path remains available but terminal time is cash close."
  },
  {
    "role": "EXECUTION",
    "code": "QQQ.US",
    "market": "US",
    "exchange": "Nasdaq/US consolidated market",
    "currency": "USD",
    "timezone": "America/New_York",
    "market_date_convention": "QQQ market date follows XNYS session date.",
    "calendar": "XNYS",
    "holiday_handling": "No entries on non-XNYS sessions.",
    "daylight_saving_handling": "America/New_York.",
    "early_close_handling": "Time exits use official XNYS close."
  }
]
```

## 3. Executable signal catalogue

| Priority | Signal | Exact trigger | Direction | Action | Entry rule | Exit rule | Notify |
|---:|---|---|---|---|---|---|---|
| 1 | `DATA_ERROR` | any_required_feature_invalid | NONE | NONE | NONE | NONE | no |
| 2 | `INSUFFICIENT_HISTORY` | yellow_threshold_history<60 OR (base_signal==BULLISH AND prior5D_NQ unavailable) | NONE | NONE | NONE | NONE | no |
| 10 | `SPX_STRONG_YELLOW` | base_signal==BEARISH AND SC_GEX_Level <= SC_GEX_Median60 AND SPShare > P75_SPShare_60 | SHORT | PLAN_ENTRY | SHORT QQQ D1 at 03:30 America/New_York. Live reference is QQQ executable price; historical model uses NQMain D1 03:30 Open as percentage-path proxy. | TP: entry*0.992; for short, Low <= TP.; SL: entry*1.010; for short, High >= SL.; If bar Open is beyond TP or SL, fill at Open.; If TP and SL both touched in same 30m bar, assume SL first and mark ambiguous=true.; No scheduled time exit in v1.0.2; position remains until TP or SL unless cancelled before entry.; No opposing-signal exit after position opens; existing-position priority blocks new signals. | yes |
| 20 | `SPX_RELIABLE_YELLOW` | base_signal==BEARISH AND SC_GEX_Level <= SC_GEX_Median60 AND SPShare <= P75_SPShare_60 | SHORT | PLAN_ENTRY | SHORT QQQ D1 03:30 ET; historical NQ percentage proxy. | TP entry*0.996.; SL entry*1.008.; Gap at Open fills Open.; Same-bar TP+SL => SL first, ambiguous=true.; No scheduled time exit.; No opposing-signal exit after open. | yes |
| 30 | `SPX_REVERSAL_GREEN` | base_signal==BULLISH AND Prior5D_NQ_Return <= 0 | LONG | PLAN_ENTRY | At D1 03:30 record reference. Place modeled limit at reference*0.99, valid through but not after D3 03:30. If any bar before D3 03:30 has Open <= limit, fill at Open; else if Low <= limit, fill at limit. If never filled, market-entry at D3 03:30 Open. | D5 official XNYS cash close time; with 30m data use final cash-session bar Close.; No TP.; No SL.; No opposing-signal exit. | yes |
| 40 | `SPX_NORMAL_GREEN` | base_signal==BULLISH AND Prior5D_NQ_Return > 0 | LONG | PLAN_ENTRY | LONG QQQ D3 03:30 ET; historical NQ percentage-path proxy. | TP entry*1.025, hit when High >= TP; gap above TP fills Open.; Otherwise D5 cash close.; No SL.; No opposing-signal exit. | yes |
| 50 | `SPX_MIXED_YELLOW` | base_signal==BEARISH AND SC_GEX_Level > SC_GEX_Median60 AND SPShare > P75_SPShare_60 | NONE | WATCH | NONE | NONE | no |
| 60 | `SPX_WEAK_YELLOW` | base_signal==BEARISH AND SC_GEX_Level > SC_GEX_Median60 AND SPShare <= P75_SPShare_60 | NONE | WATCH | NONE | NONE | no |
| 999 | `NO_SIGNAL` | NOT(any higher-precedence final signal) | NONE | NONE | NONE | NONE | no |

When no predicate matches after readiness/history/data-error gates, emit `NO_SIGNAL`, create a non-actionable report/signal record, create no paper plan, and send no Pushover notification. `NOT_READY` occurs before evaluation and creates no records.

## 4. Feature and formula contract

All decisions use full-precision values. Rounding is display-only. Quantiles use exactly the 60 prior valid observations, D0 excluded, with linear Hyndman-Fan type-7 interpolation. Duplicate capital-type rows fail readiness. Missing denominators are data errors; values are never imputed. Corrected rows change `source_revision` and force reevaluation.

```json
{
  "BCAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "column": "GEXDelta where CapitalType=BC",
    "formula": "abs(BC_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none for decisions; display only",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "BPAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "column": "GEXDelta where CapitalType=BP",
    "formula": "abs(BP_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SCAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "column": "GEXDelta where CapitalType=SC",
    "formula": "abs(SC_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SPAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "column": "GEXDelta where CapitalType=SP",
    "formula": "abs(SP_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "TotalAbsGEXDelta": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "columns": [
      "BC/BP/SC/SP GEXDelta"
    ],
    "formula": "BCAbs+BPAbs+SCAbs+SPAbs",
    "units": "GEXDelta absolute units",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if any component null or total <= 0",
    "lookback": "D0",
    "current_included": true
  },
  "PCR": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "BPAbs / BCAbs",
    "units": "ratio",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if BCAbs=0",
    "lookback": "D0",
    "current_included": true
  },
  "CloseChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "column": "Close",
    "formula": "100*(Close_D0 / Close_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "sign": "positive=price rose; negative=price fell",
    "rounding": "none",
    "null": "DATA_ERROR if either Close missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "PCRChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "100*(PCR_D0 / PCR_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "sign": "positive=PCR rose; negative=PCR fell",
    "rounding": "none",
    "null": "DATA_ERROR if previous PCR missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "SPShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "SPAbs / TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "BullShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "(BCAbs+SPAbs)/TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "BearShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "(BPAbs+SCAbs)/TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "IntentRatio": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "BearShare/BullShare",
    "units": "ratio",
    "sign": "higher=more bearish-side GEXDelta share",
    "rounding": "none",
    "null": "DATA_ERROR if BullShare=0",
    "lookback": "D0",
    "current_included": true
  },
  "IntentChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "100*(IntentRatio_D0/IntentRatio_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "rounding": "none",
    "null": "DATA_ERROR if prior ratio missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "PutBuyShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "BPAbs/(BPAbs+SPAbs)",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if denominator=0",
    "lookback": "D0",
    "current_included": true
  },
  "PutBuyShareChange": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPXW.US",
    "formula": "PutBuyShare_D0 - PutBuyShare_previous_XNYS_GEX_observation",
    "units": "fraction points",
    "sign": "negative=put-buy share collapsed",
    "rounding": "none",
    "null": "DATA_ERROR if prior missing",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "AbsPriceMove": {
    "source": "derived",
    "formula": "abs(CloseChangePct)",
    "units": "percentage points",
    "rounding": "none",
    "null": "propagate",
    "lookback": "D0"
  },
  "AbsPutBuyShareChange": {
    "source": "derived",
    "formula": "abs(PutBuyShareChange)",
    "units": "fraction points",
    "rounding": "none",
    "null": "propagate",
    "lookback": "D0"
  },
  "CausalQuantile60": {
    "source": "derived history",
    "formula": "For any named feature X, threshold Pq uses only the 60 prior valid XNYS observations, current D0 excluded. Sort the 60 prior valid values ascending. Use linear quantile (Hyndman-Fan type 7): h=(60-1)*0.5; j=floor(h); g=h-j; threshold=x[j]+g*(x[j+1]-x[j]). Current observation is excluded.",
    "units": "same as X",
    "rounding": "none",
    "null": "INSUFFICIENT_HISTORY until 60 prior valid values exist",
    "lookback": "60 prior valid observations",
    "minimum_observations": 60,
    "current_included": false,
    "tie_behavior": "Signal predicates use the written <=, <, >= or > exactly; no epsilon and no pre-rounding.",
    "duplicate_behavior": "Duplicate capital-type row fails readiness.",
    "late_corrected": "New canonical source hash creates a new revision and reevaluation.",
    "future_information_proof": "Every rolling input is filtered ObservationDate < D0 before tail(60); D1/D2 prices are outcome-only and never used in D0 trigger calculation."
  },
  "SC_GEX_Level": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType where ASXCode=SPXW.US and CapitalType=SC",
    "column": "GEX",
    "formula": "raw SC GEX level (not GEXDelta)",
    "units": "GEX level units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SC_GEX_Median60": {
    "source": "SC_GEX_Level history",
    "formula": "median of exactly 60 prior valid SC GEX levels; current excluded; linear P50 equals median for 60 sorted values",
    "units": "GEX level units",
    "rounding": "none",
    "null": "INSUFFICIENT_HISTORY until 60 prior values",
    "lookback": "60 prior XNYS observations",
    "current_included": false,
    "tie_behavior": "SC_LOW is true when current <= threshold."
  },
  "Prior5D_NQ_Return": {
    "source": "NQMain 30-minute continuous proxy",
    "formula": "NQ cash-session D0 close / NQ cash-session close five XNYS sessions before D0 - 1",
    "units": "fraction",
    "sign": "<=0 defines REVERSAL_GREEN; >0 defines NORMAL_GREEN",
    "rounding": "none",
    "null": "DATA_ERROR / NOT_READY for trading if source unavailable",
    "lookback": "5 prior XNYS cash sessions",
    "current_included": true,
    "future_information_proof": "Uses D0 and earlier closes only."
  }
}
```

### Worked actionable-rule examples

See `deterministic-fixtures.json`; it includes TRUE, FALSE, missing, stale/NOT_READY, tie, boundary, missing-bar, correction and idempotency branches.

## 5. Readiness contract

```json
{
  "runtime_frequency": "every 2 minutes",
  "source_database": "StockDB_US",
  "source_schema": "Transform",
  "source_table": "OptionGEXChangeCapitalType",
  "query_identity": "SELECT ObservationDate, ASXCode, GEXDelta, CapitalType, Close, VWAP, NoOfOption, GEX FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK) WHERE ASXCode='SPXW.US' ORDER BY ObservationDate, CapitalType",
  "expected_completed_session": "On an XNYS action date D1, expected D0 = previous XNYS cash session.",
  "required_columns": [
    "ObservationDate",
    "ASXCode",
    "CapitalType",
    "GEXDelta",
    "Close",
    "GEX"
  ],
  "component_checks": [
    "Exactly one BC, one BP, one SC and one SP row for D0.",
    "No duplicate CapitalType row for D0.",
    "All required numeric fields finite.",
    "Close values across BC/BP/SC/SP must be identical to 1e-9.",
    "sum(abs(GEXDelta of BC,BP,SC,SP)) > 0.",
    "Previous XNYS session must also have exactly BC/BP/SC/SP before any percent-change rule is evaluated."
  ],
  "refresh_marker": "Canonical D0 row hash must be identical on two consecutive 2-minute heartbeats, second heartbeat no later than 03:28:00 America/New_York; hash = SHA256 of UTF-8 canonical JSON sorted by CapitalType containing ObservationDate,ASXCode,CapitalType,GEXDelta,GEX,Close,VWAP,NoOfOption.",
  "decision_time": "03:30 America/New_York",
  "open_interest_or_revision_marker": "OPEN_INTEREST_NOT_APPLICABLE: this strategy consumes GEX/GEXDelta capital-type rows and does not use an open-interest field. The canonical four-row SHA-256 is the revision marker.",
  "timezone_normalization": "ObservationDate is interpreted as XNYS market date. Scheduler and timestamps use IANA America/New_York; UI/runtime display may additionally use Australia/Sydney.",
  "stale_data_threshold": "If D0 != previous XNYS session or stable second heartbeat occurs after 03:28:00, readiness fails for that action date.",
  "missing_or_partial": "Return NOT_READY. Create no Observation, Signal, report, paper plan or notification.",
  "revised_data": "Any byte-level change to canonical D0 component values changes source_revision. Re-run evaluation. Preserve prior immutable report and mark it superseded. Recompute any non-final outcome; finalized outcomes are recomputed only under explicit SOURCE_CORRECTION workflow.",
  "idempotency": "For unchanged source_revision and scheduled action date, reuse the existing evaluation/report/signal; do not create duplicates.",
  "not_ready_vs_no_signal": "NOT_READY is a runtime readiness status and is not a Signal. NO_SIGNAL is emitted only after readiness passes and rule evaluation finds no signal."
}
```

The row revision is a canonical SHA-256 of the four component rows. Two identical consecutive 2-minute heartbeats are required. A changed hash is a new revision. Before ready: no Observation, Signal, report, plan or notification.

## 6. Historical performance

Historical research and future production-paper outcomes are separate datasets. Per-actionable-signal details, denominator rules, costs, holding bars, MFE/MAE and confidence intervals are in `historical-performance.json`; instances are in `per-instance-ledger.json` when available.

```json
{
  "strategy_code": "SPX_GEX_QQQ_V1",
  "version_code": "1.0.2-contract",
  "status": "AVAILABLE_WITH_RECONCILIATION_BLOCKER",
  "overall_reference": {
    "initial_capital": 100000,
    "ending_nav": 156341.09184719878,
    "total_return_pct": 56.34109184719878,
    "trade_count_portfolio": 59,
    "win_rate_pct_portfolio": 79.66101694915254,
    "profit_factor_portfolio": 3.0667296962976534,
    "realized_exit_to_exit_max_drawdown_pct": 6.082286639672733,
    "mark_to_market_max_drawdown_pct": 11.511323163765875,
    "note": "Quoted from prior common-warmup v1.0.2 artifact; cannot be independently regenerated in this packet without NQMain raw data."
  },
  "signals": {
    "SPX_STRONG_YELLOW": {
      "status": "AVAILABLE_WITH_RECONCILIATION_BLOCKER",
      "as_of": "2026-08-06T23:59:59-04:00",
      "source_date_range": {
        "start": "2025-03-06",
        "end": "2026-08-06"
      },
      "eligible_sample_definition": "Candidate classifications from the prior SPX GEX v1.0.2 common-warmup backtest artifact, using NQMain percentage path proxy for QQQ. Portfolio-independent candidate outcomes are quoted here.",
      "total_eligible_dates": 352,
      "number_of_signal_instances": 10,
      "wins": 8,
      "losses": 2,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 80.0,
      "win_rate_denominator": 10,
      "gross_profit_return_units": 6.813822056424438,
      "gross_loss_return_units": 2.000000000000008,
      "profit_factor": 3.406911028212205,
      "return_units": "percentage points of theoretical NQ-percentage-path proxy return",
      "average_return_pct": 0.4813822056424429,
      "median_return_pct": "NOT_AVAILABLE",
      "holding_period_distribution_bars": "NOT_AVAILABLE",
      "maximum_adverse_excursion": "NOT_AVAILABLE",
      "maximum_favourable_excursion": "NOT_AVAILABLE",
      "transaction_costs": {
        "commission": "0 in referenced backtest",
        "slippage": "0 / NOT MODELED in referenced backtest"
      },
      "position_sizing": "Candidate stats use one theoretical unit; portfolio backtest used 100% shadow NAV exposure.",
      "treatment_of_overlapping_signals": "Candidate stats include all independently eligible candidates. Portfolio results separately enforced EXISTING_POSITION_PRIORITY.",
      "treatment_of_repeated_same_day_signals": "One classification per ObservationDate.",
      "candidate_inclusion": "All candidates for this signal code, not only portfolio-entered candidates.",
      "sample_size_limitations": "Small samples and in-sample/selection risk; forward-paper validation required.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 49.01624715366418,
        "upper_pct": 94.33178485456247
      },
      "backtest_engine_and_version": "prior SPX GEX v1.0.2 common-warmup artifact; executable engine build hash NOT_AVAILABLE",
      "source_snapshot_hash": "NOT_AVAILABLE",
      "per_instance_ledger_reference": "per-instance-ledger.json (records unavailable in current runtime; blocker explained there)"
    },
    "SPX_RELIABLE_YELLOW": {
      "status": "AVAILABLE_WITH_RECONCILIATION_BLOCKER",
      "as_of": "2026-08-06T23:59:59-04:00",
      "source_date_range": {
        "start": "2025-03-06",
        "end": "2026-08-06"
      },
      "eligible_sample_definition": "Candidate classifications from the prior SPX GEX v1.0.2 common-warmup backtest artifact, using NQMain percentage path proxy for QQQ. Portfolio-independent candidate outcomes are quoted here.",
      "total_eligible_dates": 352,
      "number_of_signal_instances": 21,
      "wins": 18,
      "losses": 3,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 85.71428571428571,
      "win_rate_denominator": 21,
      "gross_profit_return_units": 7.200000000000026,
      "gross_loss_return_units": 2.400000000000001,
      "profit_factor": 3.0000000000000098,
      "return_units": "percentage points of theoretical NQ-percentage-path proxy return",
      "average_return_pct": 0.22857142857142976,
      "median_return_pct": "NOT_AVAILABLE",
      "holding_period_distribution_bars": "NOT_AVAILABLE",
      "maximum_adverse_excursion": "NOT_AVAILABLE",
      "maximum_favourable_excursion": "NOT_AVAILABLE",
      "transaction_costs": {
        "commission": "0 in referenced backtest",
        "slippage": "0 / NOT MODELED in referenced backtest"
      },
      "position_sizing": "Candidate stats use one theoretical unit; portfolio backtest used 100% shadow NAV exposure.",
      "treatment_of_overlapping_signals": "Candidate stats include all independently eligible candidates. Portfolio results separately enforced EXISTING_POSITION_PRIORITY.",
      "treatment_of_repeated_same_day_signals": "One classification per ObservationDate.",
      "candidate_inclusion": "All candidates for this signal code, not only portfolio-entered candidates.",
      "sample_size_limitations": "Small samples and in-sample/selection risk; forward-paper validation required.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 65.36393971937906,
        "upper_pct": 95.01898750027473
      },
      "backtest_engine_and_version": "prior SPX GEX v1.0.2 common-warmup artifact; executable engine build hash NOT_AVAILABLE",
      "source_snapshot_hash": "NOT_AVAILABLE",
      "per_instance_ledger_reference": "per-instance-ledger.json (records unavailable in current runtime; blocker explained there)"
    },
    "SPX_REVERSAL_GREEN": {
      "status": "AVAILABLE_WITH_RECONCILIATION_BLOCKER",
      "as_of": "2026-08-06T23:59:59-04:00",
      "source_date_range": {
        "start": "2025-03-06",
        "end": "2026-08-06"
      },
      "eligible_sample_definition": "Candidate classifications from the prior SPX GEX v1.0.2 common-warmup backtest artifact, using NQMain percentage path proxy for QQQ. Portfolio-independent candidate outcomes are quoted here.",
      "total_eligible_dates": 352,
      "number_of_signal_instances": 42,
      "wins": 33,
      "losses": 9,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 78.57142857142857,
      "win_rate_denominator": 42,
      "gross_profit_return_units": 80.84840045255932,
      "gross_loss_return_units": 19.55002738770314,
      "profit_factor": 4.135462260447396,
      "return_units": "percentage points of theoretical NQ-percentage-path proxy return",
      "average_return_pct": 1.4594850729727662,
      "median_return_pct": "NOT_AVAILABLE",
      "holding_period_distribution_bars": "NOT_AVAILABLE",
      "maximum_adverse_excursion": "NOT_AVAILABLE",
      "maximum_favourable_excursion": "NOT_AVAILABLE",
      "transaction_costs": {
        "commission": "0 in referenced backtest",
        "slippage": "0 / NOT MODELED in referenced backtest"
      },
      "position_sizing": "Candidate stats use one theoretical unit; portfolio backtest used 100% shadow NAV exposure.",
      "treatment_of_overlapping_signals": "Candidate stats include all independently eligible candidates. Portfolio results separately enforced EXISTING_POSITION_PRIORITY.",
      "treatment_of_repeated_same_day_signals": "One classification per ObservationDate.",
      "candidate_inclusion": "All candidates for this signal code, not only portfolio-entered candidates.",
      "sample_size_limitations": "Small samples and in-sample/selection risk; forward-paper validation required.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 64.0601546836771,
        "upper_pct": 88.29420012399696
      },
      "backtest_engine_and_version": "prior SPX GEX v1.0.2 common-warmup artifact; executable engine build hash NOT_AVAILABLE",
      "source_snapshot_hash": "NOT_AVAILABLE",
      "per_instance_ledger_reference": "per-instance-ledger.json (records unavailable in current runtime; blocker explained there)"
    },
    "SPX_NORMAL_GREEN": {
      "status": "AVAILABLE_WITH_RECONCILIATION_BLOCKER",
      "as_of": "2026-08-06T23:59:59-04:00",
      "source_date_range": {
        "start": "2025-03-06",
        "end": "2026-08-06"
      },
      "eligible_sample_definition": "Candidate classifications from the prior SPX GEX v1.0.2 common-warmup backtest artifact, using NQMain percentage path proxy for QQQ. Portfolio-independent candidate outcomes are quoted here.",
      "total_eligible_dates": 352,
      "number_of_signal_instances": 25,
      "wins": 18,
      "losses": 7,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 72.0,
      "win_rate_denominator": 25,
      "gross_profit_return_units": 23.709459314633282,
      "gross_loss_return_units": 10.925330097999662,
      "profit_factor": 2.170136655090567,
      "return_units": "percentage points of theoretical NQ-percentage-path proxy return",
      "average_return_pct": 0.5113651686653449,
      "median_return_pct": "NOT_AVAILABLE",
      "holding_period_distribution_bars": "NOT_AVAILABLE",
      "maximum_adverse_excursion": "NOT_AVAILABLE",
      "maximum_favourable_excursion": "NOT_AVAILABLE",
      "transaction_costs": {
        "commission": "0 in referenced backtest",
        "slippage": "0 / NOT MODELED in referenced backtest"
      },
      "position_sizing": "Candidate stats use one theoretical unit; portfolio backtest used 100% shadow NAV exposure.",
      "treatment_of_overlapping_signals": "Candidate stats include all independently eligible candidates. Portfolio results separately enforced EXISTING_POSITION_PRIORITY.",
      "treatment_of_repeated_same_day_signals": "One classification per ObservationDate.",
      "candidate_inclusion": "All candidates for this signal code, not only portfolio-entered candidates.",
      "sample_size_limitations": "Small samples and in-sample/selection risk; forward-paper validation required.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 52.423394809638424,
        "upper_pct": 85.71614614904344
      },
      "backtest_engine
```

## 7. Asynchronous production outcome

```json
{
  "required_source": "NQMain 30-minute source identity/hash NOT_AVAILABLE.",
  "source_status": "NOT_AVAILABLE",
  "source_instrument": "NQMain percentage-path proxy for QQQ",
  "bar_frequency": "30 minutes or finer; the supplied historical contract uses 30-minute bars.",
  "required_columns": [
    "TimeIntervalStart",
    "Open",
    "High",
    "Low",
    "Close"
  ],
  "timezone": "America/New_York",
  "reference_entry_price": "D1/D3 03:30 NQMain bar Open or Green dip logic",
  "exit_price_rules": {
    "Yellow": "TP/SL first touch with no scheduled exit",
    "Reversal Green": "D5 cash close",
    "Normal Green": "2.5% TP or D5 cash close"
  },
  "holding_horizon": "Per signal definition.",
  "pending_rule": "Outcome remains PENDING until entry bar and every bar needed to prove an earlier terminal condition through the scheduled terminal bar exist. Missing required bars do not imply no hit.",
  "market_closed": "Remain PENDING until the next required XNYS/futures data is published; never synthesize a price.",
  "missing_bar": "PENDING plus MISSING_REQUIRED_BAR audit flag; do not forward-fill OHLC.",
  "correction": "Every market-bar snapshot has a revision hash. If finalized source bars change under explicit SOURCE_CORRECTION, calculate a new outcome revision, preserve the old finalized record as superseded, and link both revisions.",
  "gap_rule": "If an active stop/limit is already crossed by a bar Open, fill at Open; otherwise fill at the specified level when High/Low touches it. Time exits use terminal bar Close.",
  "opposing_signal": "Does not change an already-triggered production outcome unless the signal definition explicitly has an opposing-signal exit. These versions do not, except SPX portfolio admission prevents overlapping plans before entry.",
  "return_formula": "LONG gross=(exit/entry-1)*100. SHORT gross=(entry-exit)/entry*100. Net return = gross return - modeled round-trip slippage/cost percentage points.",
  "costs_slippage": "Referenced v1.0.2 historical backtest modeled no slippage/cost; future paper outcome cost model is NOT_AVAILABLE pending review.",
  "direction_convention": "Positive return_pct is profitable in the signal direction.",
  "calculation_version": "production_outcome_v1.0.0",
  "manual_independence": "Outcome worker MUST NOT read TradePlan.ActualEntry, ActualExit, ActualQuantity or broker/manual trade records.",
  "idempotency": "Key = strategy/version/market_date/signal_code/source_revision/calculation_version. Repeated runs reuse the same PENDING/FINAL record."
}
```

## 8. Production / Pushover policy

```json
{
  "mode": "NOTIFICATION_ONLY",
  "broker_execution": "HARD_DISABLED",
  "manual_trade_required_for_outcome": false,
  "deployment_state": "SHADOW_DISABLED_FOR_PUSH",
  "recipient": "STRATEGY_OWNER logical recipient; deployment resolves PUSHOVER_USER_KEY from secret storage, never from strategy files.",
  "pushover": {
    "enabled": false,
    "priority": 0,
    "channel": "Pushover"
  },
  "report_link_format": "runtime_authenticated_origin + \"/strategy-reports/\" + immutable_public_report_id; authentication flow must preserve this return path. No auth token is embedded in the URL.",
  "retry_policy": "Transactional outbox. Retry explicit HTTP non-2xx at +30s, +2m and +5m. On network timeout/unknown acknowledgement, do NOT blind-retry; mark DELIVERY_UNKNOWN for operator reconciliation to avoid duplicate pushes.",
  "deduplication_key": "SHA256(strategy_code|version_code|market_date|signal_code|source_revision|notification_kind)",
  "enablement_change_control": "Enablement is deployment/version-specific. Any logic/source/exit change creates a new version; enabling push requires human approval and audit event DEPLOYMENT_CHANGED.",
  "notification_title_format": "{display_name} | {signal_code} | {direction} {subject_code}",
  "notification_body_format": "Market date={market_date}; signal={signal_code}; confidence={confidence_label}; planned entry={entry_policy}; exit={exit_summary}; source revision={source_revision}; report={report_link}. No broker order is submitted.",
  "secrets": "PUSHOVER_USER_KEY and PUSHOVER_API_TOKEN exist only in secret storage; never reports, notifications, JSON or logs."
}
```

Broker execution is a hard invariant: no broker adapter, order submission, order modification, or broker-derived Actual* field is permitted in the outcome path.

## 9. Reports and audit

```json
{
  "report": {
    "kind": "STRATEGY_EVALUATION_HTML",
    "title_format": "{display_name} \u2014 {market_date} \u2014 {signal_code}",
    "market_date": "D0 ObservationDate",
    "required_fields": [
      "strategy_code",
      "version_code",
      "market_date",
      "source_revision",
      "signal_code",
      "decision_inputs",
      "trigger_result",
      "entry_rule",
      "exit_rule",
      "provenance",
      "human_explanation"
    ],
    "immutable_public_report_id": "UUIDv7 generated once after evaluation; report body is immutable. Corrections create a new report ID that references superseded_report_id."
  },
  "audit_events": [
    "STRATEGY_REGISTERED",
    "DEPLOYMENT_CHANGED",
    "STRATEGY_ENABLED",
    "STRATEGY_DISABLED",
    "SOURCE_NOT_READY",
    "SOURCE_READY",
    "EVALUATION_COMPLETED",
    "REPORT_CREATED",
    "NOTIFICATION_ENQUEUED",
    "NOTIFICATION_DELIVERED",
    "NOTIFICATION_FAILED",
    "NOTIFICATION_DELIVERY_UNKNOWN",
    "OUTCOME_PENDING",
    "OUTCOME_FINALIZED",
    "SOURCE_CORRECTION",
    "OUTCOME_SUPERSEDED"
  ],
  "audit_security": "Never include passwords, API keys, Pushover tokens, connection strings, or authentication cookies."
}
```

## 10. Provenance and hashes

Source manifest: `source-manifest.json`  
Source snapshot hash: `277d6d50ea1ea4609626726b9441a01dca9085dc11b1b300fd76811e8a1a865b`  
Implementation hash: `c9d3c8b3eca9849b942235e7354ff38c1384648ef70e64533b93d61ffbe70c57`

## 11. Acceptance status and unresolved items

```json
{
  "status": "REVIEW_READY",
  "criteria": {
    "signals_defined": "PASS",
    "exact_triggers": "PASS",
    "explicit_exits": "PASS",
    "variables_specified": "PASS",
    "refresh_gate": "PASS",
    "historical_stats_actionable": "PARTIAL",
    "ledger_reconciliation": "FAIL_BLOCKED",
    "manual_independent_outcomes": "PASS_BY_CONTRACT",
    "notification_only": "PASS",
    "broker_disabled": "PASS",
    "fixtures": "PASS",
    "hashes": "PARTIAL"
  },
  "blockers_to_implementation": [
    "NQMain raw historical/prod 30-minute source identity and SHA-256 are NOT_AVAILABLE.",
    "Full per-instance v1.0.2 ledger is NOT_AVAILABLE, so historical aggregate metrics cannot be reconciled instance-by-instance in this packet.",
    "Future SPX paper cost/slippage convention is not frozen; prior backtest modeled zero.",
    "Production QQQ 03:30 executable-price historical source identity is NOT_AVAILABLE; NQ percentage proxy remains the defined research proxy."
  ]
}
```

**Critical SPX limitation.** Aggregate v1.0.2 results are preserved from the prior backtest artifact, but the NQMain raw source and full ledger are not available in this runtime. This packet must not be promoted to IMPLEMENTABLE until those are mounted and reconciled.
