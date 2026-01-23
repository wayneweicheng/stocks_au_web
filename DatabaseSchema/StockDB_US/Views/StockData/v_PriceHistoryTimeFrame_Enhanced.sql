-- View: [StockData].[v_PriceHistoryTimeFrame_Enhanced]




CREATE VIEW [StockData].[v_PriceHistoryTimeFrame_Enhanced] AS
SELECT 
    ASXCode,
    TimeFrame,
    TimeIntervalStart, -- This is in AEST (Australian Eastern Standard Time, UTC+10)
    -- Convert AEST to US Eastern Time
    TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time' AS TimeIntervalStart_US_EST,
    -- Keep Sydney time (same as source)
    TimeIntervalStart AS TimeIntervalStart_Sydney,
    -- Extract dates for easier filtering
    CAST(TimeIntervalStart AS DATE) AS TradingDate_Sydney,
    CAST(TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time' AS DATE) AS TradingDate_US_EST,
    -- Extract hours for analysis
    DATEPART(HOUR, TimeIntervalStart) AS Hour_Sydney,
    DATEPART(HOUR, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') AS Hour_US_EST,
    -- Market session based on US Eastern time (after conversion)
    CASE 
        WHEN DATEPART(HOUR, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') BETWEEN 4 AND 8 THEN 'Pre-Market'
        WHEN DATEPART(HOUR, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') = 9 
             AND DATEPART(MINUTE, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') >= 30 THEN 'Regular Hours'
        WHEN DATEPART(HOUR, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') BETWEEN 10 AND 15 THEN 'Regular Hours'  
        WHEN DATEPART(HOUR, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') = 16 
             AND DATEPART(MINUTE, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') = 0 THEN 'Regular Hours'
        WHEN DATEPART(HOUR, TimeIntervalStart AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time') BETWEEN 16 AND 19 THEN 'After Hours'
        ELSE 'Overnight'
    END AS MarketSession,
    [Open],
    [High],
    [Low],
    [Close],
    Volume,
    FirstSale,
    LastSale,
    SaleValue,
    NumOfSale,
    AverageValuePerTransaction,
    VWAP,
    ObservationDate
FROM 
    [StockData].[PriceHistoryTimeFrame]  -- Replace with your actual table name
WHERE 1 = 1