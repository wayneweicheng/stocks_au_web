# SPY GEX Intent & SP-Share Strategy

**Strategy code:** `SPY_GEX_INTENT_V1`  
**Version:** `1.0.0`  
**Status:** `IMPLEMENTABLE`  
**Implementation key:** `spy_gex_intent_v1_0_0`  
**Owner:** `US_STOCKS_INDEXES_STRATEGY_RESEARCH`  
**Research date:** 2026-08-16  
**Superseded strategy/version:** `NONE`

## 1. Identity and rationale

**Purpose.** Generate deterministic notification-only SPY paper plans from daily capital-type GEXDelta composition.

**Rationale.** Tests whether price direction, change in all-four-capital-type intent, and sell-put share identify short-horizon momentum/reversal regimes.

**Change summary.** Initial frozen contract from causal SPY GEX/intent screening; implementable as notification-only with explicit deployment enablement and broker execution disabled. Any logic, source dependency, threshold, entry time, exit, slippage or enablement change requires a new version.

**Validation method.** Causal 60-observation features; chronological train 2025-10-20..2026-03-31 and robustness validation 2026-04-01..2026-08-13; validation is not strict OOS because it was inspected during rule selection.

**Known limitations.** ["No untouched OOS window", "Multiple-testing/data-snooping risk from broad hypothesis screen", "Production 30-minute bar availability and refresh SLA must be monitored", "Small signal samples"]

**Research window.** `2025-10-20` through `2026-08-13`.  
**Strict out-of-sample window.** `NOT_AVAILABLE` to `NOT_AVAILABLE` — No untouched post-selection holdout exists; the temporal validation segment was inspected during rule selection and is robustness evidence, not strict OOS.

**Bias controls.** Causal thresholds always exclude D0 and use only the 60 prior valid observations. D1+ prices are outcome-only. Symbols are fixed before each strategy run, so no dynamic survivor universe is used. No corporate-universe survivorship adjustment is needed for a single fixed subject, but delisting/corporate-action history would still need adjustment if the subject changed. Data snooping/multiple testing is explicitly disclosed; SPY remains notification-only and broker-disabled while forward-paper results are monitored. Selection bias is controlled operationally by logging every evaluated date after readiness and by computing historical candidate stats without manual-trade filtering.

## 2. Instruments

```json
[
  {
    "role": "SUBJECT",
    "code": "SPY.US",
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
    "code": "SPY.US",
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
    "role": "EXECUTION",
    "code": "SPY.US",
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
| 1 | `DATA_ERROR` | any_required_derived_feature_is_invalid | NONE | NONE | NONE | NONE | no |
| 2 | `INSUFFICIENT_HISTORY` | required_prior_valid_count < 60 | NONE | NONE | NONE | NONE | no |
| 10 | `SPY_LOW_SP_MOMENTUM_LONG` | continuity == true AND CloseChangePct > 0.10 AND IntentChangePct > 10.0 AND SPShare <= P35_SPShare_60 | LONG | PLAN_ENTRY | If source readiness passed by 07:28 ET, plan LONG SPY at D1 07:30 ET 30-minute bar Open / first executable quote consistent with that Open convention. If the entry bar is missing, keep the paper plan/outcome ENTRY_UNRESOLVED/PENDING and do not synthesize a fill. | Scheduled: D1 15:30 30-minute bar Close (cash close).; No take-profit.; No stop-loss.; No opposing-signal exit. | yes |
| 20 | `SPY_FEAR_EXPANSION_REVERSAL_LONG` | continuity == true AND CloseChangePct < -0.10 AND IntentChangePct > 10.0 AND SPShare >= P65_SPShare_60 | LONG | PLAN_ENTRY | If readiness passed by 07:28 ET, plan LONG SPY at D1 07:30 ET 30-minute bar Open. | Scheduled D2 15:30 30-minute bar Close.; No take-profit.; No stop-loss.; No opposing-signal exit. | yes |
| 30 | `SPY_HIGH_GEX_MOMENTUM_WATCH` | continuity == true AND CloseChangePct > 0.10 AND PCRChangePct > 10.0 AND TotalAbsGEXDelta >= P65_TotalAbs_60 | LONG | WATCH | NONE | NONE | no |
| 40 | `SPY_BEARISH_CONTINUATION_WATCH` | continuity == true AND CloseChangePct < -0.10 AND PCRChangePct < -5.0 | SHORT | WATCH | NONE | NONE | no |
| 999 | `NO_SIGNAL` | NOT(any higher-precedence condition) | NONE | NONE | NONE | NONE | no |

When no predicate matches after readiness/history/data-error gates, emit `NO_SIGNAL`, create a non-actionable report/signal record, create no paper plan, and send no Pushover notification. `NOT_READY` occurs before evaluation and creates no records.

## 4. Feature and formula contract

All decisions use full-precision values. Rounding is display-only. Quantiles use exactly the 60 prior valid observations, D0 excluded, with linear Hyndman-Fan type-7 interpolation. Duplicate capital-type rows fail readiness. Missing denominators are data errors; values are never imputed. Corrected rows change `source_revision` and force reevaluation.

```json
{
  "BCAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "column": "GEXDelta where CapitalType=BC",
    "formula": "abs(BC_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none for decisions; display only",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "BPAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "column": "GEXDelta where CapitalType=BP",
    "formula": "abs(BP_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SCAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "column": "GEXDelta where CapitalType=SC",
    "formula": "abs(SC_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SPAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "column": "GEXDelta where CapitalType=SP",
    "formula": "abs(SP_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "TotalAbsGEXDelta": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
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
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "BPAbs / BCAbs",
    "units": "ratio",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if BCAbs=0",
    "lookback": "D0",
    "current_included": true
  },
  "CloseChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
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
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "100*(PCR_D0 / PCR_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "sign": "positive=PCR rose; negative=PCR fell",
    "rounding": "none",
    "null": "DATA_ERROR if previous PCR missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "SPShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "SPAbs / TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "BullShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "(BCAbs+SPAbs)/TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "BearShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "(BPAbs+SCAbs)/TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "IntentRatio": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "BearShare/BullShare",
    "units": "ratio",
    "sign": "higher=more bearish-side GEXDelta share",
    "rounding": "none",
    "null": "DATA_ERROR if BullShare=0",
    "lookback": "D0",
    "current_included": true
  },
  "IntentChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "100*(IntentRatio_D0/IntentRatio_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "rounding": "none",
    "null": "DATA_ERROR if prior ratio missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "PutBuyShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
    "formula": "BPAbs/(BPAbs+SPAbs)",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if denominator=0",
    "lookback": "D0",
    "current_included": true
  },
  "PutBuyShareChange": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=SPY.US",
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
  "query_identity": "SELECT ObservationDate, ASXCode, GEXDelta, CapitalType, Close, VWAP, NoOfOption, GEX FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK) WHERE ASXCode='SPY.US' ORDER BY ObservationDate, CapitalType",
  "expected_completed_session": "On an XNYS action date D1, expected D0 = previous XNYS cash session.",
  "required_columns": [
    "ObservationDate",
    "ASXCode",
    "CapitalType",
    "GEXDelta",
    "Close"
  ],
  "component_checks": [
    "Exactly one BC, one BP, one SC and one SP row for D0.",
    "No duplicate CapitalType row for D0.",
    "All required numeric fields finite.",
    "Close values across BC/BP/SC/SP must be identical to 1e-9.",
    "sum(abs(GEXDelta of BC,BP,SC,SP)) > 0.",
    "Previous XNYS session must also have exactly BC/BP/SC/SP before any percent-change rule is evaluated."
  ],
  "refresh_marker": "Canonical D0 row hash must be identical on two consecutive 2-minute heartbeats, second heartbeat no later than 07:28:00 America/New_York; hash = SHA256 of UTF-8 canonical JSON sorted by CapitalType containing ObservationDate,ASXCode,CapitalType,GEXDelta,GEX,Close,VWAP,NoOfOption.",
  "decision_time": "07:30 America/New_York",
  "open_interest_or_revision_marker": "OPEN_INTEREST_NOT_APPLICABLE: this strategy consumes GEX/GEXDelta capital-type rows and does not use an open-interest field. The canonical four-row SHA-256 is the revision marker.",
  "timezone_normalization": "ObservationDate is interpreted as XNYS market date. Scheduler and timestamps use IANA America/New_York; UI/runtime display may additionally use Australia/Sydney.",
  "stale_data_threshold": "If D0 != previous XNYS session or stable second heartbeat occurs after 07:28:00, readiness fails for that action date.",
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
  "strategy_code": "SPY_GEX_INTENT_V1",
  "version_code": "1.0.0",
  "historical_vs_production_separation": "These are historical research outcomes. Future simulated production outcomes MUST be stored separately and must never be merged with this file.",
  "signals": {
    "SPY_LOW_SP_MOMENTUM_LONG": {
      "status": "AVAILABLE",
      "as_of": "2026-08-14T16:00:00-04:00",
      "source_date_range": {
        "start": "2025-10-20",
        "end": "2026-08-13"
      },
      "eligible_sample_definition": "Dates in the research window with a complete current GEX observation, immediate-prior XNYS GEX observation, at least 60 prior valid observations for every threshold used, and all required entry/terminal 30-minute bars.",
      "total_eligible_dates": 189,
      "number_of_signal_instances": 22,
      "wins": 17,
      "losses": 5,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 77.27272727272727,
      "win_rate_denominator": 22,
      "win_rule": "return_pct > 0 after modeled slippage; return_pct <= 0 is a loss. Unresolved instances are excluded from the denominator.",
      "gross_profit_return_units": 9.6669871357575,
      "gross_loss_return_units": 2.2525046055017808,
      "profit_factor": 4.291661429746123,
      "return_units": "percentage points of entry notional, net of specified slippage and before taxes; no commissions unless listed.",
      "average_return_pct": 0.33702193319344176,
      "median_return_pct": 0.37153305931213476,
      "holding_period_distribution_bars": {
        "min": 17,
        "median": 17.0,
        "max": 17
      },
      "maximum_adverse_excursion": {
        "average_pct": -0.3091153022834596,
        "worst_pct": -1.3321991378191789
      },
      "maximum_favourable_excursion": {
        "average_pct": 0.6642602578992386,
        "best_pct": 1.9690467706703574
      },
      "entry_rule": "D1 07:30 America/New_York 30-minute bar Open",
      "exit_rule": "D1 15:30 bar Close; no TP and no SL.",
      "transaction_costs": "0 commission; 5 bps per side (10 bps round trip) modeled slippage",
      "position_sizing": "1.0 notional unit per independent signal",
      "treatment_of_overlapping_signals": "Independent signal-level research; no portfolio occupancy filter.",
      "treatment_of_repeated_same_day_signals": "One signal code can emit at most once per market date and source revision; duplicates are deduplicated by strategy/version/date/signal/revision.",
      "candidate_inclusion": "All independently eligible signal candidates are included. No manual-trade filter is used.",
      "sample_size_limitations": "Small samples; estimates are unstable and should be forward-paper validated. Historical selection may have multiple-testing risk as disclosed in strategy.md.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 56.56004682477829,
        "upper_pct": 89.87696001475148
      },
      "backtest_engine_and_version": "gex_contract_backtest_v1.0.0",
      "source_snapshot_hash": "6fb89d052f4c77b2a4dc7cb86f7994fcc29587c28f71f489933bdb15c75a0fe3",
      "per_instance_ledger_reference": "per-instance-ledger.json",
      "train_subperiod": {
        "start": "2025-10-20",
        "end": "2026-03-31",
        "instances": 8,
        "wins": 7,
        "losses": 1,
        "win_rate_pct": 87.5,
        "average_return_pct": 0.22511990980961666,
        "profit_factor": 3.5216607469710315
      },
      "validation_subperiod": {
        "start": "2026-04-01",
        "end": "2026-08-13",
        "instances": 14,
        "wins": 10,
        "losses": 4,
        "win_rate_pct": 71.42857142857143,
        "average_return_pct": 0.40096594655562745,
        "profit_factor": 4.649152166412163
      }
    },
    "SPY_FEAR_EXPANSION_REVERSAL_LONG": {
      "status": "AVAILABLE",
      "as_of": "2026-08-14T16:00:00-04:00",
      "source_date_range": {
        "start": "2025-10-20",
        "end": "2026-08-13"
      },
      "eligible_sample_definition": "Dates in the research window with a complete current GEX observation, immediate-prior XNYS GEX observation, at least 60 prior valid observations for every threshold used, and all required entry/terminal 30-minute bars.",
      "total_eligible_dates": 188,
      "number_of_signal_instances": 18,
      "wins": 14,
      "losses": 4,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 77.77777777777779,
      "win_rate_denominator": 18,
      "win_rule": "return_pct > 0 after modeled slippage; return_pct <= 0 is a loss. Unresolved instances are excluded from the denominator.",
      "gross_profit_return_units": 14.467826136757989,
      "gross_loss_return_units": 3.806254086334837,
      "profit_factor": 3.801066825438739,
      "return_units": "percentage points of entry notional, net of specified slippage and before taxes; no commissions unless listed.",
      "average_return_pct": 0.5923095583568417,
      "median_return_pct": 0.6157004753920449,
      "holding_period_distribution_bars": {
        "min": 49,
        "median": 49.0,
        "max": 49
      },
      "maximum_adverse_excursion": {
        "average_pct": -1.0298985214714216,
        "worst_pct": -2.830202980278007
      },
      "maximum_favourable_excursion": {
        "average_pct": 1.3056479616117729,
        "best_pct": 3.0512749530927863
      },
      "entry_rule": "D1 07:30 America/New_York 30-minute bar Open",
      "exit_rule": "D2 15:30 bar Close; no TP and no SL.",
      "transaction_costs": "0 commission; 5 bps per side (10 bps round trip) modeled slippage",
      "position_sizing": "1.0 notional unit per independent signal",
      "treatment_of_overlapping_signals": "Independent signal-level research; no portfolio occupancy filter.",
      "treatment_of_repeated_same_day_signals": "One signal code can emit at most once per market date and source revision; duplicates are deduplicated by strategy/version/date/signal/revision.",
      "candidate_inclusion": "All independently eligible signal candidates are included. No manual-trade filter is used.",
      "sample_size_limitations": "Small samples; estimates are unstable and should be forward-paper validated. Historical selection may have multiple-testing risk as disclosed in strategy.md.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 54.785415683787384,
        "upper_pct": 90.9990718913983
      },
      "backtest_engine_and_version": "gex_contract_backtest_v1.0.0",
      "source_snapshot_hash": "6fb89d052f4c77b2a4dc7cb86f7994fcc29587c28f71f489933bdb15c75a0fe3",
      "per_instance_ledger_reference": "per-instance-ledger.json",
      "train_subperiod": {
        "start": "2025-10-20",
        "end": "2026-03-31",
        "instances": 10,
        "wins": 8,
        "losses": 2,
        "win_rate_pct": 80.0,
        "average_return_pct": 0.5439840204607871,
        "profit_factor": 2.9170591482647494
      },
      "validation_subperiod": {
        "start": "2026-04-01",
        "end": "2026-08-13",
        "instances": 8,
        "wins": 6,
        "losses": 2,
        "win_rate_pct": 75.0,
        "average_return_pct": 0.6527164807269101,
        "profit_factor": 6.390688689733468
      }
    }
  },
  "methodology": {
    "market_dates": "XNYS",
    "entry_bar": "07:30 ET bar Open",
    "cash_close": "15:30 ET bar Close (bar interval start representing the cash-close half-hour)",
    "slippage": "5 bps per side",
    "commissions": "0",
    "manual_trades": "ignored",
    "source_hash": "6fb89d052f4c77b2a4dc7cb86f7994fcc29587c28f71f489933bdb15c75a0fe3"
  }
}
```

## 7. Asynchronous production outcome

```json
{
  "required_source": "StockDB_US.StockData.PriceHistoryTimeFrame where ASXCode='SPY.US' and TimeFrame='30M'; historical snapshot SPY-20251020-20260814.csv.",
  "source_status": "AVAILABLE_FOR_HISTORICAL_SNAPSHOT",
  "source_instrument": "SPY.US",
  "bar_frequency": "30 minutes or finer; the supplied historical contract uses 30-minute bars.",
  "required_columns": [
    "TimeIntervalStart",
    "Open",
    "High",
    "Low",
    "Close"
  ],
  "timezone": "America/New_York",
  "reference_entry_price": "D1 07:30 ET bar Open",
  "exit_price_rules": {
    "SPY_LOW_SP_MOMENTUM_LONG": "D1 15:30 bar Close",
    "SPY_FEAR_EXPANSION_REVERSAL_LONG": "D2 15:30 bar Close"
  },
  "holding_horizon": "Per signal definition.",
  "pending_rule": "Outcome remains PENDING until entry bar and every bar needed to prove an earlier terminal condition through the scheduled terminal bar exist. Missing required bars do not imply no hit.",
  "market_closed": "Remain PENDING until the next required XNYS/futures data is published; never synthesize a price.",
  "missing_bar": "PENDING plus MISSING_REQUIRED_BAR audit flag; do not forward-fill OHLC.",
  "correction": "Every market-bar snapshot has a revision hash. If finalized source bars change under explicit SOURCE_CORRECTION, calculate a new outcome revision, preserve the old finalized record as superseded, and link both revisions.",
  "gap_rule": "If an active stop/limit is already crossed by a bar Open, fill at Open; otherwise fill at the specified level when High/Low touches it. Time exits use terminal bar Close.",
  "opposing_signal": "Does not change an already-triggered production outcome unless the signal definition explicitly has an opposing-signal exit. These versions do not, except SPX portfolio admission prevents overlapping plans before entry.",
  "return_formula": "LONG gross=(exit/entry-1)*100. SHORT gross=(entry-exit)/entry*100. Net return = gross return - modeled round-trip slippage/cost percentage points.",
  "costs_slippage": "5 bps per side modeled historical/production-paper slippage; commission 0 in model.",
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
  "deployment_state": "LIVE_MANUAL_NOTIFICATION_ONLY",
  "recipient": "STRATEGY_OWNER logical recipient; deployment resolves PUSHOVER_USER_KEY from secret storage, never from strategy files.",
  "pushover": {
    "enabled": true,
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
Source snapshot hash: `6fb89d052f4c77b2a4dc7cb86f7994fcc29587c28f71f489933bdb15c75a0fe3`  
Implementation hash: `cf2bd6af01fd6a6811363d63dc05741daf9fa35634a72cdd82b91d5f9545e488`

## 11. Acceptance status and unresolved items

```json
{
  "status": "IMPLEMENTABLE",
  "criteria": {
    "signals_defined": "PASS",
    "exact_triggers": "PASS",
    "explicit_exits": "PASS",
    "variables_specified": "PASS",
    "refresh_gate": "PASS",
    "historical_stats_actionable": "PASS",
    "ledger_reconciliation": "PASS",
    "manual_independent_outcomes": "PASS",
    "notification_only": "PASS",
    "broker_disabled": "PASS",
    "fixtures": "PASS",
    "hashes": "PASS"
  },
  "blockers_to_implementation": [],
  "implementation_risks": [
    "No untouched strict out-of-sample period exists after rule selection; forward-paper results remain a research validation risk.",
    "Observed source-refresh SLA for SPY.US must be monitored to confirm the 07:28 ET two-heartbeat gate in production."
  ]
}
```

**Validation warning.** The SPY rules were selected after a broad causal screen; the displayed validation segment is not an untouched OOS sample. Continue forward-paper monitoring while the notification-only deployment is active.
