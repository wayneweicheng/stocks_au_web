-- View: [StockData].[v_StrategyResult]

CREATE view StockData.v_StrategyResult
as
select 
	*, 
	format(cast(json_value(StrategyResult, '$.Value') as decimal(20, 2)), 'N0') as TradeValue, 
	cast(json_value(StrategyResult, '$.PercChange') as decimal(20, 2)) as PercChange,
	cast(json_value(StrategyResult, '$.SMA20_trending_up') as int) as SMA20_trending_up,
	cast(json_value(StrategyResult, '$.Close') as decimal(20, 4)) as [Close],
	cast(json_value(StrategyResult, '$.SMA_5') as decimal(20, 3)) as [SMA_5],
	cast(json_value(StrategyResult, '$.SMA_10') as decimal(20, 3)) as [SMA_10],
	cast(json_value(StrategyResult, '$.SMA_20') as decimal(20, 3)) as [SMA_20],
	cast(json_value(StrategyResult, '$.SMA_30') as decimal(20, 3)) as [SMA_30],
	cast(json_value(StrategyResult, '$.Prev1SMA_5') as decimal(20, 3)) as [Prev1SMA_5],
	cast(json_value(StrategyResult, '$.Prev1SMA_10') as decimal(20, 3)) as [Prev1SMA_10],
	cast(json_value(StrategyResult, '$.Prev1SMA_20') as decimal(20, 3)) as [Prev1SMA_20],
	cast(json_value(StrategyResult, '$.Prev1SMA_30') as decimal(20, 3)) as [Prev1SMA_30]
from StockData.StrategyResult
where cast(json_value(StrategyResult, '$.Value') as decimal(20, 2)) > 800000
and cast(json_value(StrategyResult, '$.PercChange') as decimal(20, 2)) < 50
