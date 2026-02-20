# Website Integration Guide (Trading Orders)

This document describes how the website should create, modify, and manage orders in the database for the Pegasus trading framework.

**Database**: `StockDB_US`

## Core Tables

The website mainly interacts with these tables:

1. `Trading.Strategy`
2. `Trading.Orders`
3. `Trading.SignalType`

Optional read-only / reporting tables:
- `Trading.OrderFills`
- `Trading.StopLossHistory`
- `Trading.v_ActiveOrders` (view)

## Table: Trading.Strategy

Stores strategy definitions. Website should reference by `StrategyId` or `StrategyCode`.

Key columns:
- `StrategyId` (PK)
- `StrategyCode` (unique, e.g. `SUPPORT_BOUNCE`)
- `IsActive`

## Table: Trading.SignalType

Defines supported signal types for dropdowns.

Key columns:
- `SignalType` (PK) e.g. `SMA_UP`, `SMA_DOWN`, `DRAGONFLY`
- `Description`
- `IsActive`

Website should load active signal types for signal order creation.

## Table: Trading.Orders

This is the main table for orders.

Key columns used by the website:
- `OrderId` (PK)
- `StrategyId` (FK to `Trading.Strategy`)
- `StockCode` (e.g. `QQQ.US`)
- `Side` (`B` or `S`)
- `OrderSourceType` (`MANUAL` or `SIGNAL`)
- `SignalType` (nullable, must exist in `Trading.SignalType`)
- `TimeFrame` (e.g. `5M`)
- `EntryType` (`LIMIT` or `MARKET`)
- `EntryPrice` (nullable for market orders)
- `Quantity`
- `ProfitTargetPrice` (nullable)
- `StopLossPrice` (nullable)
- `StopLossMode` (currently `BAR_CLOSE`)
- `Status` (`PENDING`, `PLACED`, `OPEN`, `CLOSED`, `CANCELLED`)
- `BacktestRunId` (nullable, FK to `Trading.BacktestRuns`; typically NULL for website-created orders; set automatically for backtests)
- Timestamps: `EntryPlacedAt`, `EntryFilledAt`, `ExitPlacedAt`, `ExitFilledAt`, `StoplossPlacedAt`, `StoplossFilledAt`
- `CreatedAt`, `UpdatedAt`

## Long vs Short Semantics

`Side` defines the position direction. `Quantity` is always positive.

- `Side='B'` (Long):
  - Entry sent to broker as `BUY`.
  - Exit / profit target / stop-loss sent to broker as `SELL`.
  - Backtest profit target triggers when `bar.high >= ProfitTargetPrice`.
  - Backtest stop loss triggers when `bar.close <= StopLossPrice`.

- `Side='S'` (Short):
  - Entry sent to broker as `SELL` (short sell).
  - Exit / profit target / stop-loss sent to broker as `BUY` (buy-to-cover).
  - Backtest profit target triggers when `bar.low <= ProfitTargetPrice`.
  - Backtest stop loss triggers when `bar.close >= StopLossPrice`.

Recommended website validations:
- Long: `ProfitTargetPrice > EntryPrice` and `StopLossPrice < EntryPrice`.
- Short: `ProfitTargetPrice < EntryPrice` and `StopLossPrice > EntryPrice`.

## Feature Flags (Runtime)

- `ENABLE_SHORTING=true` is required for the engine to place entries for any `Side='S'` order (both backtest and live).
- Strategy-generated short signals are separately gated per strategy. For `support_bounce`, set `SUPPORT_BOUNCE_ENABLE_SHORTS=true`.

Note: The broker may still reject short sells due to account permissions, margin, or borrow/locate requirements.

## Status Lifecycle (Live + Backtest)

- `PENDING`: order is created, not placed to broker yet.
- `PLACED`: entry order sent to broker.
- `OPEN`: entry filled.
- `CLOSED`: position fully exited.
- `CANCELLED`: order cancelled by user/system.

## Manual vs Signal Orders

### Manual Order
- `OrderSourceType = 'MANUAL'`
- `SignalType = NULL`
- Website provides `EntryPrice`, `StopLossPrice`, and `ProfitTargetPrice`.

### Signal Order
- `OrderSourceType = 'SIGNAL'`
- `SignalType` must be set (e.g. `SMA_UP`, `SMA_DOWN`, `DRAGONFLY`).
- Website provides `SignalType`, `StopLossPrice`, `ProfitTargetPrice`, `Quantity`.
- `EntryPrice` is optional: if NULL and `EntryType='LIMIT'`, the strategy will set the entry price to the bar close when the signal triggers.
- Manual orders take precedence over signals per stock (if a manual order exists for a stock, signals for that stock are ignored in live mode).

## Create Order (Insert)

Example (manual long order):

```sql
INSERT INTO Trading.Orders
    (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
     ProfitTargetPrice, StopLossPrice, StopLossMode, Status, CreatedAt, UpdatedAt)
VALUES
    (1, 'QQQ.US', 'B', 'MANUAL', NULL, '5M', 'LIMIT', 605.80, 100,
     611.00, 600.00, 'BAR_CLOSE', 'PENDING', GETDATE(), GETDATE());
```

Example (manual short order):

```sql
INSERT INTO Trading.Orders
    (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
     ProfitTargetPrice, StopLossPrice, StopLossMode, Status, CreatedAt, UpdatedAt)
VALUES
    (1, 'QQQ.US', 'S', 'MANUAL', NULL, '5M', 'LIMIT', 605.80, 100,
     600.00, 611.00, 'BAR_CLOSE', 'PENDING', GETDATE(), GETDATE());
```

Example (signal long order):

```sql
INSERT INTO Trading.Orders
    (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
     ProfitTargetPrice, StopLossPrice, StopLossMode, Status, CreatedAt, UpdatedAt)
VALUES
    (1, 'QQQ.US', 'B', 'SIGNAL', 'SMA_UP', '5M', 'LIMIT', NULL, 100,
     611.00, 600.00, 'BAR_CLOSE', 'PENDING', GETDATE(), GETDATE());
```

Example (signal short order):

```sql
INSERT INTO Trading.Orders
    (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
     ProfitTargetPrice, StopLossPrice, StopLossMode, Status, CreatedAt, UpdatedAt)
VALUES
    (1, 'QQQ.US', 'S', 'SIGNAL', 'SMA_DOWN', '5M', 'LIMIT', NULL, 100,
     600.00, 611.00, 'BAR_CLOSE', 'PENDING', GETDATE(), GETDATE());
```

## Modify Order (Update)

You may update fields only while `Status` is `PENDING` or `PLACED`.
Do not modify `EntryFilledAt`, `ExitFilledAt`, `StoplossFilledAt`.

Example:

```sql
UPDATE Trading.Orders
SET EntryPrice = 606.10,
    StopLossPrice = 601.00,
    ProfitTargetPrice = 612.00,
    UpdatedAt = GETDATE()
WHERE OrderId = 123
  AND Status IN ('PENDING', 'PLACED');
```

## Cancel Order (Soft Delete)

Use `CANCELLED` instead of deleting rows.

```sql
UPDATE Trading.Orders
SET Status = 'CANCELLED',
    UpdatedAt = GETDATE()
WHERE OrderId = 123
  AND Status IN ('PENDING', 'PLACED');
```

## Deleting Orders (Not Recommended)

Avoid `DELETE`. Keep history for audit and performance tracking.

## Signal Type Dropdown

Populate dropdown from `Trading.SignalType`:

```sql
SELECT SignalType, Description
FROM Trading.SignalType
WHERE IsActive = 1
ORDER BY SignalType;
```

## Active Orders View

Use `Trading.v_ActiveOrders` for display:

```sql
SELECT * FROM Trading.v_ActiveOrders WHERE StockCode = 'QQQ.US';
```

## Notes

- The engine will update timestamps and statuses during live/backtest.
- The website should only set timestamps if explicitly needed; normally leave them `NULL`.
- Manual orders override signal orders for the same stock.

## Performance & Reports (Basic)

### 1) Closed Orders Summary

```sql
SELECT
    o.OrderId,
    o.StockCode,
    o.Side,
    o.OrderSourceType,
    o.SignalType,
    o.EntryFilledAt,
    o.ExitFilledAt,
    o.StoplossFilledAt,
    o.EntryPrice,
    o.ProfitTargetPrice,
    o.StopLossPrice,
    f_exit.FillPrice AS ExitFillPrice
FROM Trading.Orders o
LEFT JOIN Trading.OrderFills f_exit
    ON f_exit.OrderId = o.OrderId AND f_exit.FillType = 'EXIT'
WHERE o.Status = 'CLOSED'
ORDER BY o.EntryFilledAt DESC;
```

### 2) Simple PnL Estimate (Long + Short)

```sql
SELECT
    o.OrderId,
    o.StockCode,
    o.Side,
    o.OrderSourceType,
    o.SignalType,
    o.EntryFilledAt,
    o.ExitFilledAt,
    f_entry.FillPrice AS EntryFill,
    f_exit.FillPrice AS ExitFill,
    CASE
        WHEN o.Side = 'B' THEN (f_exit.FillPrice - f_entry.FillPrice) * o.Quantity
        WHEN o.Side = 'S' THEN (f_entry.FillPrice - f_exit.FillPrice) * o.Quantity
        ELSE NULL
    END AS PnL
FROM Trading.Orders o
JOIN Trading.OrderFills f_entry
    ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
JOIN Trading.OrderFills f_exit
    ON f_exit.OrderId = o.OrderId AND f_exit.FillType = 'EXIT'
WHERE o.Status = 'CLOSED'
ORDER BY o.EntryFilledAt DESC;
```

### 3) Win/Loss by Signal Type (Direction-Aware)

```sql
WITH pnl AS (
    SELECT
        o.SignalType,
        CASE
            WHEN o.Side = 'B' THEN (f_exit.FillPrice - f_entry.FillPrice) * o.Quantity
            WHEN o.Side = 'S' THEN (f_entry.FillPrice - f_exit.FillPrice) * o.Quantity
            ELSE 0
        END AS PnL
    FROM Trading.Orders o
    JOIN Trading.OrderFills f_entry
        ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
    JOIN Trading.OrderFills f_exit
        ON f_exit.OrderId = o.OrderId AND f_exit.FillType = 'EXIT'
    WHERE o.Status = 'CLOSED'
)
SELECT
    SignalType,
    COUNT(*) AS Trades,
    SUM(CASE WHEN PnL > 0 THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN PnL <= 0 THEN 1 ELSE 0 END) AS Losses,
    SUM(PnL) AS TotalPnL
FROM pnl
GROUP BY SignalType
ORDER BY Trades DESC;
```

### 4) Active Orders Dashboard

```sql
SELECT * FROM Trading.v_ActiveOrders ORDER BY StockCode, CreatedAt;
```

### 5) Stop Loss Trailing History

```sql
SELECT *
FROM Trading.StopLossHistory
WHERE OrderId = 123
ORDER BY ChangedAt ASC;
```

## Backtest Identification

Backtests create a row in `Trading.BacktestRuns` and tag any orders created during that run with `BacktestRunId` in `Trading.Orders`.

### BacktestRuns Table

```sql
SELECT * FROM Trading.BacktestRuns ORDER BY StartedAt DESC;
```

### Orders by BacktestRunId

```sql
SELECT * FROM Trading.Orders WHERE BacktestRunId = '<run-id>';
```

### Reporting by BacktestRun (Direction-Aware)

Show PnL by run (requires fills):

```sql
WITH pnl AS (
    SELECT
        o.BacktestRunId,
        CASE
            WHEN o.Side = 'B' THEN (f_exit.FillPrice - f_entry.FillPrice) * o.Quantity
            WHEN o.Side = 'S' THEN (f_entry.FillPrice - f_exit.FillPrice) * o.Quantity
            ELSE 0
        END AS PnL
    FROM Trading.Orders o
    JOIN Trading.OrderFills f_entry ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
    JOIN Trading.OrderFills f_exit  ON f_exit.OrderId  = o.OrderId AND f_exit.FillType  = 'EXIT'
    WHERE o.BacktestRunId = '<run-id>'
)
SELECT
    BacktestRunId,
    COUNT(*) AS Trades,
    SUM(CASE WHEN PnL > 0 THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN PnL <= 0 THEN 1 ELSE 0 END) AS Losses,
    SUM(PnL) AS PnL
FROM pnl
GROUP BY BacktestRunId;
```

List recent runs:

```sql
SELECT BacktestRunId, StartedAt, EndedAt, StrategyCode, StockCode, TimeFrame, OrderSourceMode
FROM Trading.BacktestRuns
ORDER BY StartedAt DESC;
```
