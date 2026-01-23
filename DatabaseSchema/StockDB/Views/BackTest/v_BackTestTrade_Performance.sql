-- View: [BackTest].[v_BackTestTrade_Performance]












CREATE view [BackTest].[v_BackTestTrade_Performance]
as
select 
100000 as InitialCashPosition,
e.ExecutionStartDate,
a.ExecutionId, a.TradeTypeId, a.StockCode, a.OrderID,
a.OrderTime as EntryTime, a.OrderPrice as EntryPrice, floor(100000.0*4/a.OrderPrice) as OrderVolume, 
b.OrderTime as ExitTime, b.OrderPrice as ExitPrice, 
cast((b.OrderPrice-a.OrderPrice)*1.0/a.OrderPrice as decimal(20, 4)) as ProfitLossPerc, 
cast((b.OrderPrice-a.OrderPrice) as decimal(20, 4))*floor(100000.0*4/a.OrderPrice) as ProfitLoss,
datediff(minute, a.OrderTime, b.OrderTime) as Duration ,
a.ConditionCode as BuyConditionCode,
b.ConditionCode as SellConditionCode,
a.RSI as BuyRSI,
b.RSI as SellRSI,
a.CreateDate,
bte.ExecutionContext,
bte.StrategyFileName,
bte.OrderTypeId,
x.ASXCode
from [BackTest].[BackTestTrade] as a
inner join
(
	select 
		ExecutionId,
		min(CreateDate) as ExecutionStartDate
	from [BackTest].[BackTestTrade]
	group by ExecutionId
) as e
on a.ExecutionId = e.ExecutionId
left join [BackTest].[BackTestTrade] as b
on a.ExecutionId = b.ExecutionId
and a.OrderID = b.OrderID
and b.BuySell = 'S'
and b.TradeStatus = 'FF'
left join BackTest.BackTestExecution as bte
on a.ExecutionId = bte.ExecutionId
left join [BackTest].[Order] as x
on a.OrderID = x.OrderID
where 1 = 1
and a.BuySell = 'B'
and a.TradeStatus = 'FF'
