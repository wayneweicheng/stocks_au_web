-- View: [StockData].[v_PriceSummary_Latest_Today]



CREATE view [StockData].[v_PriceSummary_Latest_Today]
as
select *
from
(
	select 
		*,
		null as PriceChangeVsPrevClose,
		null as PriceChangeVsOpen,
		row_number() over (partition by ASXCode order by ObservationDate desc) as RankNumber
	from StockData.v_PriceSummary_Latest with(nolock)
) as a
where RankNumber = 1
