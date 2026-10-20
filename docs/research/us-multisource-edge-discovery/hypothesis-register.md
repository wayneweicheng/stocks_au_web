# Starter hypothesis register

This is a **starting** research agenda, not predetermined findings. The executor must add hypotheses justified by the source inventory and record why some are not feasible. Every result uses verified underlying trade outcomes, label-aware chronological folds, matched coverage, costs and trial accounting from `research-plan.md`.

All features below use completed data available before their decision. Every numeric threshold below is an initial coarse research setting, not an asserted profitable threshold. An unsupported hypothesis should be rejected or marked insufficient.

## A. Technical price/volume hypotheses

### T01 — Trend continuation versus stretched-price reversion

- Mechanism: price above a rising moving average may continue, but extreme extension may reverse; these are competing effects.
- Features: SMA/EMA 10/20/50, trailing slope, MA alignment, signed distance `(close-MA)/ATR`, recent return and gap.
- Tests: compare aligned-trend continuation with contrarian trades at extensions of 1/2 ATR. Compare to each ticker's unconditional long/short horizon. Test GEX interaction separately.
- Falsification: no stable net incremental effect across folds, or benefit disappears outside one ticker or one volatility episode.

### T02 — Bollinger location, distinct from bandwidth

- Mechanism: near-lower-band prices may mean-revert; upper/lower band breaks may instead continue in strong trends.
- Features: `percent_b=(close-lower)/(upper-lower)`, signed ATR distance to each band; initial 20-session/2-standard-deviation bands with declared ddof; zero-width bands -> missing.
- Tests: LONG at %B <=.1 and SHORT at %B >=.9 versus momentum breakout/re-entry variants; condition on trend and GEX sign in a second-stage interaction.
- Control: same dates and volatility distribution without the band-location requirement. Compare to MA distance to detect redundant information.
- Important: previous bandwidth observations did not establish a lower-band entry edge.

### T03 — Squeeze expansion versus high-volatility exhaustion

- Mechanism: low bandwidth followed by expansion may forecast movement, but not its sign; direction needs a separate cue.
- Features: `(upper-lower)/MA`, prior-only percentile, bandwidth change, realised-volatility ratio, price break direction.
- Tests: low-bandwidth directional breakout versus fading high-bandwidth extremes; include a magnitude-prediction diagnostic without mislabelling it directional alpha.
- Reject if costs dominate or direction comes only from hindsight.

### T04 — RSI extremes, midline persistence and failure swings

- Features: RSI 7/14/21; slope; cross above/below 30/50/70; causal price trend.
- Tests: extreme fade versus trend-following midline persistence. Compare RSI alone to RSI conditional on MA/band location and GEX regime.
- Reject universal RSI thresholds if effects reverse across folds or are entirely explained by recent returns.

### T05 — MACD acceleration and trend change

- Features: declared EMA12/EMA26 line, EMA9 signal, histogram, slope and cross; normalise by ATR or price.
- Tests: continuation after aligned histogram acceleration versus first-cross reversal; compare against simple MA slope at equal turnover.
- Reject if additional lag reduces net performance or gives no incremental effect.

### T06 — Confirmed divergence rather than hindsight divergence

- Features: trailing regression disagreement between price and RSI/MACD/GEX; alternatively two already-confirmed pivots with fixed 2/3 right-bar confirmation.
- Timestamp: pivot/line becomes available at confirmation, never at the historical extreme itself.
- Tests: bullish and bearish divergence; compare to price-only reversal and trend controls. Report signal delay and coverage lost.
- Reject if profitability exists only when pivots are backdated or if confirmed signals are too late.

### T07 — Prior support/resistance bounce versus break continuation

- Features: prior 10/20/60-session highs/lows (exclude the current bar from level definition), ATR distance, number of prior tests, age, breakout/retest state.
- Tests: bounce near support/resistance versus confirmed break continuation; room to next opposing level as a filter.
- Controls: band/MA distance to separate geometric level value from generic overextension.

### T08 — Daily/weekly/monthly classic pivots and CPR

- Definitions: prior completed period H/L/C; `P=(H+L+C)/3`, `R1=2P-L`, `S1=2P-H`, `R2=P+(H-L)`, `S2=P-(H-L)`. CPR: `BC=(H+L)/2`, `TC=2P-BC`, sort bounds if necessary.
- Features: ATR distance to each known level, CPR width, multi-timeframe clustering, available room.
- Tests: bounce/break at levels; compare with previous high/low levels and randomly shifted placebo levels defined using training-only rules.
- Reject if apparent level confluence is simply wide ranges or future current-week OHLC leakage.

### T09 — Causal trendline touches and breaks

- Features: trailing 20/60-bar regression slope/channel; or deterministic lines joining confirmed same-side pivots with fixed anchor/tolerance rules.
- Tests: line-touch continuation and break/retest reversal; sensitivity to window and ATR tolerance.
- Reject if results depend on discretionary anchors or tiny tolerance changes.

### T10 — Volume confirmation and liquidity

- Features: dollar volume, volume/previous-20-session median, OBV slope, close location, VWAP distance, prior anchored VWAP.
- Tests: volume-confirmed price break versus unconfirmed break; low-volume reversion; liquidity gating and execution-cost reduction.
- Distinguish better fillability from better gross directional forecasts. Do not use D1 completed volume at a D1 07:30 entry.

### T11 — Gap and intraday confirmation

- Arm A: known premarket gap to previous regular close at decision time.
- Arm B: later-entry VWAP/opening-range confirmation after its bars close.
- Tests: gap fade versus continuation by option/GEX regime; later-entry arm versus same later-entry no-confirmation benchmark.
- Reject if the filter uses a future opening range while retaining the earlier entry price.

### T12 — Subject volatility, not just VIX

- Features: ATR/price, realised vol 10/20/60, bandwidth, overnight-gap variation, relative volatility to sector.
- Tests: stable low/high-volatility regimes, interaction with directional rule and horizon; risk sizing based only on prior realised volatility.
- Contrary evidence check: a volatility gate may remove the largest winners and worsen returns despite raising win rate.

## B. Delayed options, exposure, walls and trade-flow hypotheses

### O01 — Unusual option activity relative to ticker baseline

- Features: daily call/put/total volume; prior-only rank and volume/previous-median ratio, liquidity controls.
- Tests: standalone direction from call/put imbalance, and incremental filter on price/GEX cues. High total activity alone may predict absolute moves, not sign.
- Reject if repeated snapshots or changing contract coverage explain the spike.

### O02 — Open interest participation and changes

- Features: total and near-expiry OI; matched OptionSymbol day-to-day changes; OI concentration; volume/OI.
- Controls: contract additions, expiries, corporate actions, differing chain coverage and stale OI. Report aggregate-universe changes separately from matched-contract changes.
- Tests: high/low OI state and increasing/decreasing OI conditional on price direction and option type.
- Do not equate rising OI with bullishness or identify opening buys from OI alone.

### O03 — Implied versus realised volatility

- Features: quality-filtered near-ATM IV in declared DTE buckets; IV rank/change; IV versus trailing realised vol using compatible annualisation.
- Tests: entry conditioning, future-move magnitude, D1 versus D5 horizon selection. Compare high versus low IV for both long and short signals.
- Reject if IV reflects illiquid deep-OTM quotes, incorrect IV units, or only an unobserved event proxy with poor out-of-event transfer.

### O04 — Put/call skew and expiry term structure

- Features: matched-DTE/delta or moneyness put-versus-call IV, 7–30 versus 31–60 DTE IV; minimum-contract counts per bucket.
- Tests: conditional directional imbalance and relative fear; compare weighted-chain summaries with standardised near-ATM slices.
- Reject if bucket composition, missing contracts, or crossed quotes drive the difference.

### O05 — Near-expiry concentration and gamma sensitivity

- Features: 0–7/8–30/31–60/>60 DTE fractions, gamma/OI concentration, option multiplier, underlying price, clearly defined exposure sign assumptions.
- Tests: stronger short-horizon response near concentrated expiry versus longer hold; interaction with trend and wall proximity.
- Reject claims that absolute gamma determines direction or that unsigned chain gamma proves dealer inventory.

### O06 — Gamma wall/flip distance and available price room

- Sources: inspect GammaWall, GammaWallByExpiryDate, CalculatedGEX and raw-chain definitions; compare stored and independently reconstructed levels where feasible.
- Features: distance to call/put walls or gamma-flip in ATR/price units; level changes, strength, expiry concentration, clustering with technical levels.
- Tests: pinning/bounce versus breakout acceleration; compare to technical-only levels and same coverage without wall information.
- Reject if level creation uses future prices/snapshots, unsupported sign assumptions, or no incremental effect over price levels.

### O07 — Capital-type GEX/DEX rotations

- Features: BC/BP/SC/SP exposure share, share change, net balance, HHI, total size, GEX/DEX agreement/disagreement.
- Tests: standalone rotation, interaction with trend/volatility, compare normalised versus raw magnitudes.
- Reject if a capital classification is not historically available or formula changes explain performance.

### O08 — Aggressive option trades and inferred direction

- Sources: OptionTrade, SignificantOptionTrade, OptionTradeSideInference, option-flow transforms; inspect fields, inference method and clock semantics.
- Features: premium/size, buyer/seller inference confidence, option type/delta, large-trade concentration, last-hour activity and persistence.
- Tests: stock-directional pressure versus hedge/reversal interpretations; compare high-confidence-only with all inferred trades.
- Reject treating every call print as bullish or ambiguous quote-matched trades as certain aggressive buys.

### O09 — Quote liquidity and data quality as signals or execution gates

- Features: valid bid/ask fraction, spread/mid, stale-trade age, minimum volume/OI, usable near-ATM coverage.
- Tests: improved economic net returns versus gross selection effects. Match the available subset before comparing.
- Reject if removing low-quality observations merely removes all losing dates ex post.

## C. Cross-source and context hypotheses

### C01 — Trend/reversion choice depends on GEX regime

- Hypothesis: a technical breakout and technical mean reversion respond differently to exposure sign/concentration.
- Test four cells first: technical continuation/reversion x GEX regime, not arbitrary high-order combinations. Then compare combined model to technical-only and GEX-only at matched costs/coverage.

### C02 — IV/option flow distinguishes informative technical extremes

- Hypothesis: a lower-band touch with high IV/put activity may be capitulation or justified downside pressure.
- Test opposing continuation/reversion predictions using the same band event, explicitly including failure cases. Compare IV/flow against realised-volatility controls to determine genuine new information.

### C03 — Technical and option-wall confluence

- Hypothesis: nearby independent technical and option-derived levels improve location/room-to-target information.
- Test clustered versus isolated levels, strength and distance normalisation; disjoint-source ablations. Prevent counting two transforms of the same source as independent confluence.

### C04 — Broad market, breadth and sector regime

- Features: lagged SPY/QQQ/sector trend/volatility, VIX, breadth and CLV, relative stock momentum.
- Tests: aligned versus contrarian exposure, sector-held-out transfer, regime-conditional position sizing.
- Reject a claim based on a broad high-VIX flag if there are effectively no high-VIX observations in validation.

### C05 — Persistent signals are new information or duplicated exposure

- Features: consecutive trigger count, days since initial signal, signal-strength change, prior open tranches.
- Tests: first-only, add every day, add only on improving strength; include marked-to-market capital and correlated exposure limits.
- Reject interpreting repeated same-direction D5 trades as independent confirmation of significance.

### C06 — Alternative data adds value after basic sources

- Sources: database-wide catalogue, including ETF flows, relative strength, money flow, events and fundamentals if point-in-time feasible.
- Tests: one source-family at a time, then ablation. Separate sources with short history from long-history pooled experiments.
- Reject using future-labelled tables, mutable recommendation scores or inaccessible-at-decision events as predictors.

## D. Exit/risk hypotheses

### E01 — Predictability horizon differs by source/regime

- Test fixed D1/D3/D5 with the same entry population and fully resolved common comparison where appropriate. A model selecting horizon must choose from pre-decision features and be fit inside training.
- Report exposure time and net return per unit risk; a larger five-day mean alone does not prove a superior strategy.

### E02 — Volatility stops reduce harmful tail losses

- Test coarse ATR stops (e.g. 1/2/3 ATR) and time exits versus no-stop on identical entries; gap-through-stop conservative fills; no future-ATR use.
- Reject if stopped trades repeatedly recover and total net expectancy/drawdown trade-off worsens.

### E03 — Trailing and structural exits

- Test predeclared completed-bar trails and support/VWAP failures with conservative order-of-events. Compare net P&L and drawdown, not just win rate.
- Reject if profits depend on filling at a bar's high or on hindsight MAE/MFE.

### E04 — Volatility sizing and correlated-exposure caps

- Test fixed-notional versus volatility-targeted sizing, maximum ticker/sector/cluster exposure, 1/3/5-tranche caps.
- Size and rank candidates only using information known before entry. Compare under the same gross budget, financing and rebalance costs.
- Reject lower nominal drawdown achieved only by investing dramatically less without risk-adjusted improvement.

## Registry schema required before execution

For each hypothesis record:

`hypothesis_id`, `version`, `mechanism`, `opposing_explanation`, `source_objects`, `availability_rule`, `features`, `exact_thresholds_or_model_space`, `decision_time`, `directions`, `horizons`, `universe`, `control`, `split_ids`, `cost_model`, `overlap_policy`, `selection_metric`, `test_budget`, `falsification_rule`, `status`, `artifact_paths`.

Result states: `NOT_TESTED`, `BLOCKED`, `REJECTED`, `INSUFFICIENT`, `EXPLORATORY`, `SHADOW_CANDIDATE`. A high backtest PF is not its own promotion decision. Newly discovered ideas need registry entries and a declared additional trial budget before execution.
