-- View: [StockData].[v_CourseOfSaleSecondaryASX_By_Min]



CREATE view [StockData].[v_CourseOfSaleSecondaryASX_By_Min]
as
select 
	max(CourseOfSaleSecondaryID) as CourseOfSaleSecondaryID,
	ASXCode, 
	ObservationDate,
	SaleDateTime, 
	sum(Quantity) as Quantity, 
	[Common].[RoundStockPrice](avg(Price)) as Price,
	'ASX' as Exchange,
	null as SpecialCondition,
	null as ActBuySellInd,
	cast(max(cast(DerivedInstitute as int)) as bit) as DerivedInstitute
from StockData.CourseOfSaleSecondary
where ExChange = 'ASX'
group by ASXCode, ObservationDate, SaleDateTime
