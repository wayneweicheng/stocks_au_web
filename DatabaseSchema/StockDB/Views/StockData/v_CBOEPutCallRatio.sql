-- View: [StockData].[v_CBOEPutCallRatio]

create view StockData.v_CBOEPutCallRatio
as
select 
	*, lag(cboe_date, 1) over (order by cboe_date) as prev_cboe_date 
from StockData.CBOEPutCallRatio as a;