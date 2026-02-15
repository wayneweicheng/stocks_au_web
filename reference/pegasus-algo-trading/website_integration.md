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
- `SignalType` (PK) e.g. `SMA_UP`, `DRAGONFLY`
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
- `SignalType` must be set (e.g. `SMA_UP`, `DRAGONFLY`).
- Website provides `SignalType`, `StopLossPrice`, `ProfitTargetPrice`, `Quantity`.
- `EntryPrice` is optional: if NULL and `EntryType='LIMIT'`, the strategy will set the entry price to the bar close when the signal triggers.
- Manual orders take precedence over signals per stock (if a manual order exists for a stock, signals for that stock are ignored in live mode).

## Create Order (Insert)

Example (manual order):

```
INSERT INTO Trading.Orders
    (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
     ProfitTargetPrice, StopLossPrice, StopLossMode, Status, CreatedAt, UpdatedAt)
VALUES
    (1, 'QQQ.US', 'B', 'MANUAL', NULL, '5M', 'LIMIT', 605.80, 100,
     611.00, 600.00, 'BAR_CLOSE', 'PENDING', GETDATE(), GETDATE());
```

Example (signal order):

```
INSERT INTO Trading.Orders
    (StrategyId, StockCode, Side, OrderSourceType, SignalType, TimeFrame, EntryType, EntryPrice, Quantity,
     ProfitTargetPrice, StopLossPrice, StopLossMode, Status, CreatedAt, UpdatedAt)
VALUES
    (1, 'QQQ.US', 'B', 'SIGNAL', 'SMA_UP', '5M', 'LIMIT', 605.80, 100,
     611.00, 600.00, 'BAR_CLOSE', 'PENDING', GETDATE(), GETDATE());
```

## Modify Order (Update)

You may update fields only while `Status` is `PENDING` or `PLACED`.
Do not modify `EntryFilledAt`, `ExitFilledAt`, `StoplossFilledAt`.

Example:

```
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

```
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

```
SELECT SignalType, Description
FROM Trading.SignalType
WHERE IsActive = 1
ORDER BY SignalType;
```

## Active Orders View

Use `Trading.v_ActiveOrders` for display:

```
SELECT * FROM Trading.v_ActiveOrders WHERE StockCode = 'QQQ.US';
```

## Notes

- The engine will update timestamps and statuses during live/backtest.
- The website should only set timestamps if explicitly needed; normally leave them `NULL`.
- Manual orders override signal orders for the same stock.

## Performance & Reports (Basic)

### 1) Closed Orders Summary

```
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

### 2) Simple PnL Estimate (Long Only)

```
SELECT
    o.OrderId,
    o.StockCode,
    o.OrderSourceType,
    o.SignalType,
    o.EntryFilledAt,
    o.ExitFilledAt,
    f_entry.FillPrice AS EntryFill,
    f_exit.FillPrice AS ExitFill,
    (f_exit.FillPrice - f_entry.FillPrice) * o.Quantity AS PnL
FROM Trading.Orders o
JOIN Trading.OrderFills f_entry
    ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
JOIN Trading.OrderFills f_exit
    ON f_exit.OrderId = o.OrderId AND f_exit.FillType = 'EXIT'
WHERE o.Status = 'CLOSED'
ORDER BY o.EntryFilledAt DESC;
```

### 3) Win/Loss by Signal Type

```
SELECT
    o.SignalType,
    COUNT(*) AS Trades,
    SUM(CASE WHEN f_exit.FillPrice > f_entry.FillPrice THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN f_exit.FillPrice <= f_entry.FillPrice THEN 1 ELSE 0 END) AS Losses
FROM Trading.Orders o
JOIN Trading.OrderFills f_entry
    ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
JOIN Trading.OrderFills f_exit
    ON f_exit.OrderId = o.OrderId AND f_exit.FillType = 'EXIT'
WHERE o.Status = 'CLOSED'
GROUP BY o.SignalType
ORDER BY Trades DESC;
```

### 4) Active Orders Dashboard

```
SELECT * FROM Trading.v_ActiveOrders ORDER BY StockCode, CreatedAt;
```

### 5) Stop Loss Trailing History

```
SELECT *
FROM Trading.StopLossHistory
WHERE OrderId = 123
ORDER BY ChangedAt ASC;
```

### 2b) Simple PnL Estimate (Short Only)

```
SELECT
    o.OrderId,
    o.StockCode,
    o.OrderSourceType,
    o.SignalType,
    o.EntryFilledAt,
    o.ExitFilledAt,
    f_entry.FillPrice AS EntryFill,
    f_exit.FillPrice AS ExitFill,
    (f_entry.FillPrice - f_exit.FillPrice) * o.Quantity AS PnL
FROM Trading.Orders o
JOIN Trading.OrderFills f_entry
    ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
JOIN Trading.OrderFills f_exit
    ON f_exit.OrderId = o.OrderId AND f_exit.FillType = 'EXIT'
WHERE o.Status = 'CLOSED'
  AND o.Side = 'S'
ORDER BY o.EntryFilledAt DESC;
```


## Backtest Identification

Backtests create a row in `Trading.BacktestRuns` and tag any orders created during that run with `BacktestRunId` in `Trading.Orders`.

### BacktestRuns Table

```
SELECT * FROM Trading.BacktestRuns ORDER BY StartedAt DESC;
```

### Orders by BacktestRunId

```
SELECT * FROM Trading.Orders WHERE BacktestRunId = '<run-id>';
```

### Reporting by BacktestRun

Show PnL by run (requires fills):
```
SELECT o.BacktestRunId,
       COUNT(*) AS Trades,
       SUM(CASE WHEN f_exit.FillPrice > f_entry.FillPrice THEN 1 ELSE 0 END) AS Wins,
       SUM(CASE WHEN f_exit.FillPrice <= f_entry.FillPrice THEN 1 ELSE 0 END) AS Losses,
       SUM((f_exit.FillPrice - f_entry.FillPrice) * o.Quantity) AS PnL
FROM Trading.Orders o
JOIN Trading.OrderFills f_entry ON f_entry.OrderId = o.OrderId AND f_entry.FillType = 'ENTRY'
JOIN Trading.OrderFills f_exit  ON f_exit.OrderId  = o.OrderId AND f_exit.FillType  = 'EXIT'
WHERE o.BacktestRunId = '<run-id>'
GROUP BY o.BacktestRunId;
```

List recent runs:
```
SELECT BacktestRunId, StartedAt, EndedAt, StrategyCode, StockCode, TimeFrame, OrderSourceMode
FROM Trading.BacktestRuns
ORDER BY StartedAt DESC;
```
