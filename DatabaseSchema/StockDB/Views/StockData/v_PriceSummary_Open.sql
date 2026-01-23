-- View: [StockData].[v_PriceSummary_Open]


create view StockData.v_PriceSummary_Open
as
select *
from
(
	select 
		cast(case when [Close] > 0 then ([Open]-[PrevClose])*100.0/[PrevClose] else null end as decimal(10, 2)) as OpenVsPrevClose,
		*, 
		row_number() over (partition by ObservationDate, ASXCode order by DateFrom) as RowNumber
	from StockData.v_PriceSummary as a
	where 1 = 1
	and [Volume] > 0
) as x
where RowNumber = 1
