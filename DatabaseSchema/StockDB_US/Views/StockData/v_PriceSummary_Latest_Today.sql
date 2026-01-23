-- View: [StockData].[v_PriceSummary_Latest_Today]




CREATE view [StockData].[v_PriceSummary_Latest_Today]
as
select *
from
(
	select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
	from StockData.v_PriceSummary_Latest
) as a
where RowNumber = 1
