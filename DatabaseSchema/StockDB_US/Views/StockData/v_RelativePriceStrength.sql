-- View: [StockData].[v_RelativePriceStrength]


CREATE view StockData.v_RelativePriceStrength
as
select 
	a.ASXCode,
	a.ObservationDate,
	a.PriceChange,
	a.PriceChangeRank,
	cast(a.RelativePriceStrength as decimal(10, 2)) as RelativePriceStrength
from StockData.RelativePriceStrength as a
inner join
(
	select ASXCode, max(ObservationDate) as ObservationDate
	from StockData.RelativePriceStrength
	group by ASXCode
) as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate
