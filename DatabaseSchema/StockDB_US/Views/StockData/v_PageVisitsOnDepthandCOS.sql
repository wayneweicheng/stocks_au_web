-- View: [StockData].[v_PageVisitsOnDepthandCOS]


create view StockData.v_PageVisitsOnDepthandCOS
as
select * from StockData.RawData
where DataTypeID in (10, 20)
and 
(
	RawData like '{"AsxCode"%' 
	or
	RawData like '<CourseOfSale%' 
)
