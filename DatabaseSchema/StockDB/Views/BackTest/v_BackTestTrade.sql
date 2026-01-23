-- View: [BackTest].[v_BackTestTrade]





CREATE view [BackTest].[v_BackTestTrade]
as
select 
	a.OrderID,
	a.TradeTypeId, 
	a.ExecutionId, 
	a.TradeUUId, 
	a.StockCode, 
	a.OrderTime as BuyOrderTime, 
	a.OrderPrice as BuyPrice, 
	b.OrderPrice as SellPrice,
	a.OrderVolume, 
	b.OrderTime as SellOrderTime,
	cast((b.OrderPrice - a.OrderPrice)*100.0/a.OrderPrice as decimal(10, 2)) as PriceChange,
	a.CreateDate
from BackTest.BackTestTrade as a
full outer join BackTest.BackTestTrade as b
on a.OrderID = b.OrderID
and b.BuySell = 'S'
where a.BuySell = 'B'

