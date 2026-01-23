-- View: [StockData].[v_LastTenDayAvgSaleValue]



CREATE view [StockData].[v_LastTenDayAvgSaleValue]
as
select a.ASXCode, avg(Price*Quantity) as AvgSaleValue 
from StockData.v_CourseOfSale as a
inner join 
(
	select
		ASXCode,
		SaleDate,
		row_number() over (partition by ASXCode order by SaleDate desc) as RowNumber
	from
	(
	select 
		ASXCode,
		cast(SaleDatetime as date) as SaleDate
	from StockData.CourseOfSale
	group by 
		ASXCode,
		cast(SaleDatetime as date)
	) as a
) as b
on a.ASXCode = b.ASXCode
and cast(a.SaleDateTime as date) = b.SaleDate
where b.RowNumber <= 10
and Price*Quantity <= case when Price < 1 then 50000
						   when Price >= 1 and Price < 2 then 80000
						   when Price >= 2 and Price < 5 then 120000
						   when Price >= 5 and Price < 10 then 200000
						   when Price >= 10 then 500000
					  end
and Price*Quantity >= 2000
group by a.ASXCode