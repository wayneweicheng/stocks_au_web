-- View: [Transform].[v_QQQOptionMoneyFlow]


CREATE view [Transform].[v_NASDAQOptionMoneyFlow]
as
select 
	*,
	case when (SwingIndicator = 'Swing Up' and TomorrowChange > 0.2) or (SwingIndicator = 'Swing Down' and TomorrowChange < -0.2) then 1
		 when (SwingIndicator = 'Swing Down' and TomorrowChange > 0.2) or (SwingIndicator = 'Swing Up' and TomorrowChange < -0.2) then 0
	end as IsSuccessful
from
(
	select 
		a.ASXCode, a.ObservationDate, a.ExpiryDate, 
		a.ShortLongRatio as RetailShortLongRatio, b.ShortLongRatio as SmartShortLongRatio, 
		a.ShortSize as RetailShortSize, b.ShortSize as SmartShortSize, 
		a.ShortGEX as RetailShortGEX, b.ShortGEX as SmartShortGEX, 
		a.ShortMinusLongSize as RetailShortMinusLongSize, b.ShortMinusLongSize as SmartShortMinusLongSize, 
		a.ShortMinusLongGEX as RetailShortMinusLongGEX, b.ShortMinusLongGEX as SmartShortMinusLongGEX,
		cast(b.ShortMinusLongGEX*100.0/b.ShortGEX as decimal(10, 2)) as ShortMinusLongGEXPerc,
		a.CreateDate, d.TomorrowChange,
		case when b.ShortLongRatio > a.ShortLongRatio*1.01 and b.ShortLongRatio > 1 and isnull(abs(cast(b.ShortMinusLongGEX*100.0/b.ShortGEX as decimal(10, 2))), 5) > 3.0 then 'Swing down' 
			 when b.ShortLongRatio < a.ShortLongRatio*0.99 and b.ShortLongRatio < 1 and isnull(abs(cast(b.ShortMinusLongGEX*100.0/b.ShortGEX as decimal(10, 2))), 5) > 3.0 then 'Swing Up' 
		else 'No Signal'
		end as SwingIndicator
	from
	(
		select * from StockDB_US.[Transform].[OptionTradeByExpiryDate]
		where 1 = 1
		and MoneyType = 'Dump'
	) as a
	inner join
	(
		select * from StockDB_US.[Transform].[OptionTradeByExpiryDate]
		where 1 = 1
		and MoneyType = 'Smart'
	) as b
	on a.ObservationDate = b.ObservationDate
	and a.ExpiryDate = b.ExpiryDate
	and a.ASXCode = b.ASXCode
	inner join 
	(
		select ASXCode, ObservationDate, min(ExpiryDate) as ExpiryDate from StockDB_US.[Transform].[OptionTradeByExpiryDate]
		group by ASXCode, ObservationDate
	) as c
	on a.ObservationDate = c.ObservationDate
	and a.ExpiryDate = c.ExpiryDate
	and a.ASXCode = c.ASXCode
	left join StockDB.StockData.v_PriceHistory as d
	on a.ObservationDate = d.ObservationDate
	and d.ASXCode = 'NASDAQ'
	where a.ObservationDate >= '2022-10-13'
	and a.ASXCode = 'QQQ.US'
) as x
