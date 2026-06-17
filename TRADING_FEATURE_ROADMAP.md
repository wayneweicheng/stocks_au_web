# Trading Platform Feature Roadmap

## Objective

Improve the platform by connecting its existing scanners, research, market-flow,
portfolio, and execution tools into a complete trading workflow:

1. Discover opportunities.
2. Validate the setup.
3. Define risk and position size.
4. Execute and monitor the trade.
5. Measure the outcome and improve future decisions.

The platform already contains many strong individual tools. The main opportunity
is to consolidate their outputs, explain agreement and disagreement between
signals, and measure whether those signals actually work.

## 1. Daily Trading Command Center

Replace the basic dashboard with a decision-focused daily workspace.

### Proposed Features

- Current market regime: bullish, bearish, neutral, volatility, GEX, breadth,
  dark-pool context, and relevant index conditions.
- Top opportunities ranked across all scanners and research sources.
- Current positions requiring attention.
- Orders near an entry, stop, target, or cancellation condition.
- New announcements, trading halts, and material events affecting watched or
  held stocks.
- A "What changed since yesterday?" summary.
- Data freshness and system health warnings.
- Separate pre-market, intraday, and post-market views.
- Direct actions to open the stock cockpit, review an order, or inspect the
  relevant source signal.

### Value

Creates one place to decide what needs attention now instead of manually
checking many pages.

## 2. Unified Stock Cockpit

Create a consolidated page for each ASX or US stock.

### Proposed Features

- Multi-timeframe chart and important technical levels.
- Breakout, PLLRS, TA, pattern-prediction, and market-flow signals.
- Broker accumulation and distribution analysis.
- Announcements, research links, ratings, and AI analysis.
- Liquidity, spread, market depth, average trade value, and slippage risk.
- Option flow, GEX, gamma walls, and important expiry levels where available.
- Current holding, average cost, unrealized P&L, and open orders.
- Upcoming catalysts and known risks.
- Bull case, bear case, key uncertainty, and thesis invalidation.
- Suggested entry zone, stop, targets, holding period, and risk/reward.
- Links to create an alert, add to a watchlist, or prepare an order.

### Value

Eliminates the need to open several separate tools to form a complete opinion
about one stock.

## 3. Signal Confluence Score

Produce a transparent score that combines independent evidence for each stock.

Example:

> Breakout + broker accumulation + bullish AI rating + volume expansion -
> poor liquidity = 82/100 bullish.

### Proposed Features

- Direction: bullish, bearish, or neutral.
- Confidence score.
- Expected holding period.
- Agreeing signals and conflicting signals.
- Data-quality and freshness penalties.
- Explanation of every component contributing to the score.
- Different weight profiles for intraday, swing, and position trades.
- A minimum-evidence rule so one strong-looking input cannot dominate the
  result.
- Historical calibration of score ranges against actual returns.

### Value

Makes the platform's many signals comparable while retaining enough explanation
to avoid treating the score as a black box.

## 4. Signal Performance and Calibration

Track the forward performance of every generated signal automatically.

### Proposed Features

- Returns at T+1, T+2, T+5, T+10, and T+20 trading days.
- Win rate, average return, median return, and return distribution.
- Maximum favorable excursion and maximum adverse excursion.
- Time taken to reach the target or stop.
- Performance by:
  - Signal type.
  - Confidence band.
  - Market regime.
  - Sector and market-cap band.
  - Liquidity band.
  - Long or short direction.
  - Holding period.
- Comparison of predicted direction and range against actual movement.
- Rolling performance to detect signal decay.
- Sample-size warnings and confidence intervals.
- Leaderboard showing which signals currently have genuine predictive value.

### Value

Determines where each signal works, where it fails, and whether stated
confidence reflects real-world accuracy.

## 5. Trade Journal with Automatic Attribution

Build a journal from IB executions and existing platform data rather than
requiring extensive manual entry.

### Proposed Features

- Import fills, commissions, order changes, and exits from IB.
- Link each trade to the original scanner signals, research, and AI report.
- Save the planned entry, stop, target, size, thesis, catalyst, and invalidation.
- Capture the chart and signal state at entry.
- Record scale-ins, partial exits, stop changes, and final exit reason.
- Compare planned and actual risk/reward.
- Optional notes and mistake tags:
  - Late entry.
  - Oversized position.
  - Moved or ignored stop.
  - Chased price.
  - Exited early.
  - Ignored invalidation.
  - Traded without sufficient liquidity.
- Performance reports by strategy, setup, signal, weekday, holding period,
  market regime, and confidence band.
- Separate trading-edge performance from execution and discipline errors.

### Value

Creates a feedback loop between analysis, execution, and actual results.

## 6. Position and Portfolio Intelligence

Extend Portfolio Risk beyond leverage, cash, and margin capacity.

### Proposed Features

- Risk per position based on current price and stop.
- Total portfolio risk if all stops are reached.
- Sector, industry, currency, country, and factor concentration.
- Correlation clusters and detection of duplicated exposure.
- Long/short and gross/net exposure.
- Projected exposure if all open orders fill.
- Gap-down, volatility-spike, and market-shock stress tests.
- Suggested position size using:
  - Account risk limit.
  - Stop distance.
  - Liquidity.
  - Volatility.
  - Existing correlated exposure.
- Warnings when a new order exceeds portfolio or strategy limits.
- Positions where the original signal, catalyst, or thesis has weakened.
- Portfolio-level P&L attribution by strategy and market factor.

### Value

Prevents several individually reasonable trades from combining into one
concentrated or excessive portfolio risk.

## 7. Catalyst and Event Calendar

Create a unified calendar of events that may affect held, watched, or candidate
stocks.

### Proposed Features

- Earnings and company results.
- AGM and investor presentation dates.
- Dividend dates.
- Capital raises, placements, entitlement offers, and escrow releases.
- Clinical, drilling, production, regulatory, and court milestones.
- Index additions and removals.
- Option expiries and major gamma events.
- Relevant macroeconomic announcements and central-bank decisions.
- Countdown badges on watchlists, positions, and the stock cockpit.
- Alerts for positions exposed to upcoming binary events.
- Historical reaction statistics for recurring event types where data permits.

### Value

Reduces accidental exposure to known events and helps identify catalyst-driven
opportunities.

## 8. Advanced Alert Builder

Support compound, evidence-based alerts rather than only simple price
conditions.

Example:

> Price crosses resistance AND volume is above 2x average AND broker flow is
> positive AND the stock is not in a trading halt.

### Proposed Features

- Conditions based on price, volume, VWAP, moving averages, technical levels,
  broker flow, scanner signals, options, GEX, announcements, and portfolio
  status.
- AND/OR condition groups.
- Time windows, cooldowns, and one-time or recurring alerts.
- Data-freshness requirements.
- Alert templates for common strategies.
- Preview showing whether the rule would currently trigger.
- Historical trigger count and basic outcome statistics.
- Notifications containing the triggering evidence and direct links to the
  stock cockpit and relevant chart.
- Ability to prepare, but not automatically place, an order from an alert.

### Value

Allows the platform to monitor complete trade setups continuously instead of
requiring manual checking.

## 9. Watchlist Workflow States

Turn Monitor Stocks into a structured research and trade pipeline.

### Proposed States

- Discovered.
- Researching.
- Waiting for catalyst.
- Waiting for entry.
- Ready to trade.
- Position open.
- Thesis weakened.
- Thesis broken.
- Archived.

### Proposed Features

- Entry zone, invalidation level, targets, and expected holding period.
- Catalyst and catalyst date.
- Confidence and priority.
- Reason the stock was added.
- Links to the source scanner, research, and analysis.
- Thesis expiry or mandatory review date.
- Owner and notes when multiple users are involved.
- Automatic state suggestions when an order fills, a stop is hit, or the thesis
  invalidation condition occurs.
- Kanban, table, and compact dashboard views.

### Value

Prevents promising ideas from being forgotten and makes it clear why each stock
is being monitored.

## 10. Data Freshness and Trust Indicators

Make data quality visible throughout the application.

### Proposed Features

- Timestamp every important metric and analysis.
- Display the source and effective observation date.
- Warn about stale price, broker, option, announcement, or portfolio data.
- Show missing-data penalties in signal confidence.
- Prevent unsupported certainty when critical inputs are unavailable.
- Record the data snapshot, prompt version, model, and model version used by
  every AI report.
- Identify delayed versus real-time market data.
- Flag conflicting values from different sources.
- Provide a drill-down explaining why a metric is considered stale or
  incomplete.
- Display system-level ingestion failures on the command center.

### Value

Helps avoid trading decisions based on stale, incomplete, or inconsistent data
and makes AI-generated conclusions reproducible.

## 11. Adaptive Position Exit Manager

Replace fixed sell-range exits with a position-aware exit engine that attempts
to hold a winning trade while its trend and thesis remain healthy.

The goal is not simply to "sell when bearish." Bearishness can be noisy, late,
or temporary. The engine should combine hard risk protection, profit
preservation, thesis monitoring, and confirmed deterioration.

### Exit Layers

#### Layer 1: Disaster and Thesis Stop

This protection is always active and cannot be disabled by a bullish model
opinion.

- Initial maximum-loss stop based on the planned risk for the trade.
- Structural invalidation below support, breakout level, or thesis level.
- Emergency exit for a trading halt outcome, materially adverse announcement,
  severe liquidity failure, or other explicitly defined event.
- Portfolio-level forced reduction when account or concentration limits are
  breached.

#### Layer 2: Hold While Healthy

Do not exit merely because price reaches a predetermined profit target when the
trade remains strong.

Healthy evidence may include:

- Price remains above a selected trend or trailing support level.
- Relative strength remains positive.
- Volume and liquidity remain supportive.
- Broker accumulation has not materially reversed.
- The original breakout or catalyst thesis remains valid.
- No high-confidence bearish signal is confirmed.

#### Layer 3: Profit Protection

As the trade moves in favour, progressively reduce the amount of profit that
can be surrendered.

- Move the risk stop toward break-even only after sufficient favourable
  movement.
- Trail using ATR, recent swing lows, moving averages, or a chandelier-style
  stop.
- Tighten the trailing method as profit reaches defined R-multiples.
- Optionally take a small partial profit while leaving a core position to run.
- Use a high-water mark to calculate current drawdown from peak unrealized
  profit.

#### Layer 4: Evidence-Based Reduction

Reduce part of the position when the setup weakens but is not fully invalidated.

Possible triggers:

- Close below short-term support with above-average volume.
- Failed breakout or repeated rejection from resistance.
- Broker flow changes from accumulation to distribution.
- Relative strength deteriorates.
- Market regime becomes hostile to the strategy.
- Catalyst passes without the expected price response.
- Signal confluence falls from strong to neutral or conflicting.

Example actions:

- First warning: hold and tighten the stop.
- Confirmed deterioration: sell 25% to 50%.
- Strong bearish confluence: close the remaining position.

#### Layer 5: Full Exit

Exit the remaining position when one hard invalidation or several independent
bearish conditions are confirmed.

Examples:

- Thesis or structural stop is breached.
- Two consecutive closes below a key level.
- Bearish trend break plus broker distribution.
- Bearish signal confluence exceeds a configured threshold.
- Maximum allowed drawdown from peak profit is reached.
- Maximum holding period expires without the expected development.

### Exit Profiles

Provide reusable profiles rather than one universal exit rule.

- **Capital Protection:** tight stop and fast reduction.
- **Trend Rider:** wide ATR or swing-low trail, designed to hold major trends.
- **Breakout Swing:** failed-breakout exit plus time stop.
- **Catalyst Trade:** hold through catalyst only when explicitly allowed.
- **Mean Reversion:** exit near fair value or when reversion fails.
- **Manual Hybrid:** engine recommends actions but requires confirmation.

### Exit State Machine

Each managed position should have an explicit state:

1. Protected.
2. Healthy.
3. Warning.
4. Reducing.
5. Exit pending.
6. Closed.
7. Suspended because data is stale or unavailable.

State changes and their evidence should be recorded so every exit can be
explained and reviewed later.

### Position Configuration

For every managed position, store:

- Entry price, quantity, and entry date.
- Strategy and expected holding period.
- Original thesis and invalidation condition.
- Initial stop and maximum account risk.
- Current high-water price and maximum favourable excursion.
- Current trailing level and trailing method.
- Partial-exit percentages.
- Enabled bearish evidence sources and their weights.
- Required confirmation period.
- Current exit state and latest decision explanation.
- Whether actions are recommendation-only, confirmation-required, or
  automatically executable.

### User Interface

Add an Exit Manager page showing:

- All current positions and their exit state.
- Current price, average cost, unrealized P&L, and R-multiple.
- High-water mark and drawdown from peak profit.
- Hard stop, trailing stop, and nearest invalidation level.
- Current bullish and bearish evidence.
- Recommended action: hold, tighten, reduce, or exit.
- Explanation of why the recommendation changed.
- Preview of orders before they are sent to IB.
- Audit history of state changes, recommendations, confirmations, and orders.

### Safety Requirements

- A protective stop must not depend on an LLM.
- Deterministic rules should make order decisions; AI analysis may supply
  evidence or explanation but should not directly place orders.
- Never widen a stop automatically after it has been tightened.
- Treat stale or missing data as a reason to suspend signal-based automation,
  not as evidence that the position is healthy.
- Reconcile position quantity and open orders with IB before every action.
- Avoid duplicate sell orders and prevent total exit quantity from exceeding
  the held position.
- Use minimum confirmation periods to reduce exits caused by intraday noise.
- Start in recommendation-only and paper-trading modes.
- Backtest each exit profile with fees, spread, slippage, and gap-through-stop
  behaviour before enabling live automation.

### Evaluation Metrics

Compare the adaptive exit manager with the existing sell-range approach using:

- Total return and expectancy.
- Profit factor.
- Maximum drawdown.
- Average captured percentage of maximum favourable excursion.
- Average surrendered profit from the high-water mark.
- Win rate and average win/loss ratio.
- Holding period.
- Turnover, fees, and slippage.
- Performance by strategy and market regime.
- Frequency of premature exits followed by trend continuation.

### Value

Allows profitable positions to continue compounding while preserving a
non-negotiable risk floor. It also creates a consistent, testable process for
distinguishing normal pullbacks from genuine deterioration.

## 12. Regime-Aware Options Strategy Selector

Add an options strategy recommendation layer to the Market Command Center and
Top Opportunities ranking.

The selector should not recommend an options strategy from bullish or bearish
direction alone. It must consider:

- Directional conviction.
- Expected size of the move.
- Expected timing and holding period.
- Implied volatility level and percentile.
- Expected change in implied volatility.
- GEX regime and important option walls.
- Whether the market is trending or range-bound.
- Upcoming earnings and other binary events.
- Option-chain liquidity, spread, volume, and open interest.
- Portfolio exposure and maximum acceptable loss.
- Whether the user is genuinely willing and funded to own the shares.

It must be able to return **No Suitable Options Trade**.

### Strategy Suitability Matrix

#### Strong Bullish Direction

- **Buy Call:** Suitable when a large or fast upside move is expected, implied
  volatility is not excessively expensive, and the user accepts time decay.
- **Bull Call Debit Spread:** Preferred defined-risk alternative when implied
  volatility is elevated, the upside target is reasonably bounded, or a naked
  long call is too expensive.
- **Sell Put / Cash-Secured Put:** Suitable only when the outlook is moderately
  bullish, implied volatility is attractive, and the user is willing and able
  to buy 100 shares per contract at the effective assignment price.
- **Bull Put Credit Spread:** Defined-risk alternative to a cash-secured put
  when assignment or capital usage is undesirable.

#### Moderate Bullish or Buy-the-Dip

- **Cash-Secured Put:** Prefer when the desired stock entry price is near a put
  wall or technical support and assignment is acceptable.
- **Bull Put Credit Spread:** Prefer when the thesis is bullish but ownership
  is not desired.
- **Call Calendar or Diagonal:** Consider when the near-term move may be slow
  but the medium-term outlook is bullish, subject to robust modelling of term
  structure and early assignment.

#### Strong Bearish Direction

- **Buy Put:** Suitable when a large or fast downside move is expected and
  implied volatility is not already excessively inflated.
- **Bear Put Debit Spread:** Preferred when implied volatility is expensive or
  the downside target is bounded.
- **Bear Call Credit Spread:** Suitable for moderately bearish or capped-upside
  conditions when defined risk and positive theta are desired.

#### Neutral and Range-Bound

- **Iron Condor:** Suitable when the expected range is wide enough, implied
  volatility provides adequate credit, GEX and price structure support
  mean-reversion, and no major event is expected before expiry.
- **Iron Butterfly:** Suitable only when price is expected to remain close to a
  specific central level. It has a narrower profitable region and requires
  stronger confidence than an iron condor.
- **Calendar Spread:** Consider when price is expected to remain near a target
  and near-term volatility is expensive relative to later expiries.

#### Large Move Expected but Direction Uncertain

- **Long Straddle:** Consider when a move larger than the option market's
  implied move is expected and implied volatility is not already prohibitive.
- **Long Strangle:** Lower-cost alternative when a larger move is required for
  profitability.
- **Reverse Iron Butterfly:** Defined-risk alternative when a large move is
  expected but the direction is uncertain.

These long-volatility strategies require explicit expected-move and volatility
modelling. A known event alone is not sufficient because its expected movement
may already be fully priced into the options.

### Required Inputs

For each opportunity, calculate:

- Underlying price and timestamp.
- Direction score and confidence.
- Expected low, base, and high price at the target date.
- Expected holding period.
- Option market implied move for matching expiries.
- IV percentile or IV rank.
- IV term structure and skew.
- GEX sign, flip level, put wall, and call wall.
- Bid/ask spread, open interest, volume, and quote age for every leg.
- Earnings and material-event dates.
- Buying power, assignment exposure, and existing portfolio Greeks.

### Recommendation Output

Return several ranked candidates instead of one unexplained answer:

```json
{
  "symbol": "XYZ",
  "outlook": "MODERATELY_BULLISH",
  "expected_horizon": "14-30d",
  "strategy_candidates": [
    {
      "strategy": "BULL_CALL_SPREAD",
      "suitability_score": 84,
      "max_profit": 620,
      "max_loss": 380,
      "breakevens": [104.80],
      "probability_estimate": 0.61,
      "reasons": [
        "Upside target is bounded",
        "IV is above normal",
        "Defined risk"
      ],
      "risks": [
        "Earnings occurs before expiry",
        "Call-side spread is 8%"
      ]
    }
  ]
}
```

The user interface should show:

- Recommended strategy and two alternatives.
- Why each strategy fits the outlook.
- Why other common strategies were rejected.
- Legs, expiry, strikes, quantities, and estimated fill prices.
- Maximum profit, maximum loss, breakevens, buying power, and assignment risk.
- Greeks at entry.
- P&L diagram at expiry and at earlier dates.
- Scenario table across price and implied-volatility changes.
- Exit rules for profit, loss, time remaining, and thesis invalidation.
- Quote freshness and liquidity warnings.

### Strategy Scoring

Score each candidate strategy independently:

```text
Strategy Suitability =
    25% directional fit
  + 15% expected-move fit
  + 15% volatility fit
  + 10% GEX and level fit
  + 10% time-horizon fit
  + 10% liquidity and execution quality
  + 10% defined-risk and portfolio fit
  +  5% event compatibility
  - stale-data and concentration penalties
```

Weights should eventually be calibrated using historical trades rather than
remaining permanently hand-selected.

### Safety and Practical Constraints

- Prefer defined-risk structures in the first implementation.
- Treat a cash-secured put as a commitment to buy shares, not simply as premium
  income.
- Do not recommend uncovered short calls or puts.
- Do not recommend multi-leg strategies when any leg is illiquid or stale.
- Reject trades where estimated spread and commissions consume too much of the
  expected edge.
- Do not compare strategies using annualized return alone.
- Model early assignment, ex-dividend dates, pin risk, and expiration handling.
- Avoid neutral premium-selling strategies immediately before unresolved
  binary events unless that event exposure is explicitly intended.
- Require confirmation before placing a multi-leg IB order.
- Save the complete point-in-time option chain and recommendation inputs for
  audit and backtesting.

### Initial Implementation Scope

Start with these defined-risk or fully collateralized strategies:

1. Long call.
2. Long put.
3. Bull call debit spread.
4. Bear put debit spread.
5. Cash-secured put.
6. Bull put credit spread.
7. Bear call credit spread.
8. Iron condor.
9. Iron butterfly.

Add calendars, diagonals, straddles, strangles, and reverse butterflies only
after the platform supports reliable term-structure modelling and multi-leg
scenario analysis.

### Value

Connects market regime and stock opportunity ranking to an executable,
risk-defined expression of the trade. It prevents the common mistake of using
the same options structure for every bullish, bearish, or neutral opinion.

## Recommended Implementation Order

### Phase 1: Connect Existing Capabilities

1. Daily Trading Command Center.
2. Unified Stock Cockpit.
3. Data Freshness and Trust Indicators.
4. Watchlist Workflow States.

These features mostly organize and connect information the platform already
has.

### Phase 2: Improve Decisions

5. Signal Confluence Score.
6. Position and Portfolio Intelligence.
7. Catalyst and Event Calendar.
8. Advanced Alert Builder.

These features turn existing information into more actionable decisions and
risk controls.

### Phase 3: Build the Feedback Loop

9. Signal Performance and Calibration.
10. Trade Journal with Automatic Attribution.

These features measure whether the platform's signals and the resulting trades
actually create an edge. Data capture for them should begin early, even if
their full user interfaces are implemented later.

### Phase 4: Adaptive Position Management

11. Adaptive Position Exit Manager.

Implement this incrementally:

1. Recommendation-only dashboard with hard stops and trailing levels.
2. Historical simulation against the existing sell-range approach.
3. Paper-trading state machine and partial-exit recommendations.
4. Confirmation-required IB order placement.
5. Carefully scoped automation only after measured validation.

### Phase 5: Options Strategy Selection

12. Regime-Aware Options Strategy Selector.

Implement this incrementally:

1. Strategy suitability recommendations without order placement.
2. Defined-risk payoff and scenario modelling.
3. Historical and paper-trading evaluation.
4. Multi-leg IB order previews.
5. Confirmation-required order placement.

## Important Design Principles

- Prefer explainable scores over opaque recommendations.
- Keep analysis and execution connected, but require deliberate confirmation
  before placing live orders.
- Store point-in-time signal snapshots to prevent look-ahead bias.
- Distinguish observation time, processing time, and data availability time.
- Measure results after fees, commissions, spread, and estimated slippage.
- Show sample size alongside every historical performance statistic.
- Separate ASX and US assumptions where their market structure or data differs.
- Reuse existing APIs, database views, and tools before adding new external
  data dependencies.
- Design each feature so it supports both manual trading and future automation.
