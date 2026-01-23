-- View: [BackTest].[v_BackTestTrade_Performance_Bak]







CREATE view [BackTest].[v_BackTestTrade_Performance]
as
select 
e.ExecutionStartDate,
a.ExecutionId, a.TradeTypeId, c.TradeTypeDescr, a.StockCode, a.OrderID,
a.OrderTime as EntryTime, a.OrderPrice as EntryPrice, a.OrderVolume as OrderVolume, 
b.OrderTime as ExitTime, b.OrderPrice as ExitPrice, 
cast((b.OrderPrice-a.OrderPrice)*1.0/a.OrderPrice as decimal(20, 4)) as ProfitLossPerc, 
cast((b.OrderPrice-a.OrderPrice) as decimal(20, 4)) as ProfitLoss,
datediff(minute, a.OrderTime, b.OrderTime) as Duration ,
a.CreateDate,
bte.ExecutionContext,
bte.StrategyFileName,
bte.OrderTypeId,
x.ASXCode
from [BackTest].[BackTestTrade] as a
inner join LookupRef.TradeType as c
on a.TradeTypeId = c.TradeTypeID
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
where c.TradeTypeDescr like 'Strategy-Stock-Buy%'
and a.BuySell = 'B'
and a.TradeStatus = 'FF'
