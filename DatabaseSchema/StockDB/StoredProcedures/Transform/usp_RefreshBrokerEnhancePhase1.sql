-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase1]

-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase1]


CREATE PROCEDURE Transform.usp_RefreshBrokerEnhancePhase1
    @pAsOfDate                    date            = NULL,
    @pASXCode                     varchar(10)     = NULL,
    @pvchStockCodeList            varchar(max)    = NULL,
    @pRefreshMode                 varchar(20)     = 'FULL',
    @pRecomputeTailTradingDays    int             = 60,
    @pLookbackTradingDays         int             = 504,
    @pSingleBuyRatio1D            decimal(18,8)   = 0.02000000,
    @pSingleSellRatio1D           decimal(18,8)   = 0.02000000,
    @pMinAbsoluteEventValue       decimal(20,4)   = 100000.0000,
    @pAccumBuyRatio5D             decimal(18,8)   = 0.03000000,
    @pAccumBuyRatio7D             decimal(18,8)   = 0.03500000,
    @pAccumBuyRatio10D            decimal(18,8)   = 0.04000000,
    @pAccumSellRatio5D            decimal(18,8)   = 0.03000000,
    @pAccumSellRatio7D            decimal(18,8)   = 0.03500000,
    @pAccumSellRatio10D           decimal(18,8)   = 0.04000000,
    @pMinPositiveDays5D           int             = 3,
    @pMinPositiveDays7D           int             = 4,
    @pMinPositiveDays10D          int             = 5,
    @pMinNegativeDays5D           int             = 3,
    @pMinNegativeDays7D           int             = 4,
    @pMinNegativeDays10D          int             = 5
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @vAsOfDate date =
        COALESCE(@pAsOfDate, (SELECT MAX(ObservationDate) FROM StockData.PriceHistory));

    DECLARE @vBaseASXCode varchar(10) =
        CASE
            WHEN @pASXCode IS NULL THEN NULL
            ELSE UPPER(LTRIM(RTRIM(REPLACE(@pASXCode, '.AX', ''))))
        END;
    DECLARE @vHasStockCodeFilter bit = 0;

    DECLARE @vScoreVersion varchar(40) = 'broker_enhance_phase1_v2';
    DECLARE @vRefreshMode varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@pRefreshMode, 'FULL'))));
    DECLARE @vRecomputeTailTradingDays int = CASE WHEN ISNULL(@pRecomputeTailTradingDays, 0) > 0 THEN @pRecomputeTailTradingDays ELSE 60 END;
    DECLARE @vPrevSnapshot date = NULL;
    DECLARE @vPersistStartDate date = NULL;
    DECLARE @vPriceWindowStartDate date = NULL;
    DECLARE @vBrokerMinDate date = NULL;
    DECLARE @vBrokerMaxDate date = NULL;

    IF @vRefreshMode NOT IN ('FULL', 'INCREMENTAL')
        SET @vRefreshMode = 'FULL';

    DROP TABLE IF EXISTS #StockCodeFilter;

    CREATE TABLE #StockCodeFilter
    (
        ASXCode varchar(10) NOT NULL PRIMARY KEY
    );

    IF @vBaseASXCode IS NOT NULL
    BEGIN
        INSERT INTO #StockCodeFilter (ASXCode)
        VALUES (@vBaseASXCode);
    END;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@pvchStockCodeList, ''))), '') IS NOT NULL
    BEGIN
        INSERT INTO #StockCodeFilter (ASXCode)
        SELECT DISTINCT UPPER(LTRIM(RTRIM(REPLACE(value, '.AX', '')))) AS ASXCode
        FROM STRING_SPLIT(@pvchStockCodeList, ',')
        WHERE NULLIF(LTRIM(RTRIM(REPLACE(value, '.AX', ''))), '') IS NOT NULL
          AND NOT EXISTS
          (
              SELECT 1
              FROM #StockCodeFilter f
              WHERE f.ASXCode = UPPER(LTRIM(RTRIM(REPLACE(value, '.AX', ''))))
          );
    END;

    IF EXISTS (SELECT 1 FROM #StockCodeFilter)
        SET @vHasStockCodeFilter = 1;

    IF @vRefreshMode = 'INCREMENTAL'
    BEGIN
        SELECT
            @vPrevSnapshot = MAX(s.SnapshotDate)
        FROM Transform.StockDayBrokerSetup s
        WHERE s.SnapshotDate < @vAsOfDate
          AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = s.ASXCode));

        IF @vPrevSnapshot IS NULL
            SET @vRefreshMode = 'FULL';
    END;

    DROP TABLE IF EXISTS #PriceBase;
    DROP TABLE IF EXISTS #BrokerBase;
    DROP TABLE IF EXISTS #BrokerRoll;
    DROP TABLE IF EXISTS #BrokerStreak;
    DROP TABLE IF EXISTS #InventoryBase;
    DROP TABLE IF EXISTS #DailyFinal;
    DROP TABLE IF EXISTS #EventBase;
    DROP TABLE IF EXISTS #HistSummary;
    DROP TABLE IF EXISTS #HistAgg;
    DROP TABLE IF EXISTS #Stock5D;
    DROP TABLE IF EXISTS #StockSetup;
    DROP TABLE IF EXISTS #PriceCanonical;
    DROP TABLE IF EXISTS #ActiveBrokerCode;
    DROP TABLE IF EXISTS #TempPriceHistory;
    DROP TABLE IF EXISTS #TempBrokerDayReport;

    CREATE TABLE #ActiveBrokerCode
    (
        ASXCode varchar(10) NOT NULL
    );

    IF @vHasStockCodeFilter = 1
    BEGIN
        INSERT INTO #ActiveBrokerCode (ASXCode)
        SELECT f.ASXCode
        FROM #StockCodeFilter f;
    END
    ELSE
    BEGIN
        INSERT INTO #ActiveBrokerCode (ASXCode)
        SELECT DISTINCT
            UPPER(
                LTRIM(
                    RTRIM(
                        CASE
                            WHEN RIGHT(bt.ASXCode, 3) = '.AX' THEN LEFT(bt.ASXCode, LEN(bt.ASXCode) - 3)
                            ELSE bt.ASXCode
                        END
                    )
                )
            ) AS ASXCode
        FROM StockData.BrokerTradeTransaction bt
        WHERE bt.ASXCode IS NOT NULL;
    END;

    CREATE UNIQUE CLUSTERED INDEX IX_ActiveBrokerCode_ASXCode
        ON #ActiveBrokerCode (ASXCode);

    IF @vHasStockCodeFilter = 1
    BEGIN
        ;WITH PriceDates AS
        (
            SELECT
                d.ObservationDate,
                ROW_NUMBER() OVER (ORDER BY d.ObservationDate DESC) AS RnDesc
            FROM
            (
                SELECT DISTINCT p.ObservationDate
                FROM StockData.PriceHistory p
                INNER JOIN #StockCodeFilter f
                    ON p.ASXCode = f.ASXCode
                    OR p.ASXCode = f.ASXCode + '.AX'
                WHERE p.ObservationDate <= @vAsOfDate
            ) d
        )
        SELECT
            @vPriceWindowStartDate = MIN(ObservationDate)
        FROM PriceDates
        WHERE RnDesc <= (@pLookbackTradingDays + 60);
    END
    ELSE
    BEGIN
        ;WITH PriceDates AS
        (
            SELECT
                d.ObservationDate,
                ROW_NUMBER() OVER (ORDER BY d.ObservationDate DESC) AS RnDesc
            FROM
            (
                SELECT DISTINCT p.ObservationDate
                FROM StockData.PriceHistory p
                CROSS APPLY
                (
                    VALUES
                    (
                        CASE
                            WHEN RIGHT(p.ASXCode, 3) = '.AX' THEN LEFT(p.ASXCode, LEN(p.ASXCode) - 3)
                            ELSE p.ASXCode
                        END
                    )
                ) n(BaseASXCode)
                INNER JOIN #ActiveBrokerCode ab
                    ON ab.ASXCode = n.BaseASXCode
                WHERE p.ObservationDate <= @vAsOfDate
            ) d
        )
        SELECT
            @vPriceWindowStartDate = MIN(ObservationDate)
        FROM PriceDates
        WHERE RnDesc <= (@pLookbackTradingDays + 60);
    END;

    IF @vPriceWindowStartDate IS NULL
        SET @vPriceWindowStartDate = @vAsOfDate;

    CREATE TABLE #TempPriceHistory
    (
        ASXCode varchar(10) NOT NULL,
        BaseASXCode varchar(10) NOT NULL,
        ObservationDate date NOT NULL,
        [Open] decimal(20,4) NOT NULL,
        [High] decimal(20,4) NOT NULL,
        [Low] decimal(20,4) NOT NULL,
        [Close] decimal(20,4) NOT NULL,
        Volume bigint NOT NULL,
        [Value] decimal(20,4) NULL
    );

    IF @vHasStockCodeFilter = 1
    BEGIN
        INSERT INTO #TempPriceHistory
        (
            ASXCode, BaseASXCode, ObservationDate, [Open], [High], [Low], [Close], Volume, [Value]
        )
        SELECT
            p.ASXCode,
            f.ASXCode AS BaseASXCode,
            p.ObservationDate,
            p.[Open],
            p.[High],
            p.[Low],
            p.[Close],
            p.Volume,
            p.[Value]
        FROM StockData.PriceHistory p
        INNER JOIN #StockCodeFilter f
            ON p.ASXCode = f.ASXCode
            OR p.ASXCode = f.ASXCode + '.AX'
        WHERE p.ObservationDate >= @vPriceWindowStartDate
          AND p.ObservationDate <= @vAsOfDate;
    END
    ELSE
    BEGIN
        INSERT INTO #TempPriceHistory
        (
            ASXCode, BaseASXCode, ObservationDate, [Open], [High], [Low], [Close], Volume, [Value]
        )
        SELECT
            p.ASXCode,
            n.BaseASXCode,
            p.ObservationDate,
            p.[Open],
            p.[High],
            p.[Low],
            p.[Close],
            p.Volume,
            p.[Value]
        FROM StockData.PriceHistory p
        CROSS APPLY
        (
            VALUES
            (
                CASE
                    WHEN RIGHT(p.ASXCode, 3) = '.AX' THEN LEFT(p.ASXCode, LEN(p.ASXCode) - 3)
                    ELSE p.ASXCode
                END
            )
        ) n(BaseASXCode)
        INNER JOIN #ActiveBrokerCode ab
            ON ab.ASXCode = n.BaseASXCode
        WHERE p.ObservationDate >= @vPriceWindowStartDate
          AND p.ObservationDate <= @vAsOfDate;
    END;

    CREATE CLUSTERED INDEX IX_TempPriceHistory_BaseDateCode
        ON #TempPriceHistory (BaseASXCode, ObservationDate, ASXCode);

    ;WITH PriceRaw AS
    (
        SELECT
            p.ASXCode AS PriceASXCode,
            p.BaseASXCode AS ASXCode,
            p.ObservationDate,
            CAST(p.[Open] AS decimal(20,8)) AS DayOpen,
            CAST(p.[High] AS decimal(20,8)) AS DayHigh,
            CAST(p.[Low] AS decimal(20,8)) AS DayLow,
            CAST(p.[Close] AS decimal(20,8)) AS DayClose,
            p.Volume AS DayVolume,
            CAST(ISNULL(p.[Value], 0) AS decimal(20,4)) AS DayTurnover,
            CAST(CASE WHEN p.Volume > 0 THEN ISNULL(p.[Value], 0) / CAST(p.Volume AS decimal(20,8)) END AS decimal(20,8)) AS DayVWAP,
            ROW_NUMBER() OVER
            (
                PARTITION BY p.BaseASXCode, p.ObservationDate
                ORDER BY
                    CASE
                        WHEN p.ASXCode = p.BaseASXCode THEN 0
                        WHEN p.ASXCode = p.BaseASXCode + '.AX' THEN 1
                        ELSE 2
                    END,
                    p.ASXCode
            ) AS CanonicalRank
        FROM #TempPriceHistory p
        WHERE p.ObservationDate <= @vAsOfDate
    )
    SELECT
        p.PriceASXCode,
        p.ASXCode,
        p.ObservationDate,
        p.DayOpen,
        p.DayHigh,
        p.DayLow,
        p.DayClose,
        p.DayVolume,
        p.DayTurnover,
        p.DayVWAP
    INTO #PriceCanonical
    FROM PriceRaw p
    WHERE p.CanonicalRank = 1;

    CREATE CLUSTERED INDEX IX_PriceCanonical_ASXDate
        ON #PriceCanonical (ASXCode, ObservationDate);

    ;WITH PriceWindow AS
    (
        SELECT
            p.PriceASXCode,
            p.ASXCode,
            p.ObservationDate,
            p.DayOpen,
            p.DayHigh,
            p.DayLow,
            p.DayClose,
            p.DayVolume,
            p.DayTurnover,
            p.DayVWAP,
            ROW_NUMBER() OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate DESC) AS RnDesc,

            CAST(SUM(p.DayTurnover) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS RollTurnover5D,
            CAST(SUM(p.DayTurnover) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS RollTurnover7D,
            CAST(SUM(p.DayTurnover) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS RollTurnover10D,
            CAST(SUM(p.DayTurnover) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS RollTurnover20D,

            CAST((LEAD(p.DayClose, 7)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret7D,
            CAST((LEAD(p.DayClose, 10) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret10D,
            CAST((LEAD(p.DayClose, 15) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret15D,
            CAST((LEAD(p.DayClose, 20) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret20D,
            CAST((LEAD(p.DayClose, 30) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret30D,
            CAST((LEAD(p.DayClose, 45) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret45D,
            CAST((LEAD(p.DayClose, 60) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS Ret60D,

            CAST((MAX(p.DayHigh) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 1 FOLLOWING AND 20 FOLLOWING) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS MaxUp20D,
            CAST((MAX(p.DayHigh) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 1 FOLLOWING AND 30 FOLLOWING) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS MaxUp30D,
            CAST((MAX(p.DayHigh) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 1 FOLLOWING AND 60 FOLLOWING) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS MaxUp60D,

            CAST((MIN(p.DayLow) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 1 FOLLOWING AND 20 FOLLOWING) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS MaxDD20D,
            CAST((MIN(p.DayLow) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 1 FOLLOWING AND 30 FOLLOWING) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS MaxDD30D,
            CAST((MIN(p.DayLow) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate ROWS BETWEEN 1 FOLLOWING AND 60 FOLLOWING) / NULLIF(p.DayClose, 0)) - 1.0 AS decimal(18,8)) AS MaxDD60D
        FROM #PriceCanonical p
    )
    SELECT *
    INTO #PriceBase
    FROM PriceWindow
    WHERE RnDesc <= (@pLookbackTradingDays + 60);

    CREATE CLUSTERED INDEX IX_PriceBase_ASXDate
        ON #PriceBase (ASXCode, ObservationDate);

    IF @vRefreshMode = 'INCREMENTAL'
    BEGIN
        ;WITH TailWindow AS
        (
            SELECT
                d.ObservationDate,
                ROW_NUMBER() OVER (ORDER BY d.ObservationDate DESC) AS RnDesc
            FROM
            (
                SELECT DISTINCT p.ObservationDate
                FROM #PriceBase p
                WHERE p.ObservationDate <= @vAsOfDate
            ) d
        )
        SELECT
            @vPersistStartDate = MIN(t.ObservationDate)
        FROM TailWindow t
        WHERE t.RnDesc <= @vRecomputeTailTradingDays;
    END;

    IF @vPersistStartDate IS NULL
        SELECT @vPersistStartDate = MIN(p.ObservationDate) FROM #PriceBase p;

    IF @vPersistStartDate IS NULL
        SET @vPersistStartDate = @vAsOfDate;

    SELECT
        @vBrokerMinDate = MIN(p.ObservationDate),
        @vBrokerMaxDate = MAX(p.ObservationDate)
    FROM #PriceBase p;

    IF @vBrokerMinDate IS NULL SET @vBrokerMinDate = @vAsOfDate;
    IF @vBrokerMaxDate IS NULL SET @vBrokerMaxDate = @vAsOfDate;

    SELECT
        b.*
    INTO #TempBrokerDayReport
    FROM BrokerData.BrokerDayReport b
    INNER JOIN #ActiveBrokerCode ab
        ON ab.ASXCode = b.ASXCode
    WHERE b.ObservationDate >= @vBrokerMinDate
      AND b.ObservationDate <= @vBrokerMaxDate
      AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = b.ASXCode));

    CREATE CLUSTERED INDEX IX_TempBrokerDayReport_CodeDateBroker
        ON #TempBrokerDayReport (ASXCode, ObservationDate, BrokerName);

    ;WITH BrokerDayAgg AS
    (
        SELECT
            b.ASXCode,
            b.ObservationDate,
            b.BrokerName,
            CAST(SUM(ISNULL(b.BuyValue, 0)) AS decimal(20,4)) AS BuyValue,
            CAST(SUM(ISNULL(b.SellValue, 0)) AS decimal(20,4)) AS SellValue,
            CAST(SUM(ISNULL(b.NetValue, 0)) AS decimal(20,4)) AS NetValue,
            CAST(MAX(ISNULL(b.TotalValue, 0)) AS decimal(20,4)) AS TotalValue
        FROM #TempBrokerDayReport b
        GROUP BY
            b.ASXCode,
            b.ObservationDate,
            b.BrokerName
    ),
    BrokerJoin AS
    (
        SELECT
            p.ASXCode,
            p.PriceASXCode,
            p.ObservationDate AS TradeDate,
            b.BrokerName,
            bn.BrokerCode,

            CAST(ISNULL(b.BuyValue, 0) AS decimal(20,4)) AS BuyValue,
            CAST(ISNULL(b.SellValue, 0) AS decimal(20,4)) AS SellValue,
            CAST(ISNULL(b.NetValue, 0) AS decimal(20,4)) AS NetValue,
            CAST(b.TotalValue AS decimal(20,4)) AS TotalValue,

            p.DayOpen,
            p.DayHigh,
            p.DayLow,
            p.DayClose,
            p.DayVolume,
            p.DayTurnover,
            p.DayVWAP,
            p.RollTurnover5D,
            p.RollTurnover7D,
            p.RollTurnover10D,
            p.RollTurnover20D,
            p.Ret7D,
            p.Ret10D,
            p.Ret15D,
            p.Ret20D,
            p.Ret30D,
            p.Ret45D,
            p.Ret60D,
            p.MaxUp20D,
            p.MaxUp30D,
            p.MaxUp60D,
            p.MaxDD20D,
            p.MaxDD30D,
            p.MaxDD60D,

            CAST(CASE WHEN ISNULL(b.NetValue, 0) > 0 THEN ISNULL(b.NetValue, 0) ELSE 0 END AS decimal(20,4)) AS NetBuyValue1D,
            CAST(CASE WHEN ISNULL(b.NetValue, 0) < 0 THEN ABS(ISNULL(b.NetValue, 0)) ELSE 0 END AS decimal(20,4)) AS NetSellValue1D,
            CAST(CASE WHEN p.DayTurnover > 0 AND ISNULL(b.NetValue, 0) > 0 THEN ISNULL(b.NetValue, 0) / p.DayTurnover ELSE 0 END AS decimal(18,8)) AS NetBuyRatio1D,
            CAST(CASE WHEN p.DayTurnover > 0 AND ISNULL(b.NetValue, 0) < 0 THEN ABS(ISNULL(b.NetValue, 0)) / p.DayTurnover ELSE 0 END AS decimal(18,8)) AS NetSellRatio1D,
            CAST(CASE WHEN p.DayTurnover > 0 THEN ISNULL(b.BuyValue, 0) / p.DayTurnover ELSE 0 END AS decimal(18,8)) AS BuyValueRatio1D,
            CAST(CASE WHEN p.DayTurnover > 0 THEN ISNULL(b.SellValue, 0) / p.DayTurnover ELSE 0 END AS decimal(18,8)) AS SellValueRatio1D,

            CAST(CASE WHEN ISNULL(b.BuyValue, 0) + ISNULL(b.SellValue, 0) > 0 THEN ISNULL(b.NetValue, 0) / NULLIF(ISNULL(b.BuyValue, 0) + ISNULL(b.SellValue, 0), 0) END AS decimal(18,8)) AS NetToGrossRatio,
            CAST(CASE WHEN ISNULL(b.BuyValue, 0) + ISNULL(b.SellValue, 0) > 0 THEN ISNULL(b.BuyValue, 0) / NULLIF(ISNULL(b.BuyValue, 0) + ISNULL(b.SellValue, 0), 0) END AS decimal(18,8)) AS BuyDominance,
            CAST(CASE WHEN ISNULL(b.BuyValue, 0) + ISNULL(b.SellValue, 0) > 0 THEN ISNULL(b.SellValue, 0) / NULLIF(ISNULL(b.BuyValue, 0) + ISNULL(b.SellValue, 0), 0) END AS decimal(18,8)) AS SellDominance
        FROM #PriceBase p
        INNER JOIN BrokerDayAgg b
            ON b.ASXCode = p.ASXCode
           AND b.ObservationDate = p.ObservationDate
        OUTER APPLY
        (
            SELECT TOP (1)
                l.BrokerCode
            FROM LookupRef.BrokerName l
            WHERE l.BrokerName = b.BrokerName
               OR l.APIBrokerName = b.BrokerName
            ORDER BY
                CASE WHEN l.BrokerName = b.BrokerName THEN 0 ELSE 1 END,
                l.BrokerCode
        ) bn
    ),
    BrokerRoll AS
    (
        SELECT
            j.*,
            CAST(SUM(CASE WHEN j.NetValue > 0 THEN j.NetValue ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetBuy5D,
            CAST(SUM(CASE WHEN j.NetValue > 0 THEN j.NetValue ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetBuy7D,
            CAST(SUM(CASE WHEN j.NetValue > 0 THEN j.NetValue ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetBuy10D,
            CAST(SUM(CASE WHEN j.NetValue > 0 THEN j.NetValue ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetBuy20D,

            CAST(SUM(CASE WHEN j.NetValue < 0 THEN ABS(j.NetValue) ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetSell5D,
            CAST(SUM(CASE WHEN j.NetValue < 0 THEN ABS(j.NetValue) ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetSell7D,
            CAST(SUM(CASE WHEN j.NetValue < 0 THEN ABS(j.NetValue) ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetSell10D,
            CAST(SUM(CASE WHEN j.NetValue < 0 THEN ABS(j.NetValue) ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS decimal(20,4)) AS SumNetSell20D,

            SUM(CASE WHEN j.NetValue > 0 THEN 1 ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS PositiveDays5D,
            SUM(CASE WHEN j.NetValue > 0 THEN 1 ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS PositiveDays7D,
            SUM(CASE WHEN j.NetValue > 0 THEN 1 ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS PositiveDays10D,

            SUM(CASE WHEN j.NetValue < 0 THEN 1 ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS NegativeDays5D,
            SUM(CASE WHEN j.NetValue < 0 THEN 1 ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS NegativeDays7D,
            SUM(CASE WHEN j.NetValue < 0 THEN 1 ELSE 0 END) OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS NegativeDays10D,

            ROW_NUMBER() OVER (PARTITION BY j.ASXCode, j.BrokerName ORDER BY j.TradeDate) AS BrokerSeq
        FROM BrokerJoin j
    ),
    BrokerRatio AS
    (
        SELECT
            r.*,
            CAST(CASE WHEN r.RollTurnover5D > 0 THEN r.SumNetBuy5D / r.RollTurnover5D ELSE 0 END AS decimal(18,8)) AS NetBuyRatio5D,
            CAST(CASE WHEN r.RollTurnover7D > 0 THEN r.SumNetBuy7D / r.RollTurnover7D ELSE 0 END AS decimal(18,8)) AS NetBuyRatio7D,
            CAST(CASE WHEN r.RollTurnover10D > 0 THEN r.SumNetBuy10D / r.RollTurnover10D ELSE 0 END AS decimal(18,8)) AS NetBuyRatio10D,
            CAST(CASE WHEN r.RollTurnover20D > 0 THEN r.SumNetBuy20D / r.RollTurnover20D ELSE 0 END AS decimal(18,8)) AS NetBuyRatio20D,

            CAST(CASE WHEN r.RollTurnover5D > 0 THEN r.SumNetSell5D / r.RollTurnover5D ELSE 0 END AS decimal(18,8)) AS NetSellRatio5D,
            CAST(CASE WHEN r.RollTurnover7D > 0 THEN r.SumNetSell7D / r.RollTurnover7D ELSE 0 END AS decimal(18,8)) AS NetSellRatio7D,
            CAST(CASE WHEN r.RollTurnover10D > 0 THEN r.SumNetSell10D / r.RollTurnover10D ELSE 0 END AS decimal(18,8)) AS NetSellRatio10D,
            CAST(CASE WHEN r.RollTurnover20D > 0 THEN r.SumNetSell20D / r.RollTurnover20D ELSE 0 END AS decimal(18,8)) AS NetSellRatio20D,
            CAST(CASE WHEN r.DayVWAP > 0 THEN r.NetValue / r.DayVWAP ELSE 0 END AS decimal(28,8)) AS EstimatedNetShares1D
        FROM BrokerRoll r
    ),
    BuyGroup AS
    (
        SELECT
            r.*,
            SUM(CASE WHEN r.NetValue > 0 THEN 0 ELSE 1 END) OVER (PARTITION BY r.ASXCode, r.BrokerName ORDER BY r.TradeDate ROWS UNBOUNDED PRECEDING) AS BuyGrp,
            SUM(CASE WHEN r.NetValue < 0 THEN 0 ELSE 1 END) OVER (PARTITION BY r.ASXCode, r.BrokerName ORDER BY r.TradeDate ROWS UNBOUNDED PRECEDING) AS SellGrp
        FROM BrokerRatio r
    )
    SELECT
        g.*,
        CASE
            WHEN g.NetValue > 0 THEN COUNT(*) OVER (PARTITION BY g.ASXCode, g.BrokerName, g.BuyGrp ORDER BY g.TradeDate ROWS UNBOUNDED PRECEDING)
            ELSE 0
        END AS BuyStreakLength,
        CASE
            WHEN g.NetValue < 0 THEN COUNT(*) OVER (PARTITION BY g.ASXCode, g.BrokerName, g.SellGrp ORDER BY g.TradeDate ROWS UNBOUNDED PRECEDING)
            ELSE 0
        END AS SellStreakLength
    INTO #BrokerStreak
    FROM BuyGroup g;

    SELECT *
    INTO #InventoryBase
    FROM #BrokerStreak;

    ;WITH Inv AS
    (
        SELECT
            i.ASXCode,
            i.PriceASXCode,
            i.TradeDate,
            i.BrokerName,
            i.BrokerCode,
            i.BrokerSeq,
            i.EstimatedNetShares1D,
            i.BuyValue,
            CAST(CASE WHEN i.EstimatedNetShares1D > 0 THEN i.EstimatedNetShares1D ELSE 0 END AS decimal(28,8)) AS PositionSharesEst,
            -- Use net traded value to align cost accumulation with net-share accumulation.
            CAST(CASE WHEN i.EstimatedNetShares1D > 0 THEN i.NetValue ELSE 0 END AS decimal(28,8)) AS CostValueEst
        FROM #InventoryBase i
        WHERE i.BrokerSeq = 1

        UNION ALL

        SELECT
            i.ASXCode,
            i.PriceASXCode,
            i.TradeDate,
            i.BrokerName,
            i.BrokerCode,
            i.BrokerSeq,
            i.EstimatedNetShares1D,
            i.BuyValue,
            CAST(
                CASE
                    WHEN prev.PositionSharesEst + i.EstimatedNetShares1D < 0 THEN 0
                    ELSE prev.PositionSharesEst + i.EstimatedNetShares1D
                END AS decimal(28,8)
            ) AS PositionSharesEst,
            CAST(
                CASE
                    WHEN i.EstimatedNetShares1D >= 0 THEN prev.CostValueEst + i.NetValue
                    WHEN prev.PositionSharesEst <= 0 THEN 0
                    WHEN prev.PositionSharesEst + i.EstimatedNetShares1D <= 0 THEN 0
                    ELSE prev.CostValueEst
                         * (
                               (prev.PositionSharesEst + i.EstimatedNetShares1D)
                               / NULLIF(prev.PositionSharesEst, 0)
                           )
                END AS decimal(28,8)
            ) AS CostValueEst
        FROM #InventoryBase i
        INNER JOIN Inv prev
            ON prev.ASXCode = i.ASXCode
           AND prev.BrokerName = i.BrokerName
           AND prev.BrokerSeq + 1 = i.BrokerSeq
    )
    SELECT
        s.ASXCode,
        s.PriceASXCode,
        s.TradeDate,
        s.BrokerName,
        s.BrokerCode,
        s.BuyValue,
        s.SellValue,
        s.NetValue,
        s.TotalValue,
        s.DayOpen,
        s.DayHigh,
        s.DayLow,
        s.DayClose,
        s.DayVolume,
        s.DayTurnover,
        s.DayVWAP,
        s.NetBuyValue1D,
        s.NetSellValue1D,
        s.NetBuyRatio1D,
        s.NetSellRatio1D,
        s.BuyValueRatio1D,
        s.SellValueRatio1D,
        s.RollTurnover5D,
        s.RollTurnover7D,
        s.RollTurnover10D,
        s.RollTurnover20D,
        s.SumNetBuy5D,
        s.SumNetBuy7D,
        s.SumNetBuy10D,
        s.SumNetBuy20D,
        s.SumNetSell5D,
        s.SumNetSell7D,
        s.SumNetSell10D,
        s.SumNetSell20D,
        s.NetBuyRatio5D,
        s.NetBuyRatio7D,
        s.NetBuyRatio10D,
        s.NetBuyRatio20D,
        s.NetSellRatio5D,
        s.NetSellRatio7D,
        s.NetSellRatio10D,
        s.NetSellRatio20D,
        s.PositiveDays5D,
        s.PositiveDays7D,
        s.PositiveDays10D,
        s.NegativeDays5D,
        s.NegativeDays7D,
        s.NegativeDays10D,
        s.BuyStreakLength,
        s.SellStreakLength,
        s.NetToGrossRatio,
        s.BuyDominance,
        s.SellDominance,
        s.EstimatedNetShares1D,
        inv.PositionSharesEst,
        inv.CostValueEst,
        CAST(CASE WHEN inv.PositionSharesEst > 0 THEN inv.CostValueEst / inv.PositionSharesEst END AS decimal(20,8)) AS AvgCostEst,
        CAST(CASE WHEN inv.PositionSharesEst > 0 THEN (s.DayClose / NULLIF(inv.CostValueEst / inv.PositionSharesEst, 0)) - 1.0 END AS decimal(18,8)) AS CloseVsAvgCost,
        CAST(CASE WHEN inv.PositionSharesEst > 0 AND s.DayVWAP > 0 THEN (s.DayVWAP / NULLIF(inv.CostValueEst / inv.PositionSharesEst, 0)) - 1.0 END AS decimal(18,8)) AS VWAPVsAvgCost
    INTO #DailyFinal
    FROM #BrokerStreak s
    INNER JOIN Inv inv
        ON inv.ASXCode = s.ASXCode
       AND inv.BrokerName = s.BrokerName
       AND inv.TradeDate = s.TradeDate
    OPTION (MAXRECURSION 0);

    DELETE d
    FROM Transform.BrokerDailyFeature d
    WHERE d.TradeDate >= @vPersistStartDate
      AND d.TradeDate <= @vAsOfDate
      AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode));

    INSERT INTO Transform.BrokerDailyFeature
    (
        ASXCode, PriceASXCode, TradeDate, BrokerName, BrokerCode,
        BuyValue, SellValue, NetValue, TotalValue,
        DayOpen, DayHigh, DayLow, DayClose, DayVolume, DayTurnover, DayVWAP,
        NetBuyValue1D, NetSellValue1D, NetBuyRatio1D, NetSellRatio1D, BuyValueRatio1D, SellValueRatio1D,
        RollTurnover5D, RollTurnover7D, RollTurnover10D, RollTurnover20D,
        SumNetBuy5D, SumNetBuy7D, SumNetBuy10D, SumNetBuy20D,
        SumNetSell5D, SumNetSell7D, SumNetSell10D, SumNetSell20D,
        NetBuyRatio5D, NetBuyRatio7D, NetBuyRatio10D, NetBuyRatio20D,
        NetSellRatio5D, NetSellRatio7D, NetSellRatio10D, NetSellRatio20D,
        PositiveDays5D, PositiveDays7D, PositiveDays10D,
        NegativeDays5D, NegativeDays7D, NegativeDays10D,
        BuyStreakLength, SellStreakLength,
        NetToGrossRatio, BuyDominance, SellDominance,
        EstimatedNetShares1D, PositionSharesEst, CostValueEst, AvgCostEst, CloseVsAvgCost, VWAPVsAvgCost,
        ScoreVersion, CreatedDate, ModifiedDate
    )
    SELECT
        ASXCode, PriceASXCode, TradeDate, BrokerName, BrokerCode,
        BuyValue, SellValue, NetValue, TotalValue,
        DayOpen, DayHigh, DayLow, DayClose, DayVolume, DayTurnover, DayVWAP,
        NetBuyValue1D, NetSellValue1D, NetBuyRatio1D, NetSellRatio1D, BuyValueRatio1D, SellValueRatio1D,
        RollTurnover5D, RollTurnover7D, RollTurnover10D, RollTurnover20D,
        SumNetBuy5D, SumNetBuy7D, SumNetBuy10D, SumNetBuy20D,
        SumNetSell5D, SumNetSell7D, SumNetSell10D, SumNetSell20D,
        NetBuyRatio5D, NetBuyRatio7D, NetBuyRatio10D, NetBuyRatio20D,
        NetSellRatio5D, NetSellRatio7D, NetSellRatio10D, NetSellRatio20D,
        PositiveDays5D, PositiveDays7D, PositiveDays10D,
        NegativeDays5D, NegativeDays7D, NegativeDays10D,
        BuyStreakLength, SellStreakLength,
        NetToGrossRatio, BuyDominance, SellDominance,
        EstimatedNetShares1D, PositionSharesEst, CostValueEst, AvgCostEst, CloseVsAvgCost, VWAPVsAvgCost,
        @vScoreVersion, SYSUTCDATETIME(), SYSUTCDATETIME()
    FROM #DailyFinal
    WHERE TradeDate >= @vPersistStartDate
      AND TradeDate <= @vAsOfDate;

    ;WITH EventUnion AS
    (
        SELECT
            d.ASXCode,
            d.PriceASXCode,
            d.TradeDate,
            d.BrokerName,
            d.BrokerCode,
            'BUY_STRONG_1D' AS EventType,
            'BULL' AS EventDirection,
            'NetBuyRatio1D' AS TriggerMetric,
            d.NetBuyRatio1D AS TriggerValue
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetBuyRatio1D >= @pSingleBuyRatio1D
          AND d.NetBuyValue1D >= @pMinAbsoluteEventValue

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'ACCUM_5D', 'BULL', 'NetBuyRatio5D', d.NetBuyRatio5D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetBuyRatio5D >= @pAccumBuyRatio5D
          AND d.PositiveDays5D >= @pMinPositiveDays5D

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'ACCUM_7D', 'BULL', 'NetBuyRatio7D', d.NetBuyRatio7D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetBuyRatio7D >= @pAccumBuyRatio7D
          AND d.PositiveDays7D >= @pMinPositiveDays7D

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'ACCUM_10D', 'BULL', 'NetBuyRatio10D', d.NetBuyRatio10D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetBuyRatio10D >= @pAccumBuyRatio10D
          AND d.PositiveDays10D >= @pMinPositiveDays10D

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'SELL_STRONG_1D', 'BEAR', 'NetSellRatio1D', d.NetSellRatio1D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetSellRatio1D >= @pSingleSellRatio1D
          AND d.NetSellValue1D >= @pMinAbsoluteEventValue

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'DIST_5D', 'BEAR', 'NetSellRatio5D', d.NetSellRatio5D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetSellRatio5D >= @pAccumSellRatio5D
          AND d.NegativeDays5D >= @pMinNegativeDays5D

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'DIST_7D', 'BEAR', 'NetSellRatio7D', d.NetSellRatio7D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetSellRatio7D >= @pAccumSellRatio7D
          AND d.NegativeDays7D >= @pMinNegativeDays7D

        UNION ALL

        SELECT d.ASXCode, d.PriceASXCode, d.TradeDate, d.BrokerName, d.BrokerCode, 'DIST_10D', 'BEAR', 'NetSellRatio10D', d.NetSellRatio10D
        FROM Transform.BrokerDailyFeature d
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
          AND d.NetSellRatio10D >= @pAccumSellRatio10D
          AND d.NegativeDays10D >= @pMinNegativeDays10D
    )
    SELECT
        e.ASXCode,
        e.PriceASXCode,
        e.TradeDate,
        e.BrokerName,
        e.BrokerCode,
        e.EventType,
        e.EventDirection,
        e.TriggerMetric,
        e.TriggerValue,
        d.BuyValue,
        d.SellValue,
        d.NetValue,
        d.DayTurnover,
        d.DayClose,
        d.DayVWAP,
        d.NetToGrossRatio,
        d.BuyDominance,
        d.SellDominance,
        p.Ret7D,
        p.Ret10D,
        p.Ret15D,
        p.Ret20D,
        p.Ret30D,
        p.Ret45D,
        p.Ret60D,
        p.MaxUp20D,
        p.MaxUp30D,
        p.MaxUp60D,
        p.MaxDD20D,
        p.MaxDD30D,
        p.MaxDD60D
    INTO #EventBase
    FROM EventUnion e
    INNER JOIN Transform.BrokerDailyFeature d
        ON d.ASXCode = e.ASXCode
       AND d.TradeDate = e.TradeDate
       AND d.BrokerName = e.BrokerName
    INNER JOIN #PriceBase p
        ON p.ASXCode = e.ASXCode
       AND p.ObservationDate = e.TradeDate;

    DELETE e
    FROM Transform.BrokerEvent e
    WHERE e.TradeDate >= @vPersistStartDate
      AND e.TradeDate <= @vAsOfDate
      AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = e.ASXCode));

    INSERT INTO Transform.BrokerEvent
    (
        ASXCode, PriceASXCode, TradeDate, BrokerName, BrokerCode,
        EventType, EventDirection, TriggerMetric, TriggerValue,
        BuyValue, SellValue, NetValue, DayTurnover, DayClose, DayVWAP,
        NetToGrossRatio, BuyDominance, SellDominance,
        Ret7D, Ret10D, Ret15D, Ret20D, Ret30D, Ret45D, Ret60D,
        MaxUp20D, MaxUp30D, MaxUp60D, MaxDD20D, MaxDD30D, MaxDD60D,
        ScoreVersion, CreatedDate
    )
    SELECT
        ASXCode, PriceASXCode, TradeDate, BrokerName, BrokerCode,
        EventType, EventDirection, TriggerMetric, TriggerValue,
        BuyValue, SellValue, NetValue, DayTurnover, DayClose, DayVWAP,
        NetToGrossRatio, BuyDominance, SellDominance,
        Ret7D, Ret10D, Ret15D, Ret20D, Ret30D, Ret45D, Ret60D,
        MaxUp20D, MaxUp30D, MaxUp60D, MaxDD20D, MaxDD30D, MaxDD60D,
        @vScoreVersion, SYSUTCDATETIME()
    FROM #EventBase;

    ;WITH StockCounts AS
    (
        SELECT
            e.BrokerName,
            e.EventType,
            e.EventDirection,
            COUNT(DISTINCT e.ASXCode) AS StockCount
        FROM Transform.BrokerEvent e
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = e.ASXCode))
          AND e.TradeDate <= @vAsOfDate
        GROUP BY
            e.BrokerName,
            e.EventType,
            e.EventDirection
    ),
    Stats AS
    (
        SELECT
            @vAsOfDate AS SnapshotDate,
            e.BrokerName,
            MAX(e.BrokerCode) OVER (PARTITION BY e.BrokerName, e.EventType) AS BrokerCode,
            e.EventType,
            e.EventDirection,
            COUNT(*) OVER (PARTITION BY e.BrokerName, e.EventType) AS EventCount,
            sc.StockCount,

            CAST(AVG(CAST(e.Ret7D AS float))  OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet7D,
            CAST(AVG(CAST(e.Ret10D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet10D,
            CAST(AVG(CAST(e.Ret15D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet15D,
            CAST(AVG(CAST(e.Ret20D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet20D,
            CAST(AVG(CAST(e.Ret30D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet30D,
            CAST(AVG(CAST(e.Ret45D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet45D,
            CAST(AVG(CAST(e.Ret60D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgRet60D,

            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret7D)  OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet7D,
            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret10D) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet10D,
            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret15D) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet15D,
            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret20D) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet20D,
            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret30D) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet30D,
            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret45D) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet45D,
            CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.Ret60D) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS MedianRet60D,

            CAST(STDEV(CAST(e.Ret7D AS float))  OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet7D,
            CAST(STDEV(CAST(e.Ret10D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet10D,
            CAST(STDEV(CAST(e.Ret15D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet15D,
            CAST(STDEV(CAST(e.Ret20D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet20D,
            CAST(STDEV(CAST(e.Ret30D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet30D,
            CAST(STDEV(CAST(e.Ret45D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet45D,
            CAST(STDEV(CAST(e.Ret60D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS StdRet60D,

            CAST(AVG(CASE WHEN e.Ret7D  > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate7D,
            CAST(AVG(CASE WHEN e.Ret10D > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate10D,
            CAST(AVG(CASE WHEN e.Ret15D > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate15D,
            CAST(AVG(CASE WHEN e.Ret20D > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate20D,
            CAST(AVG(CASE WHEN e.Ret30D > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate30D,
            CAST(AVG(CASE WHEN e.Ret45D > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate45D,
            CAST(AVG(CASE WHEN e.Ret60D > 0 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS WinRate60D,

            CAST(AVG(CASE WHEN e.Ret20D > 0.10 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS LargeWinnerRate20D,
            CAST(AVG(CASE WHEN e.Ret30D > 0.20 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS LargeWinnerRate30D,
            CAST(AVG(CASE WHEN e.Ret60D > 0.30 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS LargeWinnerRate60D,
            CAST(AVG(CASE WHEN e.Ret20D < -0.10 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS LargeLoserRate20D,
            CAST(AVG(CASE WHEN e.Ret30D < -0.15 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS LargeLoserRate30D,
            CAST(AVG(CASE WHEN e.Ret60D < -0.20 THEN 1.0 ELSE 0.0 END) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS LargeLoserRate60D,

            CAST(AVG(CAST(e.MaxUp30D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgMaxUp30D,
            CAST(AVG(CAST(e.MaxDD30D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgMaxDD30D,
            CAST(AVG(CAST(e.MaxUp60D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgMaxUp60D,
            CAST(AVG(CAST(e.MaxDD60D AS float)) OVER (PARTITION BY e.BrokerName, e.EventType) AS decimal(18,8)) AS AvgMaxDD60D
        FROM Transform.BrokerEvent e
        INNER JOIN StockCounts sc
            ON sc.BrokerName = e.BrokerName
           AND sc.EventType = e.EventType
           AND sc.EventDirection = e.EventDirection
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = e.ASXCode))
          AND e.TradeDate <= @vAsOfDate
    )
    SELECT DISTINCT
        SnapshotDate,
        BrokerName,
        BrokerCode,
        EventType,
        EventDirection,
        EventCount,
        StockCount,
        AvgRet7D,
        AvgRet10D,
        AvgRet15D,
        AvgRet20D,
        AvgRet30D,
        AvgRet45D,
        AvgRet60D,
        MedianRet7D,
        MedianRet10D,
        MedianRet15D,
        MedianRet20D,
        MedianRet30D,
        MedianRet45D,
        MedianRet60D,
        StdRet7D,
        StdRet10D,
        StdRet15D,
        StdRet20D,
        StdRet30D,
        StdRet45D,
        StdRet60D,
        WinRate7D,
        WinRate10D,
        WinRate15D,
        WinRate20D,
        WinRate30D,
        WinRate45D,
        WinRate60D,
        LargeWinnerRate20D,
        LargeWinnerRate30D,
        LargeWinnerRate60D,
        LargeLoserRate20D,
        LargeLoserRate30D,
        LargeLoserRate60D,
        AvgMaxUp30D,
        AvgMaxDD30D,
        AvgMaxUp60D,
        AvgMaxDD60D,
        CAST(CASE WHEN EventCount >= 100 THEN 1.0 ELSE LOG(1.0 + EventCount) / LOG(101.0) END AS decimal(18,8)) AS ReliabilityScore,
        CAST(
            CASE
                WHEN EventDirection = 'BULL' THEN
                    (CASE WHEN EventCount >= 100 THEN 1.0 ELSE LOG(1.0 + EventCount) / LOG(101.0) END)
                    * (0.15 * WinRate15D + 0.25 * WinRate20D + 0.25 * WinRate30D + 0.15 * WinRate45D + 0.20 * LargeWinnerRate30D)
                ELSE
                    (CASE WHEN EventCount >= 100 THEN 1.0 ELSE LOG(1.0 + EventCount) / LOG(101.0) END)
                    * (
                        0.20 * (1.0 - WinRate15D)
                      + 0.25 * (1.0 - WinRate20D)
                      + 0.25 * (1.0 - WinRate30D)
                      + 0.10 * LargeLoserRate20D
                      + 0.20 * LargeLoserRate30D
                    )
            END
            AS decimal(18,8)
        ) AS HistoricalEdgeScore,
        CASE
            WHEN EventDirection = 'BULL' AND MedianRet20D > 0 AND MedianRet30D > MedianRet10D AND LargeWinnerRate30D >= 0.20 THEN 'Early Accumulator'
            WHEN EventDirection = 'BULL' AND MedianRet7D > 0 AND MedianRet10D > 0 AND MedianRet30D <= MedianRet10D THEN 'Breakout Confirmer'
            WHEN EventDirection = 'BULL' AND MedianRet7D > 0 AND MedianRet20D <= 0 THEN 'Momentum Chaser'
            WHEN EventDirection = 'BEAR' AND MedianRet20D < 0 AND LargeLoserRate20D >= 0.20 THEN 'Distribution Broker'
            WHEN ABS(COALESCE(AvgRet20D, 0)) < 0.01 AND ABS(COALESCE(AvgRet30D, 0)) < 0.01 THEN 'Churn / Flow Broker'
            ELSE 'Unclassified'
        END AS BrokerArchetype,
        @vScoreVersion AS ScoreVersion
    INTO #HistSummary
    FROM Stats;

    IF @vHasStockCodeFilter = 0
    BEGIN
        DELETE h
        FROM Transform.BrokerHistoricalPerformance h
        WHERE h.SnapshotDate = @vAsOfDate;
    END;

    IF @vHasStockCodeFilter = 0
    BEGIN
        INSERT INTO Transform.BrokerHistoricalPerformance
        (
            SnapshotDate, BrokerName, BrokerCode, EventType, EventDirection,
            EventCount, StockCount,
            AvgRet7D, AvgRet10D, AvgRet15D, AvgRet20D, AvgRet30D, AvgRet45D, AvgRet60D,
            MedianRet7D, MedianRet10D, MedianRet15D, MedianRet20D, MedianRet30D, MedianRet45D, MedianRet60D,
            StdRet7D, StdRet10D, StdRet15D, StdRet20D, StdRet30D, StdRet45D, StdRet60D,
            WinRate7D, WinRate10D, WinRate15D, WinRate20D, WinRate30D, WinRate45D, WinRate60D,
            LargeWinnerRate20D, LargeWinnerRate30D, LargeWinnerRate60D,
            LargeLoserRate20D, LargeLoserRate30D, LargeLoserRate60D,
            AvgMaxUp30D, AvgMaxDD30D, AvgMaxUp60D, AvgMaxDD60D,
            ReliabilityScore, HistoricalEdgeScore, BrokerArchetype, ScoreVersion, CreatedDate
        )
        SELECT
            SnapshotDate, BrokerName, BrokerCode, EventType, EventDirection,
            EventCount, StockCount,
            AvgRet7D, AvgRet10D, AvgRet15D, AvgRet20D, AvgRet30D, AvgRet45D, AvgRet60D,
            MedianRet7D, MedianRet10D, MedianRet15D, MedianRet20D, MedianRet30D, MedianRet45D, MedianRet60D,
            StdRet7D, StdRet10D, StdRet15D, StdRet20D, StdRet30D, StdRet45D, StdRet60D,
            WinRate7D, WinRate10D, WinRate15D, WinRate20D, WinRate30D, WinRate45D, WinRate60D,
            LargeWinnerRate20D, LargeWinnerRate30D, LargeWinnerRate60D,
            LargeLoserRate20D, LargeLoserRate30D, LargeLoserRate60D,
            AvgMaxUp30D, AvgMaxDD30D, AvgMaxUp60D, AvgMaxDD60D,
            ReliabilityScore, HistoricalEdgeScore, BrokerArchetype, ScoreVersion, SYSUTCDATETIME()
        FROM #HistSummary;
    END;

    ;WITH Prior AS
    (
        SELECT
            h.BrokerName,
            MAX(CASE WHEN h.EventType = 'ACCUM_5D' THEN h.HistoricalEdgeScore END) AS BullPrior5D,
            MAX(CASE WHEN h.EventType = 'DIST_5D' THEN h.HistoricalEdgeScore END) AS BearPrior5D
        FROM Transform.BrokerHistoricalPerformance h
        WHERE h.SnapshotDate = @vAsOfDate
        GROUP BY h.BrokerName
    ),
    StockBroker5D AS
    (
        SELECT
            d.ASXCode,
            d.PriceASXCode,
            d.TradeDate,
            d.DayClose,
            d.DayVWAP,
            d.DayTurnover,
            d.RollTurnover5D,
            d.BrokerName,
            d.BrokerCode,
            d.SumNetBuy5D,
            d.SumNetSell5D,
            d.PositionSharesEst,
            d.AvgCostEst,
            COALESCE(p.BullPrior5D, 0.0) AS BullPrior5D,
            COALESCE(p.BearPrior5D, 0.0) AS BearPrior5D,
            CAST(
                SUM(CASE WHEN d.SumNetBuy5D > 0 THEN d.SumNetBuy5D ELSE 0 END)
                    OVER (PARTITION BY d.ASXCode, d.TradeDate)
                AS decimal(20,4)
            ) AS TotalPositiveNetBuy5D,
            CAST(
                SUM(CASE WHEN d.SumNetSell5D > 0 THEN d.SumNetSell5D ELSE 0 END)
                    OVER (PARTITION BY d.ASXCode, d.TradeDate)
                AS decimal(20,4)
            ) AS TotalPositiveNetSell5D,
            ROW_NUMBER() OVER (PARTITION BY d.ASXCode, d.TradeDate ORDER BY d.SumNetBuy5D DESC, d.BrokerName) AS BuyRank5D,
            ROW_NUMBER() OVER (PARTITION BY d.ASXCode, d.TradeDate ORDER BY d.SumNetSell5D DESC, d.BrokerName) AS SellRank5D
        FROM Transform.BrokerDailyFeature d
        LEFT JOIN Prior p
            ON p.BrokerName = d.BrokerName
        WHERE (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = d.ASXCode))
          AND d.TradeDate >= @vPersistStartDate
          AND d.TradeDate <= @vAsOfDate
    ),
    StockBroker5DFlow AS
    (
        SELECT
            s.*,
            CAST(
                CASE
                    WHEN s.TotalPositiveNetBuy5D > 0 AND s.SumNetBuy5D > 0
                    THEN s.SumNetBuy5D / NULLIF(s.TotalPositiveNetBuy5D, 0)
                    ELSE 0
                END AS decimal(18,8)
            ) AS PositiveFlowShare5D,
            CAST(
                CASE
                    WHEN s.TotalPositiveNetSell5D > 0 AND s.SumNetSell5D > 0
                    THEN s.SumNetSell5D / NULLIF(s.TotalPositiveNetSell5D, 0)
                    ELSE 0
                END AS decimal(18,8)
            ) AS NegativeFlowShare5D
        FROM StockBroker5D s
    ),
    StockAgg AS
    (
        SELECT
            @vAsOfDate AS SnapshotDate,
            s.ASXCode,
            MAX(s.PriceASXCode) AS PriceASXCode,
            s.TradeDate,
            MAX(s.DayClose) AS DayClose,
            MAX(s.DayVWAP) AS DayVWAP,
            MAX(s.DayTurnover) AS DayTurnover,
            MAX(s.RollTurnover5D) AS RollTurnover5D,

            CAST(SUM(s.SumNetBuy5D) AS decimal(20,4)) AS TotalBrokerNetBuy5D,
            CAST(SUM(s.SumNetSell5D) AS decimal(20,4)) AS TotalBrokerNetSell5D,

            CAST(MAX(CASE WHEN s.BuyRank5D = 1 THEN CASE WHEN s.RollTurnover5D > 0 THEN s.SumNetBuy5D / s.RollTurnover5D ELSE 0 END END) AS decimal(18,8)) AS Top1BrokerNetBuyShare5D,
            CAST(SUM(CASE WHEN s.BuyRank5D <= 3 THEN CASE WHEN s.RollTurnover5D > 0 THEN s.SumNetBuy5D / s.RollTurnover5D ELSE 0 END ELSE 0 END) AS decimal(18,8)) AS Top3BrokerNetBuyShare5D,
            CAST(MAX(CASE WHEN s.SellRank5D = 1 THEN CASE WHEN s.RollTurnover5D > 0 THEN s.SumNetSell5D / s.RollTurnover5D ELSE 0 END END) AS decimal(18,8)) AS Top1BrokerNetSellShare5D,
            CAST(SUM(CASE WHEN s.SellRank5D <= 3 THEN CASE WHEN s.RollTurnover5D > 0 THEN s.SumNetSell5D / s.RollTurnover5D ELSE 0 END ELSE 0 END) AS decimal(18,8)) AS Top3BrokerNetSellShare5D,

            COUNT(CASE WHEN s.SumNetBuy5D > 0 THEN 1 END) AS PositiveBrokerCount5D,
            COUNT(CASE WHEN s.SumNetSell5D > 0 THEN 1 END) AS NegativeBrokerCount5D,

            CAST(SUM(s.SumNetBuy5D * s.BullPrior5D) AS decimal(20,4)) AS SmartBrokerNetBuy5D,
            CAST(SUM(s.SumNetSell5D * s.BearPrior5D) AS decimal(20,4)) AS SmartBrokerNetSell5D,

            CAST(CASE
                WHEN MAX(s.TotalPositiveNetBuy5D) > 0
                THEN SUM(POWER(s.PositiveFlowShare5D, 2))
                ELSE 0
            END AS decimal(18,8)) AS PositiveFlowHHI5D,
            CAST(CASE
                WHEN MAX(s.TotalPositiveNetSell5D) > 0
                THEN SUM(POWER(s.NegativeFlowShare5D, 2))
                ELSE 0
            END AS decimal(18,8)) AS NegativeFlowHHI5D,

            CAST(
                CASE
                    WHEN SUM(CASE WHEN s.PositionSharesEst > 0 THEN s.PositionSharesEst ELSE 0 END) > 0
                    THEN SUM(CASE WHEN s.PositionSharesEst > 0 THEN s.PositionSharesEst * s.AvgCostEst ELSE 0 END)
                         / NULLIF(SUM(CASE WHEN s.PositionSharesEst > 0 THEN s.PositionSharesEst ELSE 0 END), 0)
                END AS decimal(20,8)
            ) AS EstimatedCompositeCost,

            MAX(CASE WHEN s.BuyRank5D = 1 THEN s.BrokerName END) AS LeadBullBroker,
            MAX(CASE WHEN s.SellRank5D = 1 THEN s.BrokerName END) AS LeadBearBroker
        FROM StockBroker5DFlow s
        GROUP BY s.ASXCode, s.TradeDate
    )
    SELECT
        a.SnapshotDate,
        a.ASXCode,
        a.PriceASXCode,
        a.TradeDate,
        a.DayClose,
        a.DayVWAP,
        a.DayTurnover,
        a.RollTurnover5D,
        a.TotalBrokerNetBuy5D,
        a.TotalBrokerNetSell5D,
        a.Top1BrokerNetBuyShare5D,
        a.Top3BrokerNetBuyShare5D,
        a.Top1BrokerNetSellShare5D,
        a.Top3BrokerNetSellShare5D,
        a.PositiveFlowHHI5D,
        a.NegativeFlowHHI5D,
        a.PositiveBrokerCount5D,
        a.NegativeBrokerCount5D,
        a.SmartBrokerNetBuy5D,
        a.SmartBrokerNetSell5D,
        CAST(CASE WHEN a.RollTurnover5D > 0 THEN a.SmartBrokerNetBuy5D / a.RollTurnover5D ELSE 0 END AS decimal(18,8)) AS SmartBrokerNetBuyPct5D,
        CAST(CASE WHEN a.RollTurnover5D > 0 THEN a.SmartBrokerNetSell5D / a.RollTurnover5D ELSE 0 END AS decimal(18,8)) AS SmartBrokerNetSellPct5D,
        a.EstimatedCompositeCost,
        CAST(CASE WHEN a.EstimatedCompositeCost > 0 THEN (a.DayClose / a.EstimatedCompositeCost) - 1.0 END AS decimal(18,8)) AS CloseVsCompositeCost,
        a.LeadBullBroker,
        a.LeadBearBroker,
        CAST(
              0.30 * CASE WHEN a.RollTurnover5D > 0 THEN CASE WHEN a.SmartBrokerNetBuy5D / a.RollTurnover5D >= 0.05 THEN 1.0 ELSE (a.SmartBrokerNetBuy5D / a.RollTurnover5D) / 0.05 END ELSE 0 END
            + 0.20 * CASE WHEN a.Top3BrokerNetBuyShare5D >= 0.10 THEN 1.0 ELSE a.Top3BrokerNetBuyShare5D / 0.10 END
            + 0.15 * CASE WHEN a.PositiveBrokerCount5D >= 5 THEN 1.0 ELSE CAST(a.PositiveBrokerCount5D AS float) / 5.0 END
            + 0.15 * CASE
                         WHEN a.EstimatedCompositeCost IS NULL OR a.EstimatedCompositeCost <= 0 THEN 0
                         WHEN (a.DayClose / a.EstimatedCompositeCost) - 1.0 >= 0.05 THEN 1.0
                         WHEN (a.DayClose / a.EstimatedCompositeCost) - 1.0 <= -0.05 THEN 0.0
                         ELSE ((a.DayClose / a.EstimatedCompositeCost) - 1.0 + 0.05) / 0.10
                     END
            + 0.20 * CASE
                         WHEN a.RollTurnover5D <= 0 THEN 0
                         WHEN (a.TotalBrokerNetBuy5D - a.TotalBrokerNetSell5D) / a.RollTurnover5D >= 0.05 THEN 1.0
                         WHEN (a.TotalBrokerNetBuy5D - a.TotalBrokerNetSell5D) / a.RollTurnover5D <= 0 THEN 0.0
                         ELSE ((a.TotalBrokerNetBuy5D - a.TotalBrokerNetSell5D) / a.RollTurnover5D) / 0.05
                     END
            AS decimal(18,8)
        ) AS BullishSetupScore,
        CAST(
              0.30 * CASE WHEN a.RollTurnover5D > 0 THEN CASE WHEN a.SmartBrokerNetSell5D / a.RollTurnover5D >= 0.05 THEN 1.0 ELSE (a.SmartBrokerNetSell5D / a.RollTurnover5D) / 0.05 END ELSE 0 END
            + 0.20 * CASE WHEN a.Top3BrokerNetSellShare5D >= 0.10 THEN 1.0 ELSE a.Top3BrokerNetSellShare5D / 0.10 END
            + 0.15 * CASE WHEN a.NegativeBrokerCount5D >= 5 THEN 1.0 ELSE CAST(a.NegativeBrokerCount5D AS float) / 5.0 END
            + 0.15 * CASE
                         WHEN a.EstimatedCompositeCost IS NULL OR a.EstimatedCompositeCost <= 0 THEN 0
                         WHEN (a.DayClose / a.EstimatedCompositeCost) - 1.0 <= -0.05 THEN 1.0
                         WHEN (a.DayClose / a.EstimatedCompositeCost) - 1.0 >= 0.05 THEN 0.0
                         ELSE (0.05 - ((a.DayClose / a.EstimatedCompositeCost) - 1.0)) / 0.10
                     END
            + 0.20 * CASE
                         WHEN a.RollTurnover5D <= 0 THEN 0
                         WHEN (a.TotalBrokerNetSell5D - a.TotalBrokerNetBuy5D) / a.RollTurnover5D >= 0.05 THEN 1.0
                         WHEN (a.TotalBrokerNetSell5D - a.TotalBrokerNetBuy5D) / a.RollTurnover5D <= 0 THEN 0.0
                         ELSE ((a.TotalBrokerNetSell5D - a.TotalBrokerNetBuy5D) / a.RollTurnover5D) / 0.05
                     END
            AS decimal(18,8)
        ) AS BearishSetupScore
    INTO #StockSetup
    FROM StockAgg a;

    DELETE s
    FROM Transform.StockDayBrokerSetup s
    WHERE s.SnapshotDate = @vAsOfDate
      AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = s.ASXCode));

    INSERT INTO Transform.StockDayBrokerSetup
    (
        SnapshotDate, ASXCode, PriceASXCode, TradeDate,
        DayClose, DayVWAP, DayTurnover, RollTurnover5D,
        TotalBrokerNetBuy5D, TotalBrokerNetSell5D,
        Top1BrokerNetBuyShare5D, Top3BrokerNetBuyShare5D,
        Top1BrokerNetSellShare5D, Top3BrokerNetSellShare5D,
        PositiveFlowHHI5D, NegativeFlowHHI5D,
        PositiveBrokerCount5D, NegativeBrokerCount5D,
        SmartBrokerNetBuy5D, SmartBrokerNetSell5D, SmartBrokerNetBuyPct5D, SmartBrokerNetSellPct5D,
        EstimatedCompositeCost, CloseVsCompositeCost,
        LeadBullBroker, LeadBearBroker,
        BullishSetupScore, BearishSetupScore,
        ScoreVersion, CreatedDate
    )
    SELECT
        SnapshotDate, ASXCode, PriceASXCode, TradeDate,
        DayClose, DayVWAP, DayTurnover, RollTurnover5D,
        TotalBrokerNetBuy5D, TotalBrokerNetSell5D,
        Top1BrokerNetBuyShare5D, Top3BrokerNetBuyShare5D,
        Top1BrokerNetSellShare5D, Top3BrokerNetSellShare5D,
        PositiveFlowHHI5D, NegativeFlowHHI5D,
        PositiveBrokerCount5D, NegativeBrokerCount5D,
        SmartBrokerNetBuy5D, SmartBrokerNetSell5D, SmartBrokerNetBuyPct5D, SmartBrokerNetSellPct5D,
        EstimatedCompositeCost, CloseVsCompositeCost,
        LeadBullBroker, LeadBearBroker,
        BullishSetupScore, BearishSetupScore,
        @vScoreVersion, SYSUTCDATETIME()
    FROM #StockSetup;
END
