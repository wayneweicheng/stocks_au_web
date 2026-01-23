-- View: [StockData].[v_CourseOfSale]




CREATE view [StockData].[v_CourseOfSale]
as
select ASXCode, SaleDateTime, Price, ActBuySellInd, sum(Quantity) as Quantity 
from StockData.CourseOfSale
group by ASXCode, SaleDateTime, Price, ActBuySellInd

