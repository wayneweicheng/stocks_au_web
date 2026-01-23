-- View: [StockData].[v_PlaceHistory_Latest]


CREATE view [StockData].[v_PlaceHistory_Latest]
as
select *
from
(
	select 
		*,
		row_number() over (partition by ASXCode order by PlacementDate desc) as RowNumber
	from [StockData].[PlaceHistory] with(nolock)
) as a
where RowNumber = 1
