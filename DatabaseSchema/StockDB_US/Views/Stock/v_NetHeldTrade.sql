-- View: [Stock].[v_NetHeldTrade]


CREATE view [Stock].[v_NetHeldTrade]
as
	select 
		   [ASXCode]
		  ,UserID
		  ,sum(case when TradeType = 1 then 1.0*[Volume] else -1.0*Volume end) as NetVolumn
	from Stock.Trade as a
	where TradeType in (1, 2)
	group by a.UserID, a.ASXCode
	having sum(case when TradeType = 1 then 1.0*[Volume] else -1.0*Volume end) >  0
