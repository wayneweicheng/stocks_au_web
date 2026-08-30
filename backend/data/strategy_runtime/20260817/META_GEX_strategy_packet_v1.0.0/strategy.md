# META GEX/PCR Continuation & Confirmation Strategy

**Strategy code:** `META_GEX_PCR_V1`  
**Version:** `1.0.0`  
**Status:** `IMPLEMENTABLE`  
**Implementation key:** `meta_gex_pcr_v1_0_0`  
**Owner:** `US_STOCKS_INDEXES_STRATEGY_RESEARCH`  
**Research date:** 2026-08-16  
**Superseded strategy/version:** `NONE; derived from META_GEX_research_baseline_2026-08-15 research memo`

## 1. Identity and rationale

**Purpose.** Notification-only META paper plans using causal GEXDelta/PCR regimes.

**Rationale.** META research showed a mild-decline continuation regime and a distinct low-SC bullish-confirmation regime; large-drop and exhaustion variants remain watch-only.

**Change summary.** Formalizes META continuation/confirmation research into deterministic notification-only rules and freezes a 2.5% emergency stop for the bearish D1 rule. Any logic, source dependency, threshold, entry time, exit, slippage or enablement change requires a new version.

**Validation method.** Causal 60-observation features plus chronological train/validation subperiod reporting; validation was inspected during research and is not claimed as untouched OOS.

**Known limitations.** ["No untouched OOS window", "Small samples", "Production 30-minute bar availability and refresh SLA must be monitored", "2.5% emergency stop is frozen for v1.0.0 and must be monitored during forward paper"]

**Research window.** `2025-10-20` through `2026-08-13`.  
**Strict out-of-sample window.** `NOT_AVAILABLE` to `NOT_AVAILABLE` — No untouched post-selection holdout. The validation segment was inspected during research.

**Bias controls.** Causal thresholds always exclude D0 and use only the 60 prior valid observations. D1+ prices are outcome-only. Symbols are fixed before each strategy run, so no dynamic survivor universe is used. No corporate-universe survivorship adjustment is needed for a single fixed subject, but delisting/corporate-action history would still need adjustment if the subject changed. Data snooping/multiple testing is explicitly disclosed; META remains notification-only and broker-disabled while forward-paper results are monitored. Selection bias is controlled operationally by logging every evaluated date after readiness and by computing historical candidate stats without manual-trade filtering.

## 2. Instruments

```json
[
  {
    "role": "SUBJECT",
    "code": "META.US",
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
    "code": "META.US",
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
    "code": "META.US",
    "market": "US",
    "exchange": "Nasdaq/US consolidated market",
    "currency": "USD",
    "timezone": "America/New_York",
    "market_date_convention": "QQQ market date follows XNYS session date.",
    "calendar": "XNYS",
    "holiday_handling": "No entries on non-XNYS sessions.",
    "daylight_saving_handling": "America/New_York.",
    "early_close_handling": "Time exits use official XNYS close."
  },
  {
    "role": "BENCHMARK",
    "code": "QQQ.US",
    "market": "US",
    "exchange": "Nasdaq/US consolidated market",
    "currency": "USD",
    "timezone": "America/New_York",
    "market_date_convention": "XNYS cash-session label",
    "calendar": "XNYS",
    "holiday_handling": "Skip non-sessions.",
    "daylight_saving_handling": "America/New_York.",
    "early_close_handling": "Use official XNYS early close."
  }
]
```

## 3. Executable signal catalogue

| Priority | Signal | Exact trigger | Direction | Action | Entry rule | Exit rule | Notify |
|---:|---|---|---|---|---|---|---|
| 1 | `DATA_ERROR` | any_required_derived_feature_is_invalid | NONE | NONE | NONE | NONE | no |
| 2 | `INSUFFICIENT_HISTORY` | required_prior_valid_count < 60 | NONE | NONE | NONE | NONE | no |
| 10 | `META_STRONG_BEARISH_CONTINUATION` | continuity == true AND CloseChangePct < -0.10 AND PCRChangePct < -5.0 AND AbsPriceMove <= P50_AbsPriceMove_60 | SHORT | PLAN_ENTRY | If fresh META GEX is stable by 07:28 ET, plan SHORT META at D1 07:30 ET bar Open. | Emergency stop: entry_price * 1.025; for short, if a bar Open >= stop, exit at Open; else if High >= stop, exit at stop.; If stop not hit, D1 15:30 bar Close.; No take-profit.; No opposing-signal exit. | yes |
| 20 | `META_STRONG_BULLISH_CONFIRMATION` | continuity == true AND CloseChangePct > 0.10 AND PCRChangePct < -5.0 AND SCAbs <= P40_SCAbs_60 | LONG | PLAN_ENTRY | If fresh META GEX is stable by 07:28 ET, plan LONG META at D1 07:30 ET bar Open. | Scheduled D2 15:30 bar Close.; No take-profit.; No stop-loss.; No opposing-signal exit. | yes |
| 30 | `META_STRONG_BEARISH_DIVERGENCE_WATCH` | continuity == true AND CloseChangePct > 0.10 AND PCRChangePct > 5.0 AND SPShare >= P65_SPShare_60 | SHORT | WATCH | NONE | NONE | no |
| 40 | `META_CROWDED_PUT_SELLING_EXHAUSTION_WATCH` | continuity == true AND PutBuyShareChange < 0 AND AbsPutBuyShareChange >= P75_AbsPutBuyShareChange_60 AND SPShare >= P65_SPShare_60 | SHORT | WATCH | NONE | NONE | no |
| 50 | `META_BULLISH_CONFIRMATION_WATCH` | continuity == true AND CloseChangePct > 0.10 AND PCRChangePct < -5.0 AND SCAbs > P40_SCAbs_60 | LONG | WATCH | NONE | NONE | no |
| 60 | `META_LARGE_DROP_REVERSAL_WATCH` | continuity == true AND CloseChangePct < -0.10 AND PCRChangePct < -5.0 AND AbsPriceMove > P50_AbsPriceMove_60 | NONE | WATCH | NONE | NONE | no |
| 70 | `META_FEAR_EXPANSION_REVERSAL_WATCH` | continuity == true AND CloseChangePct < -0.10 AND PCRChangePct > 5.0 | LONG | WATCH | NONE | NONE | no |
| 999 | `NO_SIGNAL` | NOT(any higher-precedence condition) | NONE | NONE | NONE | NONE | no |

When no predicate matches after readiness/history/data-error gates, emit `NO_SIGNAL`, create a non-actionable report/signal record, create no paper plan, and send no Pushover notification. `NOT_READY` occurs before evaluation and creates no records.

## 4. Feature and formula contract

All decisions use full-precision values. Rounding is display-only. Quantiles use exactly the 60 prior valid observations, D0 excluded, with linear Hyndman-Fan type-7 interpolation. Duplicate capital-type rows fail readiness. Missing denominators are data errors; values are never imputed. Corrected rows change `source_revision` and force reevaluation.

```json
{
  "BCAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "column": "GEXDelta where CapitalType=BC",
    "formula": "abs(BC_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none for decisions; display only",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "BPAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "column": "GEXDelta where CapitalType=BP",
    "formula": "abs(BP_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SCAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "column": "GEXDelta where CapitalType=SC",
    "formula": "abs(SC_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "SPAbs": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "column": "GEXDelta where CapitalType=SP",
    "formula": "abs(SP_GEXDelta)",
    "units": "GEXDelta absolute units",
    "rounding": "none",
    "null": "DATA_ERROR",
    "lookback": "D0",
    "current_included": true
  },
  "TotalAbsGEXDelta": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
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
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "BPAbs / BCAbs",
    "units": "ratio",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if BCAbs=0",
    "lookback": "D0",
    "current_included": true
  },
  "CloseChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
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
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "100*(PCR_D0 / PCR_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "sign": "positive=PCR rose; negative=PCR fell",
    "rounding": "none",
    "null": "DATA_ERROR if previous PCR missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "SPShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "SPAbs / TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "sign": "non-negative",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "BullShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "(BCAbs+SPAbs)/TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "BearShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "(BPAbs+SCAbs)/TotalAbsGEXDelta",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if total=0",
    "lookback": "D0",
    "current_included": true
  },
  "IntentRatio": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "BearShare/BullShare",
    "units": "ratio",
    "sign": "higher=more bearish-side GEXDelta share",
    "rounding": "none",
    "null": "DATA_ERROR if BullShare=0",
    "lookback": "D0",
    "current_included": true
  },
  "IntentChangePct": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "100*(IntentRatio_D0/IntentRatio_previous_XNYS_GEX_observation - 1)",
    "units": "percentage points",
    "rounding": "none",
    "null": "DATA_ERROR if prior ratio missing/zero",
    "lookback": "previous XNYS session",
    "current_included": true
  },
  "PutBuyShare": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
    "formula": "BPAbs/(BPAbs+SPAbs)",
    "units": "fraction 0..1",
    "rounding": "none",
    "null": "DATA_ERROR if denominator=0",
    "lookback": "D0",
    "current_included": true
  },
  "PutBuyShareChange": {
    "source": "StockDB_US.Transform.OptionGEXChangeCapitalType rows where ASXCode=META.US",
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
  "query_identity": "SELECT ObservationDate, ASXCode, GEXDelta, CapitalType, Close, VWAP, NoOfOption, GEX FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK) WHERE ASXCode='META.US' ORDER BY ObservationDate, CapitalType",
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
  "strategy_code": "META_GEX_PCR_V1",
  "version_code": "1.0.0",
  "historical_vs_production_separation": "Historical research only; future production-paper outcomes are stored separately.",
  "signals": {
    "META_STRONG_BEARISH_CONTINUATION": {
      "status": "AVAILABLE",
      "as_of": "2026-08-14T16:00:00-04:00",
      "source_date_range": {
        "start": "2025-10-20",
        "end": "2026-08-13"
      },
      "eligible_sample_definition": "Dates in the research window with a complete current GEX observation, immediate-prior XNYS GEX observation, at least 60 prior valid observations for every threshold used, and all required entry/terminal 30-minute bars.",
      "total_eligible_dates": 190,
      "number_of_signal_instances": 15,
      "wins": 12,
      "losses": 3,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 80.0,
      "win_rate_denominator": 15,
      "win_rule": "return_pct > 0 after modeled slippage; return_pct <= 0 is a loss. Unresolved instances are excluded from the denominator.",
      "gross_profit_return_units": 18.04639902574531,
      "gross_loss_return_units": 2.235607057959395,
      "profit_factor": 8.072258924704597,
      "return_units": "percentage points of entry notional, net of specified slippage and before taxes; no commissions unless listed.",
      "average_return_pct": 1.0540527978523946,
      "median_return_pct": 1.0326837285747867,
      "holding_period_distribution_bars": {
        "min": 17,
        "median": 17.0,
        "max": 17
      },
      "maximum_adverse_excursion": {
        "average_pct": -0.8271212915811349,
        "worst_pct": -2.2233161046845438
      },
      "maximum_favourable_excursion": {
        "average_pct": 2.1887183788775126,
        "best_pct": 5.472691725529773
      },
      "entry_rule": "D1 07:30 America/New_York 30-minute bar Open",
      "exit_rule": "2.5% adverse emergency stop first; otherwise D1 15:30 bar Close (the 15:30-16:00 cash-close bar).",
      "transaction_costs": {
        "commission": "0 modeled",
        "slippage": "10 bps per side, 20 bps round trip, deducted from return"
      },
      "position_sizing": "1.0 notional unit per independent signal",
      "treatment_of_overlapping_signals": "Independent signal-level research; no portfolio occupancy filter.",
      "treatment_of_repeated_same_day_signals": "One signal code can emit at most once per market date and source revision; duplicates are deduplicated by strategy/version/date/signal/revision.",
      "candidate_inclusion": "All independently eligible signal candidates are included. No manual-trade filter is used.",
      "sample_size_limitations": "Small samples; estimates are unstable and should be forward-paper validated. Historical selection may have multiple-testing risk as disclosed in strategy.md.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 54.81455128483065,
        "upper_pct": 92.95245065301843
      },
      "backtest_engine_and_version": "gex_contract_backtest_v1.0.0",
      "source_snapshot_hash": "30e3670c2e044e451ab8dea0434f35351b097509023026013e04e28cbdffa3b9",
      "per_instance_ledger_reference": "per-instance-ledger.json",
      "train_subperiod": {
        "start": "2025-10-20",
        "end": "2026-03-31",
        "instances": 8,
        "wins": 6,
        "losses": 2,
        "win_rate_pct": 75.0,
        "average_return_pct": 0.891298463479345,
        "profit_factor": 5.445183696254404
      },
      "validation_subperiod": {
        "start": "2026-04-01",
        "end": "2026-08-13",
        "instances": 7,
        "wins": 6,
        "losses": 1,
        "win_rate_pct": 85.71428571428571,
        "average_return_pct": 1.2400577514215938,
        "profit_factor": 14.744894323643738
      }
    },
    "META_STRONG_BULLISH_CONFIRMATION": {
      "status": "AVAILABLE",
      "as_of": "2026-08-14T16:00:00-04:00",
      "source_date_range": {
        "start": "2025-10-20",
        "end": "2026-08-13"
      },
      "eligible_sample_definition": "Dates in the research window with a complete current GEX observation, immediate-prior XNYS GEX observation, at least 60 prior valid observations for every threshold used, and all required entry/terminal 30-minute bars.",
      "total_eligible_dates": 189,
      "number_of_signal_instances": 17,
      "wins": 12,
      "losses": 5,
      "unresolved_excluded_instances": 0,
      "win_rate_pct": 70.58823529411765,
      "win_rate_denominator": 17,
      "win_rule": "return_pct > 0 after modeled slippage; return_pct <= 0 is a loss. Unresolved instances are excluded from the denominator.",
      "gross_profit_return_units": 32.06618378856159,
      "gross_loss_return_units": 6.563695802652236,
      "profit_factor": 4.885385421975892,
      "return_units": "percentage points of entry notional, net of specified slippage and before taxes; no commissions unless listed.",
      "average_return_pct": 1.500146352112315,
      "median_return_pct": 0.7690789277514434,
      "holding_period_distribution_bars": {
        "min": 49,
        "median": 49.0,
        "max": 49
      },
      "maximum_adverse_excursion": {
        "average_pct": -1.5793349204844933,
        "worst_pct": -5.615152531009048
      },
      "maximum_favourable_excursion": {
        "average_pct": 3.2038686299880035,
        "best_pct": 11.373466638303897
      },
      "entry_rule": "D1 07:30 America/New_York 30-minute bar Open",
      "exit_rule": "D2 15:30 bar Close; no TP and no SL in v1.0.0.",
      "transaction_costs": "0 commission; 10 bps per side (20 bps round trip) modeled slippage",
      "position_sizing": "1.0 notional unit per independent signal",
      "treatment_of_overlapping_signals": "Independent signal-level research; no portfolio occupancy filter.",
      "treatment_of_repeated_same_day_signals": "One signal code can emit at most once per market date and source revision; duplicates are deduplicated by strategy/version/date/signal/revision.",
      "candidate_inclusion": "All independently eligible signal candidates are included. No manual-trade filter is used.",
      "sample_size_limitations": "Small samples; estimates are unstable and should be forward-paper validated. Historical selection may have multiple-testing risk as disclosed in strategy.md.",
      "confidence_interval": {
        "method": "Wilson score 95%",
        "lower_pct": 46.86688993346016,
        "upper_pct": 86.72001038970478
      },
      "backtest_engine_and_version": "gex_contract_backtest_v1.0.0",
      "source_snapshot_hash": "30e3670c2e044e451ab8dea0434f35351b097509023026013e04e28cbdffa3b9",
      "per_instance_ledger_reference": "per-instance-ledger.json",
      "train_subperiod": {
        "start": "2025-10-20",
        "end": "2026-03-31",
        "instances": 8,
        "wins": 7,
        "losses": 1,
        "win_rate_pct": 87.5,
        "average_return_pct": 1.2631539992607965,
        "profit_factor": 7.12662799006765
      },
      "validation_subperiod": {
        "start": "2026-04-01",
        "end": "2026-08-13",
        "instances": 9,
        "wins": 5,
        "losses": 4,
        "win_rate_pct": 55.55555555555556,
        "average_return_pct": 1.7108062213136646,
        "profit_factor": 4.13315318860995
      }
    }
  },
  "research_lineage": {
    "prior_memo": "META_GEX_research_baseline_2026-08-15.md",
    "note": "This contract recomputes actionable-rule metrics directly from the mounted source snapshots and applies its frozen slippage/exit conventions. Therefore counts/statistics can differ from the earlier exploratory memo."
  }
}
```

## 7. Asynchronous production outcome

```json
{
  "required_source": "StockDB_US.StockData.PriceHistoryTimeFrame where ASXCode='META.US' and TimeFrame='30M'; historical snapshot META-20251020-20260814.csv.",
  "source_status": "AVAILABLE_FOR_HISTORICAL_SNAPSHOT",
  "source_instrument": "META.US",
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
    "META_STRONG_BEARISH_CONTINUATION": "2.5% adverse stop or D1 15:30 close",
    "META_STRONG_BULLISH_CONFIRMATION": "D2 15:30 close"
  },
  "holding_horizon": "Per signal definition.",
  "pending_rule": "Outcome remains PENDING until entry bar and every bar needed to prove an earlier terminal condition through the scheduled terminal bar exist. Missing required bars do not imply no hit.",
  "market_closed": "Remain PENDING until the next required XNYS/futures data is published; never synthesize a price.",
  "missing_bar": "PENDING plus MISSING_REQUIRED_BAR audit flag; do not forward-fill OHLC.",
  "correction": "Every market-bar snapshot has a revision hash. If finalized source bars change under explicit SOURCE_CORRECTION, calculate a new outcome revision, preserve the old finalized record as superseded, and link both revisions.",
  "gap_rule": "If an active stop/limit is already crossed by a bar Open, fill at Open; otherwise fill at the specified level when High/Low touches it. Time exits use terminal bar Close.",
  "opposing_signal": "Does not change an already-triggered production outcome unless the signal definition explicitly has an opposing-signal exit. These versions do not, except SPX portfolio admission prevents overlapping plans before entry.",
  "return_formula": "LONG gross=(exit/entry-1)*100. SHORT gross=(entry-exit)/entry*100. Net return = gross return - modeled round-trip slippage/cost percentage points.",
  "costs_slippage": "10 bps per side modeled slippage; commission 0.",
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
Source snapshot hash: `30e3670c2e044e451ab8dea0434f35351b097509023026013e04e28cbdffa3b9`  
Implementation hash: `ba32288a8ef6ccfa5a25da91e88f5906e5318ac697b5036de0b18fe316665ebd`

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
    "No untouched strict OOS window exists; forward-paper results remain a research validation risk.",
    "The 2.5% emergency stop is frozen for v1.0.0 and must be monitored; changing it requires a new version."
  ]
}
```

**META-specific note.** The prior research memo treated Strong Bearish Continuation's D1 cash-close path as the primary benchmark and suggested an emergency stop around 2%-2.5%. This contract freezes 2.5%; changing it requires a new version.
