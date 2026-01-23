-- View: [StockData].[v_MarketScan_Latest]




CREATE view [StockData].[v_MarketScan_Latest]
as
select *
from
(
	select 
		*, 
		row_number() over (partition by ASXCode, ObservationDate order by CreateDate desc) as RowNumber
	from [StockData].[v_MarketScan] as a
) as x
where x.RowNumber = 1
