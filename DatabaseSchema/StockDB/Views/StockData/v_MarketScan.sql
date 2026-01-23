-- View: [StockData].[v_MarketScan]


CREATE view [StockData].[v_MarketScan]
as
select 
	*, 
	case when len(a.ScanResultJson) > 0 then cast(JSON_VALUE(a.ScanResultJson, '$.PriceChange') as numeric(20, 2)) else null end as PriceChange,
	case when len(a.ScanResultJson) > 0 then cast(cast(JSON_VALUE(a.ScanResultJson, '$.TradeValue') as numeric(20, 2))/1000 as int) else null end as TradeValue,
	case when len(a.ScanResultJson) > 0 then cast(JSON_VALUE(a.ScanResultJson, '$.Close') as numeric(20, 4)) else null end as ClosePrice,
	case when len(a.ScanResultJson) > 0 then cast(JSON_VALUE(a.ScanResultJson, '$.Vwap') as numeric(20, 4)) else null end as Vwap
from StockData.MarketScan as a

