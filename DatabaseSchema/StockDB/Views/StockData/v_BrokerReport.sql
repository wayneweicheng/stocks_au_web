-- View: [StockData].[v_BrokerReport]


CREATE view [StockData].[v_BrokerReport]
as
select 
	a.BrokerDayReportID as BrokerReportID,
	c.BrokerCode as BrokerCode,
	a.ASXCode + '.AX' as ASXCode,
	a.ObservationDate,
	a.ASXCode as Symbol,
	a.BuyValue,
	a.SellValue,
	a.BuyValue - a.SellValue as NetValue,
	a.TotalValue,
	cast(a.BuyValue*1.0/(b.Value/b.Volume) as int) as BuyVolume,
	cast(a.SellValue*1.0/(b.Value/b.Volume) as int) as SellVolume,
	cast(a.BuyValue*1.0/(b.Value/b.Volume) as int) - cast(a.SellValue*1.0/(b.Value/b.Volume) as int) as NetVolume,
	cast(a.BuyValue*1.0/(b.Value/b.Volume) as int) + cast(a.SellValue*1.0/(b.Value/b.Volume) as int) as TotalVolume,
	1 as NoBuys,
	1 as NoSells,
	1 as Trades,
	cast(b.Value/b.Volume as decimal(10, 4)) as BuyPrice,
	cast(b.Value/b.Volume as decimal(10, 4)) as SellPrice,
	null as PercRank,
	CASE 
        -- Handle Billions: Remove 'B', convert to number, multiply by 1000
        WHEN MarketCap LIKE '%B' THEN 
            TRY_CAST(REPLACE(MarketCap, 'B', '') AS DECIMAL(18, 2)) * 1000
        
        -- Handle Millions: Remove 'M', convert to number, keep as is
        WHEN MarketCap LIKE '%M' THEN 
            TRY_CAST(REPLACE(MarketCap, 'M', '') AS DECIMAL(18, 2))
        
        -- Handle cases with no suffix (assumes already in millions or raw number)
        ELSE 
            TRY_CAST(MarketCap AS DECIMAL(18, 2))
    END AS MarketCapInMillion,
	a.CreateDate
from StockDB.BrokerData.BrokerDayReport as a
inner join StockDB.Transform.PriceHistory24Month as b
on a.ASXCode + '.AX' = b.ASXCode
and a.ObservationDate = b.ObservationDate
left join LookupRef.BrokerName as c
on a.BrokerName = c.APIBrokerName
where b.Volume > 0