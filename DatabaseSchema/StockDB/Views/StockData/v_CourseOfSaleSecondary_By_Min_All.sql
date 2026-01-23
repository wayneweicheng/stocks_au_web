-- View: [StockData].[v_CourseOfSaleSecondary_By_Min_All]



create view [StockData].[v_CourseOfSaleSecondary_By_Min_All]
as
select 
	max(CourseOfSaleSecondaryID) as CourseOfSaleSecondaryID,
	ASXCode, 
	ObservationDate,
	SaleDateTime, 
	sum(Quantity) as Quantity, 
	[Common].[RoundStockPrice](sum(Price*Quantity)*1.0/sum(Quantity)) as Price,
	'SMART' as Exchange,
	null as SpecialCondition,
	null as ActBuySellInd,
	cast(max(cast(DerivedInstitute as int)) as bit) as DerivedInstitute
from StockData.CourseOfSaleSecondary
where 1 = 1
and Quantity > 0
group by ASXCode, ObservationDate, SaleDateTime
