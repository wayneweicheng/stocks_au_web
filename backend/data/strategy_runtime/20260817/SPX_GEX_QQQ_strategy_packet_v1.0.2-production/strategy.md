# SPXW GEX → QQQ Production Strategy Contract

**Strategy:** `SPX_GEX_QQQ_V1`  
**Version:** `1.0.2-production`  
**Status:** **IMPLEMENTABLE**  
**Deployment target:** **PRODUCTION**  
**Execution mode:** notification-only / manual QQQ execution  
**Broker execution:** **HARD_DISABLED**

## Production intent

This packet is the production-ingestible repair of `1.0.2-contract`. It keeps the frozen v1.0.2 trading rules and replaces the previous review blocker with a fully reconciled SPXW + NQMain historical instance ledger. It is suitable for registration/deployment in the Production catalogue; actual deployment still requires the host application to import and enable this exact version and configure its Pushover secrets.

The architecture is intentionally split:

`SPXW GEX (signal source) → NQMain 30m (historical percentage-path proxy) → QQQ (live/manual execution instrument)`.

NQ price is never treated as QQQ price. Historical returns use NQ percentage movement as the QQQ proxy. Live plans must price QQQ from a current executable QQQ quote.

## Exact base signal

- **BEARISH** if `(CloseChangePct > 0 AND PCRChangePct > +5)` OR `(abs(CloseChangePct) < 0.10 AND PCRChangePct > +20)`.
- **BULLISH** if `(CloseChangePct < 0 AND PCRChangePct < -5)` OR `(abs(CloseChangePct) < 0.10 AND PCRChangePct < -20)`.
- Otherwise `NONE`.

`PCR = abs(BP_GEXDelta) / abs(BC_GEXDelta)`.

## Executable signal catalogue

| Priority | Signal | Exact trigger | Direction | Action | Entry | Exit | Production notify |
|---:|---|---|---|---|---|---|---|
| 1 | STRONG_YELLOW | BEARISH + SC GEX <= prior-60 median + SPDeltaShare > prior-60 P75 | SHORT | PLAN_ENTRY | QQQ D1 03:30 NY | TP -0.8%, SL +1.0%; no scheduled time exit | yes |
| 2 | RELIABLE_YELLOW | BEARISH + SC GEX <= prior-60 median + SPDeltaShare <= prior-60 P75 | SHORT | PLAN_ENTRY | QQQ D1 03:30 NY | TP -0.4%, SL +0.8%; no scheduled time exit | yes |
| — | MIXED_YELLOW | BEARISH + SC above median + SP share above P75 | NONE | WATCH | — | — | no |
| — | WEAK_YELLOW | BEARISH + SC above median + SP share <= P75 | NONE | WATCH | — | — | no |
| 3 | REVERSAL_GREEN | BULLISH + prior-5D adjusted NQ return <= 0 | LONG | PLAN_ENTRY | D1 03:30 reference; -1% dip to D3 03:30; fallback D3 03:30 | D5 cash close | yes |
| 4 | NORMAL_GREEN | BULLISH + prior-5D adjusted NQ return > 0 | LONG | PLAN_ENTRY | QQQ D3 03:30 NY | +2.5% TP, else D5 cash close | yes |
| — | NO_SIGNAL | base signal NONE | NONE | NONE | — | — | no |

## Causality and data readiness

All rolling thresholds use **exactly the 60 prior valid observations** and exclude D0. D1/D3/D5 are XNYS sessions, not calendar days. `America/New_York` is used directly so DST is not represented by a fixed UTC offset.

The scheduler must fail closed with `NOT_READY` and create no observation/signal/report/plan/notification if the expected D0 source is stale, BC/BP/SC/SP is incomplete or duplicated, required values are null, total absolute GEX delta is zero, prior-session continuity fails, or required historical observations are unavailable.

## NQ continuous-contract roll handling

The uploaded NQMain file contains deterministic positive roll discontinuities near quarterly roll dates. Historical prices are roll-neutralized with the forward-ratio method specified in `source-manifest.json`. The method reproduces the earlier adjusted series exactly; for example 2025-03-26 03:30 raw NQ Open `20490.0` becomes `19782.399352381643`.

## Historical performance — full currently usable period

Signal-level statistics include every actionable candidate from **2025-03-06 through 2026-08-13**. Conflicting candidates remain in signal-level statistics; portfolio gating is shown separately. Gross proxy performance uses zero modeled costs/slippage.

| Signal | Instances | Resolved | Wins | Losses | Unresolved | Win rate | Avg return | Profit factor |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| STRONG_YELLOW | 10 | 10 | 8 | 2 | 0 | 80.00% | 0.481% | 3.407 |
| RELIABLE_YELLOW | 21 | 21 | 18 | 3 | 0 | 85.71% | 0.229% | 3.000 |
| REVERSAL_GREEN | 43 | 42 | 33 | 9 | 1 | 78.57% | 1.459% | 4.135 |
| NORMAL_GREEN | 26 | 26 | 19 | 7 | 0 | 73.08% | 0.550% | 2.309 |

The earlier Normal Green aggregate was 25 resolved / 72.0% because the 2026-08-06 candidate had not reached D5 when that snapshot was produced. The newly uploaded NQ history now resolves it positively, so the ledger and aggregate are updated together rather than preserving an unreconcilable stale total.

With `EXISTING_POSITION_PRIORITY` applied, the reconciled currently resolved portfolio has **60 trades**, **80.00% wins**, PF **3.300**, and a compound theoretical ending NAV of **$158,707.69** from $100,000 at 1.0x exposure. This portfolio figure is a gross NQ-percentage proxy, not a claim of realizable QQQ performance.

## Production portfolio state

At most one directional strategy episode can occupy the portfolio. A Reversal Green occupies state starting D1 03:30 while its dip order is pending. A Normal Green does **not** occupy the portfolio before its D3 03:30 entry. Existing positions/pending dip orders block new opposing or same-direction signals; no stacking or automatic reversal is allowed.

## Notification/outcome separation

Production is notification-only. A human may trade QQQ manually, but model outcomes must never depend on manually entered actual trade prices. The outcome worker uses market data and remains `PENDING` until all required bars exist. Historical research performance and production/shadow performance must be displayed separately.

## Version lock

Any change to the base-signal clauses, 60-day windows, P75 rule, 03:30 timing, TP/SL, Reversal -1% dip/fallback, Normal +2.5% TP, NQ roll method, or portfolio conflict policy requires a **new version**.
