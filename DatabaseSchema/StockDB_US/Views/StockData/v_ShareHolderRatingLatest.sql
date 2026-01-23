-- View: [StockData].[v_ShareHolderRatingLatest]


create view StockData.v_ShareHolderRatingLatest
as
select *
from
(
	select 
		*,
		row_number() over (partition by ShareHolder, StockType, DaysGoBack order by ReportPeriod desc) as RowNumber
	from StockData.ShareHolderRating
) as a
where RowNumber = 1
