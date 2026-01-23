-- View: [StockData].[v_CalculatedGEX_V2]



CREATE view [StockData].[v_CalculatedGEX_V2]
as
select 
	a.ASXCode, 
	a.ObservationDate, 
	NoOfOption, 
	GEX,
	format(GEX, 'N0') as FormattedGEX,
	b.[Close]
from Transform.OptionGEXChange as a
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
where a.GEX is not null
