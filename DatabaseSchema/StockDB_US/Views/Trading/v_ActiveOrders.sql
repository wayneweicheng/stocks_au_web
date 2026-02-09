-- View: [Trading].[v_ActiveOrders]


-- Views for convenience (no stored procedures)
CREATE   VIEW Trading.v_ActiveOrders
AS
SELECT
    o.OrderId,
    o.StrategyId,
    s.StrategyCode,
    o.StockCode,
    o.Side,
    o.OrderSourceType,
    o.SignalType,
    o.TimeFrame,
    o.EntryType,
    o.EntryPrice,
    o.Quantity,
    o.ProfitTargetPrice,
    o.StopLossPrice,
    o.StopLossMode,
    o.Status,
    o.EntryPlacedAt,
    o.EntryFilledAt,
    o.ExitPlacedAt,
    o.ExitFilledAt,
    o.StoplossPlacedAt,
    o.StoplossFilledAt,
    o.BacktestRunId,
    o.CreatedAt,
    o.UpdatedAt,
    o.MetaJson
FROM Trading.Orders o
INNER JOIN Trading.Strategy s ON s.StrategyId = o.StrategyId
WHERE o.Status IN ('PENDING', 'OPEN');
