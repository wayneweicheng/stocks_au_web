-- View: [StockData].[v_IntradayIndexChanges]

create view StockData.v_IntradayIndexChanges
as
select 'SmallCap' as MarketCapType, *
from StockDB.StockData.IntradaySmallIndexChanges
union all
select 'MicroCap' as MarketCapType, *
from StockDB.StockData.IntradayMicroIndexChanges
union all
select 'MidLarge' as MarketCapType, *
from StockDB.StockData.IntradayMidLargeIndexChanges
