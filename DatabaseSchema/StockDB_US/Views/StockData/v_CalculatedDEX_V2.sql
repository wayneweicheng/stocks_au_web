-- View: [StockData].[v_CalculatedDEX_V2]




CREATE view [StockData].[v_CalculatedDEX_V2]
as
select 
	a.ASXCode, 
	a.ObservationDate, 
	count(*) as NoOfOption, 
	sum(case when PorC = 'C' then 1 else 1 end*Delta*100*OpenInterest*1.0) as DEX,
	format(sum(case when PorC = 'C' then 1 else 1 end*Delta*100*OpenInterest*1.0), 'N0') as FormattedDEX,
	b.[Close]
from StockData.v_OptionDelayedQuote_V2 as a
left join 
(
	select 
		b.ASXCode,
		b.ObservationDate,
		b.[Close]
	from StockData.PriceHistory as b
	union all
	select 
		'SPX.US' as ASXCode,
		b.ObservationDate,
		b.[Close]
	from StockDB.StockData.PriceHistory as b
	where ASXCode = 'SPX'
	union all
	select 
		'_VIX.US' as ASXCode,
		b.ObservationDate,
		b.[Close]
	from StockDB.StockData.PriceHistory as b
	where ASXCode = 'VIX'	
	union all	
	select 
		'SPXW.US' as ASXCode,
		b.ObservationDate,
		b.[Close]
	from StockDB.StockData.PriceHistory as b
	where ASXCode = 'SPX'
) as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate
--and PorC = 'P'
where a.ObservationDate <= a.ExpiryDate
group by a.ASXCode, a.ObservationDate, b.[Close]

