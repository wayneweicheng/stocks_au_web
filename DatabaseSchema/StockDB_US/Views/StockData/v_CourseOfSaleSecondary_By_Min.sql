-- View: [StockData].[v_CourseOfSaleSecondary_By_Min]




CREATE view [StockData].[v_CourseOfSaleSecondary_By_Min]
as
select 
	max(CourseOfSaleSecondaryTodayID) as CourseOfSaleSecondaryID,
	ASXCode, 
	ObservationDate,
	SaleDateTime, 
	sum(Quantity) as Quantity, 
	[Common].[RoundStockPrice](avg(Price)) as Price,
	'SMART' as Exchange,
	null as SpecialCondition,
	null as ActBuySellInd,
	cast(max(cast(DerivedInstitute as int)) as bit) as DerivedInstitute
from StockData.CourseOfSaleSecondaryToday
where 1 = 1
and Quantity > 0
group by ASXCode, ObservationDate, SaleDateTime
