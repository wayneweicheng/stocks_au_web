-- View: [Transform].[v_SPXOptionMoneyFlow_Agg]







create view [Transform].[v_SPXOptionMoneyFlow_Agg]
as

with mf as
(
	select 
		a.ASXCode, 
		a.ObservationDate, 
		--a.ExpiryDate, 
		cast(sum(a.ShortGEX)*1.0/sum(a.LongGEX) as [numeric](38, 6)) as RetailShortLongRatio, 
		cast(sum(b.ShortGEX)*1.0/sum(b.LongGEX) as [numeric](38, 6)) as SmartShortLongRatio, 
		sum(a.ShortSize) as RetailShortSize, 
		sum(b.ShortSize) as SmartShortSize, 
		sum(a.ShortGEX) as RetailShortGEX, 
		sum(b.ShortGEX) as SmartShortGEX, 
		sum(a.ShortMinusLongSize) as RetailShortMinusLongSize, 
		sum(b.ShortMinusLongSize) as SmartShortMinusLongSize, 
		sum(a.ShortMinusLongGEX) as RetailShortMinusLongGEX, 
		sum(b.ShortMinusLongGEX) as SmartShortMinusLongGEX,
		cast(sum(b.ShortMinusLongGEX)*100.0/sum(b.ShortGEX) as decimal(10, 2)) as ShortMinusLongGEXPerc,
		a.CreateDate, d.TomorrowChange,
		case when sum(b.ShortGEX)*1.0/sum(b.LongGEX) > sum(a.ShortGEX)*1.0/sum(a.LongGEX)*1.01 and sum(b.ShortGEX)*1.0/sum(b.LongGEX) > 1 and isnull(abs(cast(sum(b.ShortMinusLongGEX)*100.0/sum(b.ShortGEX) as decimal(10, 2))), 5) > 2.5 then 'Swing down' 
			 when sum(b.ShortGEX)*1.0/sum(b.LongGEX) > sum(a.ShortGEX)*1.0/sum(a.LongGEX)*0.99 and sum(b.ShortGEX)*1.0/sum(b.LongGEX) > 1.03 and isnull(abs(cast(sum(b.ShortMinusLongGEX)*100.0/sum(b.ShortGEX) as decimal(10, 2))), 5) > 2.5 then 'Swing down' 
			 when sum(b.ShortGEX)*1.0/sum(b.LongGEX) < sum(a.ShortGEX)*1.0/sum(a.LongGEX)*0.99 and sum(b.ShortGEX)*1.0/sum(b.LongGEX) < 1 and isnull(abs(cast(sum(b.ShortMinusLongGEX)*100.0/sum(b.ShortGEX) as decimal(10, 2))), 5) > 2.5 then 'Swing Up' 
			 when sum(b.ShortGEX)*1.0/sum(b.LongGEX) < sum(a.ShortGEX)*1.0/sum(a.LongGEX)*1.01 and sum(b.ShortGEX)*1.0/sum(b.LongGEX) < 0.97 and isnull(abs(cast(sum(b.ShortMinusLongGEX)*100.0/sum(b.ShortGEX) as decimal(10, 2))), 5) > 2.5 then 'Swing Up' 
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
	--inner join 
	--(
	--	select ASXCode, ObservationDate, min(ExpiryDate) as ExpiryDate from StockDB_US.[Transform].[OptionTradeByExpiryDate]
	--	group by ASXCode, ObservationDate
	--) as c
	--on a.ObservationDate = c.ObservationDate
	--and a.ExpiryDate = c.ExpiryDate
	--and a.ASXCode = c.ASXCode
	left join StockDB.StockData.v_PriceHistory as d
	on a.ObservationDate = d.ObservationDate
	and d.ASXCode = 'SPX'
	where a.ObservationDate >= '2022-10-13'
	and a.ASXCode = 'SPX.US'
	and a.ShortGEX is not null
	group by 
		a.ASXCode, 
		a.ObservationDate,
		a.CreateDate, 
		d.TomorrowChange
)

select 
	*,
	case when (SwingIndicator = 'Swing Up' and TomorrowChange > 0.2) or (SwingIndicator = 'Swing Down' and TomorrowChange < -0.2) then 1
		 when (SwingIndicator = 'Swing Down' and TomorrowChange > 0.2) or (SwingIndicator = 'Swing Up' and TomorrowChange < -0.2) then 0
	end as IsSuccessful
from
(
	select * from mf
) as x
