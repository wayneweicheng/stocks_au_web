# Sell Put Spread Support In Option Orders

## Context

The current support-zone workflow from `price-levels-30m` helps the user prepare a cash-secured sell put order. The existing behavior should remain the default. The new behavior adds an explicit opt-in mode for a vertical sell put spread.

The current codebase stores option-related strategy order metadata as JSON in `AdditionalSettings` using fields such as `OptionSymbol` and `OptionBuySell`. The IB order router currently supports equity limit orders and bracket orders, but not option combo/BAG spread orders.

## Goals

- Keep the existing cash-secured sell put workflow unchanged when the new checkbox is not selected.
- Add a `Sell put spread` checkbox to the Option Orders workflow, default unchecked.
- When checked, prefill the spread legs from the support-zone context:
  - short put: the existing selected sell put leg
  - long put: a lower-strike protective put with the same expiry
- Submit a single combo sell put spread order, not two independent leg orders.
- Support the existing 30% profit exit concept for spreads by submitting a linked buy-to-close combo exit order at 70% of the entry credit.
- Show enough preview data for the user to understand credit, max loss, breakeven, and liquidity/fill risk before submission.

## Non-Goals

- Do not change current cash-secured put behavior.
- Do not place two separate option leg orders for a spread.
- Do not add stop-loss handling for sell put spreads in the first version.
- Do not redesign unrelated order pages.

## User Workflow

1. User clicks a support-zone link on `price-levels-30m`.
2. Option Orders opens with the existing sell put ticket prefilled.
3. The `Sell put spread` checkbox is visible and unchecked by default.
4. If the user leaves it unchecked, `Submit Order` uses the current cash-secured put order path.
5. If the user checks it:
   - the page adds a long-put protection leg section
   - the system preselects a lower strike with the same expiry when possible
   - the user can adjust the long-put strike
   - the preview changes from single-leg premium/cash-secured exposure to spread credit/max-loss metrics
6. `Submit Order` places one IB combo sell put spread order at a net-credit limit.
7. If 30% profit exit is enabled, the system submits a linked buy-to-close combo exit order at `entry_credit * 0.70`.

## UI Behavior

### Default Cash-Secured Put Mode

- Checkbox label: `Sell put spread`
- Default state: unchecked.
- Existing fields, validation, and submit behavior remain unchanged.

### Spread Mode

When checked, show:

- Short leg summary: sell put symbol, expiry, strike, bid/ask/mid if available.
- Long leg selector: lower-strike put, same expiry.
- Net credit limit input.
- Quantity.
- 30% profit exit toggle or existing setting if already present in the page.
- Preview:
  - spread width
  - net credit
  - max loss: `(short_strike - long_strike - net_credit) * 100 * quantity`
  - max profit: `net_credit * 100 * quantity`
  - breakeven: `short_strike - net_credit`
  - profit exit debit: `net_credit * 0.70`
- Warning text:
  - spreads should be submitted as a single net-credit combo order
  - fair pricing may reduce fill probability in illiquid options
  - aggressive pricing may fill faster but gives up edge

## Backend Behavior

Add combo spread support to the IB order layer without changing the existing single-leg path.

### Request Shape

The spread submit request should include:

- underlying symbol
- quantity
- short put contract identifier or normalized option fields
- long put contract identifier or normalized option fields
- net credit limit
- optional profit exit percentage, default `30`

The backend should validate:

- both legs are puts
- both legs share the same underlying and expiry
- short strike is greater than long strike
- quantity is positive
- net credit is positive
- profit exit debit is positive and less than entry credit

### IB Order Model

Use an IB combo/BAG contract:

- short leg action: sell higher-strike put
- long leg action: buy lower-strike put
- parent order: sell combo at net credit limit
- profit exit: buy same combo at `entry_credit * 0.70`, linked to the parent with IB parent/child order semantics where supported

The spread must not be submitted as two independent leg orders.

## Data Persistence

When the UI saves or records the order, persist spread details in `AdditionalSettings` as structured JSON while preserving existing fields for compatibility.

Suggested new fields:

```json
{
  "OptionStrategy": "SELL_PUT_SPREAD",
  "OptionBuySell": "SELL",
  "OptionSymbol": "SHORT_LEG_SYMBOL",
  "SpreadLegs": [
    {
      "role": "SHORT",
      "action": "SELL",
      "put_call": "P",
      "option_symbol": "SHORT_LEG_SYMBOL",
      "expiry": "YYYYMMDD",
      "strike": 100
    },
    {
      "role": "LONG",
      "action": "BUY",
      "put_call": "P",
      "option_symbol": "LONG_LEG_SYMBOL",
      "expiry": "YYYYMMDD",
      "strike": 95
    }
  ],
  "NetCreditLimit": 1.00,
  "ProfitExitPercent": 30,
  "ProfitExitDebit": 0.70
}
```

For cash-secured puts, keep the current JSON shape.

## Liquidity And Fill Policy

The spread order should be priced and submitted as a net credit. This protects the user from legging risk.

Expected behavior:

- If the credit is fair or optimistic, the order may be hard to fill.
- If the credit is too aggressive toward the market maker, the order may fill but at a worse expected return.
- The UI should make this trade-off visible instead of silently improving fill odds at a bad price.

## Error Handling

- If no suitable lower-strike put is found, keep spread mode selected but show an actionable validation message.
- If quotes are missing, allow manual net credit entry but warn that preview quality is limited.
- If IB rejects combo contract qualification, show the contract/leg details in the error message.
- If parent entry placement succeeds but linked profit exit placement fails, report the partial state clearly and do not silently place an unlinked exit order.

## Testing

Frontend:

- Checkbox unchecked preserves current cash-secured put payload and submit behavior.
- Checkbox checked requires a valid long put, net credit, and quantity.
- Spread preview formulas are correct.
- Profit exit debit is computed as 70% of entry credit.

Backend:

- Validation rejects invalid leg combinations.
- Combo order request builds the expected IB BAG contract and leg actions.
- Profit exit request uses the reverse combo action and correct limit debit.
- Existing single-leg sell put behavior is unchanged.

## Open Implementation Notes

- Confirm the actual current Option Orders page path/name during implementation. The visible repo has `strategy-orders`, `range-orders`, `trading-orders`, and option insight pages, but no literal `price-levels-30m` route in the current tree.
- Confirm whether the existing sell put submit path is handled by the Strategy Orders API, a not-yet-committed Option Orders page, or another local branch file.
