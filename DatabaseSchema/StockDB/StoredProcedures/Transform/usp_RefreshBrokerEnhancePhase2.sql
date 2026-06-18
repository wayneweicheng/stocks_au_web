-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase2]

-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase2]


CREATE   PROCEDURE Transform.usp_RefreshBrokerEnhancePhase2
    @pAsOfDate                    date            = NULL,
    @pASXCode                     varchar(10)     = NULL,
    @pvchStockCodeList            varchar(max)    = NULL,
    @pLookbackCalendarDays        int             = 30,
    @pTriggerMode                 varchar(20)     = 'HYBRID',
    @pMinBullishSetupScore        decimal(18,8)   = 0.60000000,
    @pMinBearishSetupScore        decimal(18,8)   = 0.60000000,
    @pMaxEventStocks              int             = 200,
    @pArchiveRetentionDays        int             = 90,
    @pPersistArchive              bit             = 0,
    @pRunPhase3                   bit             = 0,
    @pMinTotalValue               decimal(20,2)   = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @vAsOfDate date =
        COALESCE(@pAsOfDate, (SELECT MAX(ObservationDate) FROM StockData.BrokerTradeTransaction));

    DECLARE @vBaseASXCode varchar(10) =
        CASE
            WHEN @pASXCode IS NULL THEN NULL
            ELSE UPPER(LTRIM(RTRIM(REPLACE(@pASXCode, '.AX', ''))))
        END;
    DECLARE @vHasStockCodeFilter bit = 0;

    DECLARE @vLookbackCalendarDays int = CASE WHEN ISNULL(@pLookbackCalendarDays, 0) > 0 THEN @pLookbackCalendarDays ELSE 30 END;
    DECLARE @vWindowStartDate date = DATEADD(DAY, 1 - @vLookbackCalendarDays, @vAsOfDate);
    DECLARE @vTriggerMode varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@pTriggerMode, 'HYBRID'))));
    DECLARE @vIncludeTxUniverse bit =
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(@pTriggerMode, 'HYBRID')))) IN ('TX', 'ALL', 'HYBRID') THEN 1
            ELSE 0
        END;
    DECLARE @vScoreVersion varchar(40) = 'broker_enhance_phase2_v1';
    DECLARE @vArchiveRetentionDays int = CASE WHEN ISNULL(@pArchiveRetentionDays, 0) > 0 THEN @pArchiveRetentionDays ELSE 90 END;
    DECLARE @vArchiveCutoffDate date = DATEADD(DAY, -@vArchiveRetentionDays, @vAsOfDate);
    DECLARE @vCaptureRunID bigint;
    DECLARE @vTxUniverseDate date =
    (
        SELECT MAX(t.ObservationDate)
        FROM StockData.BrokerTradeTransaction t
        WHERE t.ObservationDate <= @vAsOfDate
    );

    DROP TABLE IF EXISTS #CandidateRaw;
    DROP TABLE IF EXISTS #StockCodeFilter;
    DROP TABLE IF EXISTS #Candidates;
    DROP TABLE IF EXISTS #CandidateTxCode;
    DROP TABLE IF EXISTS #BrokerLookupResolved;
    DROP TABLE IF EXISTS #TxBase;
    DROP TABLE IF EXISTS #BuyerAgg;
    DROP TABLE IF EXISTS #BuyerRank;
    DROP TABLE IF EXISTS #SellerAgg;
    DROP TABLE IF EXISTS #SellerRank;
    DROP TABLE IF EXISTS #CoverageAgg;
    DROP TABLE IF EXISTS #CoverageScope;
    DROP TABLE IF EXISTS #TxWindow;
    DROP TABLE IF EXISTS #MicroBase;

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

    CREATE TABLE #CandidateRaw
    (
        ASXCode                     varchar(10)     NOT NULL,
        PriceASXCode                varchar(10)     NULL,
        CaptureSource               varchar(20)     NOT NULL,
        Priority                    int             NOT NULL,
        BullishSetupScore           decimal(18,8)   NULL,
        BearishSetupScore           decimal(18,8)   NULL
    );

    /*
        Trigger mode behavior:
        - EVENT: ranked setup candidates only, capped by @pMaxEventStocks.
        - HYBRID: union of CURATED + EVENT + TX candidates (no event top-cap).
        - TX: transaction universe only.
        - ALL: transaction universe only (legacy behavior retained).
        - HYBRID guarantee: if a stock has transactions in the latest tx universe date
          (<= @pAsOfDate), it is included via TX candidate expansion even when not in
          curated/event selections.
    */

    IF @vTriggerMode IN ('CURATED', 'HYBRID')
    BEGIN
        INSERT INTO #CandidateRaw
        (
            ASXCode,
            PriceASXCode,
            CaptureSource,
            Priority,
            BullishSetupScore,
            BearishSetupScore
        )
        SELECT
            u.ASXCode,
            NULL,
            'CURATED',
            u.Priority,
            NULL,
            NULL
        FROM Transform.BrokerTxCaptureUniverse u
        WHERE u.IsEnabled = 1
          AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = u.ASXCode));
    END;

    IF @vTriggerMode = 'EVENT'
    BEGIN
        ;WITH LatestSnapshot AS
        (
            SELECT MAX(SnapshotDate) AS SnapshotDate
            FROM Transform.StockDayBrokerSetup
            WHERE SnapshotDate <= @vAsOfDate
        ),
        RankedSetup AS
        (
            SELECT
                s.ASXCode,
                s.PriceASXCode,
                s.TradeDate,
                s.BullishSetupScore,
                s.BearishSetupScore,
                CASE
                    WHEN s.BullishSetupScore >= s.BearishSetupScore THEN s.BullishSetupScore
                    ELSE s.BearishSetupScore
                END AS TriggerScore,
                ROW_NUMBER() OVER
                (
                    PARTITION BY s.ASXCode
                    ORDER BY s.TradeDate DESC,
                             CASE
                                 WHEN s.BullishSetupScore >= s.BearishSetupScore THEN s.BullishSetupScore
                                 ELSE s.BearishSetupScore
                             END DESC
                ) AS ASXRank
            FROM Transform.StockDayBrokerSetup s
            CROSS JOIN LatestSnapshot ls
            WHERE ls.SnapshotDate IS NOT NULL
              AND s.SnapshotDate = ls.SnapshotDate
              AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = s.ASXCode))
              AND (
                    s.BullishSetupScore >= @pMinBullishSetupScore
                    OR s.BearishSetupScore >= @pMinBearishSetupScore
                  )
        )
        INSERT INTO #CandidateRaw
        (
            ASXCode,
            PriceASXCode,
            CaptureSource,
            Priority,
            BullishSetupScore,
            BearishSetupScore
        )
        SELECT TOP (@pMaxEventStocks)
            r.ASXCode,
            r.PriceASXCode,
            'EVENT',
            CAST(ROUND(r.TriggerScore * 1000.0, 0) AS int),
            r.BullishSetupScore,
            r.BearishSetupScore
        FROM RankedSetup r
        WHERE r.ASXRank = 1
        ORDER BY r.TriggerScore DESC, r.ASXCode;
    END;

    IF @vTriggerMode = 'HYBRID'
    BEGIN
        ;WITH LatestSnapshot AS
        (
            SELECT MAX(SnapshotDate) AS SnapshotDate
            FROM Transform.StockDayBrokerSetup
            WHERE SnapshotDate <= @vAsOfDate
        ),
        RankedSetup AS
        (
            SELECT
                s.ASXCode,
                s.PriceASXCode,
                s.TradeDate,
                s.BullishSetupScore,
                s.BearishSetupScore,
                CASE
                    WHEN s.BullishSetupScore >= s.BearishSetupScore THEN s.BullishSetupScore
                    ELSE s.BearishSetupScore
                END AS TriggerScore,
                ROW_NUMBER() OVER
                (
                    PARTITION BY s.ASXCode
                    ORDER BY s.TradeDate DESC,
                             CASE
                                 WHEN s.BullishSetupScore >= s.BearishSetupScore THEN s.BullishSetupScore
                                 ELSE s.BearishSetupScore
                             END DESC
                ) AS ASXRank
            FROM Transform.StockDayBrokerSetup s
            CROSS JOIN LatestSnapshot ls
            WHERE ls.SnapshotDate IS NOT NULL
              AND s.SnapshotDate = ls.SnapshotDate
              AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = s.ASXCode))
              AND (
                    s.BullishSetupScore >= @pMinBullishSetupScore
                    OR s.BearishSetupScore >= @pMinBearishSetupScore
                  )
        )
        INSERT INTO #CandidateRaw
        (
            ASXCode,
            PriceASXCode,
            CaptureSource,
            Priority,
            BullishSetupScore,
            BearishSetupScore
        )
        SELECT
            r.ASXCode,
            r.PriceASXCode,
            'EVENT',
            CAST(ROUND(r.TriggerScore * 1000.0, 0) AS int),
            r.BullishSetupScore,
            r.BearishSetupScore
        FROM RankedSetup r
        WHERE r.ASXRank = 1
        ORDER BY r.TriggerScore DESC, r.ASXCode;
    END;

    IF @vIncludeTxUniverse = 1
    BEGIN
        INSERT INTO #CandidateRaw
        (
            ASXCode,
            PriceASXCode,
            CaptureSource,
            Priority,
            BullishSetupScore,
            BearishSetupScore
        )
        SELECT
            CASE
                WHEN RIGHT(tx.ASXCode, 3) = '.AX' THEN LEFT(tx.ASXCode, LEN(tx.ASXCode) - 3)
                ELSE tx.ASXCode
            END AS ASXCode,
            MAX(tx.ASXCode) AS PriceASXCode,
            'TX',
            500,
            NULL,
            NULL
        FROM StockData.BrokerTradeTransaction tx
        WHERE @vTxUniverseDate IS NOT NULL
          AND tx.ObservationDate = @vTxUniverseDate
          AND
          (
              @vHasStockCodeFilter = 0
              OR EXISTS
              (
                  SELECT 1
                  FROM #StockCodeFilter f
                  WHERE tx.ASXCode = f.ASXCode
                     OR tx.ASXCode = f.ASXCode + '.AX'
              )
          )
        GROUP BY
            CASE
                WHEN RIGHT(tx.ASXCode, 3) = '.AX' THEN LEFT(tx.ASXCode, LEN(tx.ASXCode) - 3)
                ELSE tx.ASXCode
            END;
    END;

    SELECT
        c.ASXCode,
        MAX(c.PriceASXCode) AS PriceASXCode,
        CASE
            WHEN COUNT(DISTINCT c.CaptureSource) > 1 THEN 'HYBRID'
            ELSE MAX(c.CaptureSource)
        END AS CaptureSource,
        MAX(c.Priority) AS Priority,
        MAX(c.BullishSetupScore) AS BullishSetupScore,
        MAX(c.BearishSetupScore) AS BearishSetupScore
    INTO #Candidates
    FROM #CandidateRaw c
    GROUP BY c.ASXCode;

    CREATE TABLE #CandidateTxCode
    (
        ASXCode              varchar(10)     NOT NULL,
        TxASXCode            varchar(10)     NOT NULL,
        PriceASXCode         varchar(10)     NULL,
        CaptureSource        varchar(20)     NOT NULL,
        BullishSetupScore    decimal(18,8)   NULL,
        BearishSetupScore    decimal(18,8)   NULL
    );

    INSERT INTO #CandidateTxCode
    (
        ASXCode,
        TxASXCode,
        PriceASXCode,
        CaptureSource,
        BullishSetupScore,
        BearishSetupScore
    )
    SELECT
        c.ASXCode,
        c.ASXCode,
        c.PriceASXCode,
        c.CaptureSource,
        c.BullishSetupScore,
        c.BearishSetupScore
    FROM #Candidates c
    UNION ALL
    SELECT
        c.ASXCode,
        c.ASXCode + '.AX',
        c.PriceASXCode,
        c.CaptureSource,
        c.BullishSetupScore,
        c.BearishSetupScore
    FROM #Candidates c;

    CREATE INDEX IX_CandidateTxCode_TxASXCode
        ON #CandidateTxCode (TxASXCode);

    ;WITH LookupRaw AS
    (
        SELECT
            UPPER(LTRIM(RTRIM(v.LookupName))) AS LookupName,
            l.BrokerCode,
            l.BrokerLevel,
            l.BrokerScore,
            ROW_NUMBER() OVER
            (
                PARTITION BY UPPER(LTRIM(RTRIM(v.LookupName)))
                ORDER BY
                    CASE WHEN v.IsPrimary = 1 THEN 0 ELSE 1 END,
                    l.BrokerCode
            ) AS Rn
        FROM LookupRef.BrokerName l
        CROSS APPLY
        (
            VALUES
                (l.BrokerName, 1),
                (l.APIBrokerName, 0)
        ) v(LookupName, IsPrimary)
        WHERE v.LookupName IS NOT NULL
          AND LTRIM(RTRIM(v.LookupName)) <> ''
    )
    SELECT
        r.LookupName,
        r.BrokerCode,
        r.BrokerLevel,
        r.BrokerScore
    INTO #BrokerLookupResolved
    FROM LookupRaw r
    WHERE r.Rn = 1;

    CREATE UNIQUE CLUSTERED INDEX IX_BrokerLookupResolved_Name
        ON #BrokerLookupResolved (LookupName);

    INSERT INTO Transform.BrokerTxCaptureRun
    (
        RunDate,
        WindowStartDate,
        WindowEndDate,
        TriggerMode,
        CandidateCount,
        ArchivedRowCount,
        CoverageRowCount,
        SourceMaxObservationDate,
        ScoreVersion
    )
    VALUES
    (
        @vAsOfDate,
        @vWindowStartDate,
        @vAsOfDate,
        @vTriggerMode,
        (SELECT COUNT(*) FROM #Candidates),
        0,
        0,
        (SELECT MAX(ObservationDate) FROM StockData.BrokerTradeTransaction),
        @vScoreVersion
    );

    SET @vCaptureRunID = SCOPE_IDENTITY();

    SELECT
        tx.TransactionID AS SourceTransactionID,
        c.ASXCode,
        tx.ASXCode AS PriceASXCode,
        tx.ObservationDate,
        tx.TransactionDateTime,
        tx.Buyer AS BuyerBrokerName,
        buyLkp.BrokerCode AS BuyerBrokerCode,
        buyLkp.BrokerLevel AS BuyerBrokerLevel,
        buyLkp.BrokerScore AS BuyerBrokerScore,
        tx.Seller AS SellerBrokerName,
        sellLkp.BrokerCode AS SellerBrokerCode,
        sellLkp.BrokerLevel AS SellerBrokerLevel,
        sellLkp.BrokerScore AS SellerBrokerScore,
        CAST(tx.Price AS decimal(20,4)) AS Price,
        tx.Volume,
        CAST(tx.Value AS decimal(20,2)) AS Value,
        tx.[Condition],
        tx.Market,
        c.CaptureSource,
        c.BullishSetupScore,
        c.BearishSetupScore
    INTO #TxBase
    FROM StockData.BrokerTradeTransaction tx
    INNER JOIN #CandidateTxCode c
        ON tx.ASXCode = c.TxASXCode
    LEFT JOIN #BrokerLookupResolved buyLkp
        ON buyLkp.LookupName = UPPER(LTRIM(RTRIM(tx.Buyer)))
    LEFT JOIN #BrokerLookupResolved sellLkp
        ON sellLkp.LookupName = UPPER(LTRIM(RTRIM(tx.Seller)))
    WHERE tx.ObservationDate >= @vWindowStartDate
      AND tx.ObservationDate <= @vAsOfDate
      AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = c.ASXCode));

    CREATE CLUSTERED INDEX IX_TxBase_ASX_Obs
        ON #TxBase (ASXCode, ObservationDate, TransactionDateTime);

    CREATE UNIQUE NONCLUSTERED INDEX IX_TxBase_SourceTransactionID
        ON #TxBase (SourceTransactionID);

    IF @pPersistArchive = 1
    BEGIN
        DELETE a
        FROM Transform.BrokerTxArchive a
        INNER JOIN #Candidates c
            ON c.ASXCode = a.ASXCode
        WHERE a.ObservationDate >= @vWindowStartDate
          AND a.ObservationDate <= @vAsOfDate;

        INSERT INTO Transform.BrokerTxArchive
        (
            SourceTransactionID,
            CaptureRunID,
            ASXCode,
            PriceASXCode,
            ObservationDate,
            TransactionDateTime,
            BuyerBrokerName,
            BuyerBrokerCode,
            BuyerBrokerLevel,
            BuyerBrokerScore,
            SellerBrokerName,
            SellerBrokerCode,
            SellerBrokerLevel,
            SellerBrokerScore,
            Price,
            Volume,
            Value,
            [Condition],
            Market,
            CaptureSource,
            BullishSetupScore,
            BearishSetupScore,
            ScoreVersion,
            CreatedDate
        )
        SELECT
            SourceTransactionID,
            @vCaptureRunID,
            ASXCode,
            PriceASXCode,
            ObservationDate,
            TransactionDateTime,
            BuyerBrokerName,
            BuyerBrokerCode,
            BuyerBrokerLevel,
            BuyerBrokerScore,
            SellerBrokerName,
            SellerBrokerCode,
            SellerBrokerLevel,
            SellerBrokerScore,
            Price,
            Volume,
            Value,
            [Condition],
            Market,
            CaptureSource,
            BullishSetupScore,
            BearishSetupScore,
            @vScoreVersion,
            SYSUTCDATETIME()
        FROM #TxBase
        OPTION (RECOMPILE);

        -- Keep archive bounded to reduce long-term insert/delete and index maintenance cost.
        IF @vHasStockCodeFilter = 0 AND @vArchiveRetentionDays > 0
        BEGIN
            DELETE a
            FROM Transform.BrokerTxArchive a
            WHERE a.ObservationDate < @vArchiveCutoffDate;
        END;
    END;

    SELECT
        t.ASXCode,
        t.ObservationDate,
        t.BuyerBrokerName,
        CAST(SUM(t.Value) AS decimal(20,2)) AS BuyerValue
    INTO #BuyerAgg
    FROM #TxBase t
    GROUP BY t.ASXCode, t.ObservationDate, t.BuyerBrokerName;

    CREATE CLUSTERED INDEX IX_BuyerAgg_AsxObsBuyer
        ON #BuyerAgg (ASXCode, ObservationDate, BuyerBrokerName);

    SELECT
        b.ASXCode,
        b.ObservationDate,
        b.BuyerBrokerName,
        b.BuyerValue,
        ROW_NUMBER() OVER (PARTITION BY b.ASXCode, b.ObservationDate ORDER BY b.BuyerValue DESC, b.BuyerBrokerName) AS BuyerRank
    INTO #BuyerRank
    FROM #BuyerAgg b;

    CREATE CLUSTERED INDEX IX_BuyerRank_AsxObsRank
        ON #BuyerRank (ASXCode, ObservationDate, BuyerRank);

    SELECT
        t.ASXCode,
        t.ObservationDate,
        t.SellerBrokerName,
        CAST(SUM(t.Value) AS decimal(20,2)) AS SellerValue
    INTO #SellerAgg
    FROM #TxBase t
    GROUP BY t.ASXCode, t.ObservationDate, t.SellerBrokerName;

    CREATE CLUSTERED INDEX IX_SellerAgg_AsxObsSeller
        ON #SellerAgg (ASXCode, ObservationDate, SellerBrokerName);

    SELECT
        s.ASXCode,
        s.ObservationDate,
        s.SellerBrokerName,
        s.SellerValue,
        ROW_NUMBER() OVER (PARTITION BY s.ASXCode, s.ObservationDate ORDER BY s.SellerValue DESC, s.SellerBrokerName) AS SellerRank
    INTO #SellerRank
    FROM #SellerAgg s;

    CREATE CLUSTERED INDEX IX_SellerRank_AsxObsRank
        ON #SellerRank (ASXCode, ObservationDate, SellerRank);

    SELECT
        @vAsOfDate AS SnapshotDate,
        t.ASXCode,
        MAX(t.PriceASXCode) AS PriceASXCode,
        t.ObservationDate,
        MAX(t.CaptureSource) AS CaptureSource,
        MAX(t.BullishSetupScore) AS BullishSetupScore,
        MAX(t.BearishSetupScore) AS BearishSetupScore,
        COUNT_BIG(*) AS TransactionCount,
        CAST(SUM(t.Value) AS decimal(20,2)) AS TotalValue,
        SUM(t.Volume) AS TotalVolume,
        MIN(t.TransactionDateTime) AS FirstTransactionDateTime,
        MAX(t.TransactionDateTime) AS LastTransactionDateTime
    INTO #CoverageBase
    FROM #TxBase t
    GROUP BY t.ASXCode, t.ObservationDate;

    CREATE CLUSTERED INDEX IX_CoverageBase_ASXDate
        ON #CoverageBase (ASXCode, ObservationDate);

    SELECT b.ASXCode, b.ObservationDate, COUNT_BIG(*) AS DistinctBuyerCount
    INTO #BuyerDistinct
    FROM #BuyerAgg b
    GROUP BY b.ASXCode, b.ObservationDate;

    CREATE CLUSTERED INDEX IX_BuyerDistinct_ASXDate
        ON #BuyerDistinct (ASXCode, ObservationDate);

    SELECT s.ASXCode, s.ObservationDate, COUNT_BIG(*) AS DistinctSellerCount
    INTO #SellerDistinct
    FROM #SellerAgg s
    GROUP BY s.ASXCode, s.ObservationDate;

    CREATE CLUSTERED INDEX IX_SellerDistinct_ASXDate
        ON #SellerDistinct (ASXCode, ObservationDate);

    SELECT br.ASXCode, br.ObservationDate, br.BuyerBrokerName AS TopBuyerBrokerName, br.BuyerValue AS TopBuyerValue
    INTO #TopBuyer
    FROM #BuyerRank br
    WHERE br.BuyerRank = 1;

    CREATE CLUSTERED INDEX IX_TopBuyer_ASXDate
        ON #TopBuyer (ASXCode, ObservationDate);

    SELECT sr.ASXCode, sr.ObservationDate, sr.SellerBrokerName AS TopSellerBrokerName, sr.SellerValue AS TopSellerValue
    INTO #TopSeller
    FROM #SellerRank sr
    WHERE sr.SellerRank = 1;

    CREATE CLUSTERED INDEX IX_TopSeller_ASXDate
        ON #TopSeller (ASXCode, ObservationDate);

    SELECT
        b.SnapshotDate,
        b.ASXCode,
        b.PriceASXCode,
        b.ObservationDate,
        b.CaptureSource,
        b.BullishSetupScore,
        b.BearishSetupScore,
        b.TransactionCount,
        CAST(ISNULL(db.DistinctBuyerCount, 0) AS int) AS DistinctBuyerCount,
        CAST(ISNULL(ds.DistinctSellerCount, 0) AS int) AS DistinctSellerCount,
        b.TotalValue,
        b.TotalVolume,
        b.FirstTransactionDateTime,
        b.LastTransactionDateTime,
        tb.TopBuyerBrokerName,
        tb.TopBuyerValue,
        ts.TopSellerBrokerName,
        ts.TopSellerValue
    INTO #CoverageAgg
    FROM #CoverageBase b
    LEFT JOIN #BuyerDistinct db
        ON db.ASXCode = b.ASXCode
       AND db.ObservationDate = b.ObservationDate
    LEFT JOIN #SellerDistinct ds
        ON ds.ASXCode = b.ASXCode
       AND ds.ObservationDate = b.ObservationDate
    LEFT JOIN #TopBuyer tb
        ON tb.ASXCode = b.ASXCode
       AND tb.ObservationDate = b.ObservationDate
    LEFT JOIN #TopSeller ts
        ON ts.ASXCode = b.ASXCode
       AND ts.ObservationDate = b.ObservationDate;

    DELETE c
    FROM Transform.BrokerTxCoverage c
    INNER JOIN #Candidates k
        ON k.ASXCode = c.ASXCode
    WHERE c.SnapshotDate = @vAsOfDate;

    INSERT INTO Transform.BrokerTxCoverage
    (
        SnapshotDate,
        ASXCode,
        PriceASXCode,
        ObservationDate,
        CaptureSource,
        BullishSetupScore,
        BearishSetupScore,
        TransactionCount,
        DistinctBuyerCount,
        DistinctSellerCount,
        TotalValue,
        TotalVolume,
        FirstTransactionDateTime,
        LastTransactionDateTime,
        TopBuyerBrokerName,
        TopBuyerValue,
        TopSellerBrokerName,
        TopSellerValue,
        ScoreVersion,
        CreatedDate
    )
    SELECT
        SnapshotDate,
        ASXCode,
        PriceASXCode,
        ObservationDate,
        CaptureSource,
        BullishSetupScore,
        BearishSetupScore,
        TransactionCount,
        DistinctBuyerCount,
        DistinctSellerCount,
        TotalValue,
        TotalVolume,
        FirstTransactionDateTime,
        LastTransactionDateTime,
        TopBuyerBrokerName,
        TopBuyerValue,
        TopSellerBrokerName,
        TopSellerValue,
        @vScoreVersion,
        SYSUTCDATETIME()
    FROM #CoverageAgg;

    IF @pRunPhase3 = 1
    BEGIN
        DECLARE @vScoreVersionPhase3 varchar(40) = 'broker_enhance_phase3_v3';

        SELECT
            c.SnapshotDate,
            c.ASXCode,
            c.PriceASXCode,
            c.ObservationDate,
            c.CaptureSource,
            c.BullishSetupScore,
            c.BearishSetupScore,
            c.TransactionCount,
            c.DistinctBuyerCount,
            c.DistinctSellerCount,
            c.TotalValue,
            c.TotalVolume,
            c.TopBuyerBrokerName,
            c.TopBuyerValue,
            c.TopSellerBrokerName,
            c.TopSellerValue
        INTO #CoverageScope
        FROM #CoverageAgg c
        WHERE c.SnapshotDate = @vAsOfDate
          AND c.ObservationDate >= @vWindowStartDate
          AND c.ObservationDate <= @vAsOfDate
          AND c.TotalValue >= @pMinTotalValue
          AND (@vHasStockCodeFilter = 0 OR EXISTS (SELECT 1 FROM #StockCodeFilter f WHERE f.ASXCode = c.ASXCode));

        CREATE CLUSTERED INDEX IX_CoverageScope_ASXDate
            ON #CoverageScope (ASXCode, ObservationDate);

        SELECT
            t.ASXCode,
            t.ObservationDate,
            t.BuyerBrokerName,
            t.SellerBrokerName,
            t.Price,
            t.Value
        INTO #TxWindow
        FROM #TxBase t
        INNER JOIN #CoverageScope c
            ON c.ASXCode = t.ASXCode
           AND c.ObservationDate = t.ObservationDate;

        CREATE CLUSTERED INDEX IX_TxWindow_ASXDate
            ON #TxWindow (ASXCode, ObservationDate);

        CREATE NONCLUSTERED INDEX IX_TxWindow_BuyerAgg
            ON #TxWindow (ASXCode, ObservationDate, BuyerBrokerName)
            INCLUDE (Value, Price, SellerBrokerName);

        CREATE NONCLUSTERED INDEX IX_TxWindow_SellerAgg
            ON #TxWindow (ASXCode, ObservationDate, SellerBrokerName)
            INCLUDE (Value, Price, BuyerBrokerName);

        SELECT
            s.ASXCode,
            s.ObservationDate,
            s.BrokerName,
            CAST(SUM(s.BuyValue) AS decimal(20,2)) AS BuyValue,
            CAST(SUM(s.SellValue) AS decimal(20,2)) AS SellValue,
            CAST(SUM(s.BuyValue - s.SellValue) AS decimal(20,2)) AS NetValue
        INTO #BrokerNet
        FROM
        (
            SELECT t.ASXCode, t.ObservationDate, t.BuyerBrokerName AS BrokerName,
                   CAST(SUM(t.Value) AS decimal(20,2)) AS BuyValue,
                   CAST(0 AS decimal(20,2)) AS SellValue
            FROM #TxWindow t
            GROUP BY t.ASXCode, t.ObservationDate, t.BuyerBrokerName

            UNION ALL

            SELECT t.ASXCode, t.ObservationDate, t.SellerBrokerName AS BrokerName,
                   CAST(0 AS decimal(20,2)) AS BuyValue,
                   CAST(SUM(t.Value) AS decimal(20,2)) AS SellValue
            FROM #TxWindow t
            GROUP BY t.ASXCode, t.ObservationDate, t.SellerBrokerName
        ) s
        GROUP BY s.ASXCode, s.ObservationDate, s.BrokerName;

        CREATE CLUSTERED INDEX IX_BrokerNet_ASXDateBroker
            ON #BrokerNet (ASXCode, ObservationDate, BrokerName);

        SELECT n.ASXCode, n.ObservationDate,
               MAX(CASE WHEN n.rnBuy = 1 THEN n.BrokerName END) AS LeadAggressorBroker,
               MAX(CASE WHEN n.rnSell = 1 THEN n.BrokerName END) AS LeadDistributorBroker
        INTO #BrokerLeads
        FROM
        (
            SELECT n.ASXCode, n.ObservationDate, n.BrokerName,
                   ROW_NUMBER() OVER (PARTITION BY n.ASXCode, n.ObservationDate ORDER BY n.NetValue DESC, n.BrokerName) AS rnBuy,
                   ROW_NUMBER() OVER (PARTITION BY n.ASXCode, n.ObservationDate ORDER BY n.NetValue ASC, n.BrokerName) AS rnSell
            FROM #BrokerNet n
        ) n
        GROUP BY n.ASXCode, n.ObservationDate;

        CREATE CLUSTERED INDEX IX_BrokerLeads_ASXDate
            ON #BrokerLeads (ASXCode, ObservationDate);

        SELECT b.ASXCode, b.ObservationDate,
               CAST(SUM(POWER(CASE WHEN b.TotalBuyerValue > 0 THEN b.BuyValue / NULLIF(b.TotalBuyerValue, 0) ELSE 0 END, 2)) AS decimal(18,8)) AS BuyerHHI
        INTO #BuyerConcentration
        FROM
        (
            SELECT n.ASXCode, n.ObservationDate, n.BuyValue,
                   CAST(SUM(n.BuyValue) OVER (PARTITION BY n.ASXCode, n.ObservationDate) AS decimal(20,2)) AS TotalBuyerValue
            FROM #BrokerNet n
            WHERE n.BuyValue > 0
        ) b
        GROUP BY b.ASXCode, b.ObservationDate;

        CREATE CLUSTERED INDEX IX_BuyerConcentration_ASXDate
            ON #BuyerConcentration (ASXCode, ObservationDate);

        SELECT s.ASXCode, s.ObservationDate,
               CAST(SUM(POWER(CASE WHEN s.TotalSellerValue > 0 THEN s.SellValue / NULLIF(s.TotalSellerValue, 0) ELSE 0 END, 2)) AS decimal(18,8)) AS SellerHHI
        INTO #SellerConcentration
        FROM
        (
            SELECT n.ASXCode, n.ObservationDate, n.SellValue,
                   CAST(SUM(n.SellValue) OVER (PARTITION BY n.ASXCode, n.ObservationDate) AS decimal(20,2)) AS TotalSellerValue
            FROM #BrokerNet n
            WHERE n.SellValue > 0
        ) s
        GROUP BY s.ASXCode, s.ObservationDate;

        CREATE CLUSTERED INDEX IX_SellerConcentration_ASXDate
            ON #SellerConcentration (ASXCode, ObservationDate);

        ;WITH PriceCodeCandidates AS
        (
            SELECT c.ASXCode, c.ObservationDate, c.PriceASXCode, c.PriceASXCode AS LookupASXCode, 0 AS Pref
            FROM #CoverageScope c
            WHERE c.PriceASXCode IS NOT NULL

            UNION ALL

            SELECT c.ASXCode, c.ObservationDate, c.PriceASXCode, c.ASXCode AS LookupASXCode, 1 AS Pref
            FROM #CoverageScope c

            UNION ALL

            SELECT c.ASXCode, c.ObservationDate, c.PriceASXCode, c.ASXCode + '.AX' AS LookupASXCode, 2 AS Pref
            FROM #CoverageScope c
        ),
        PriceRefRanked AS
        (
            SELECT
                pc.ASXCode,
                pc.ObservationDate,
                CAST(p.[Open] AS decimal(20,8)) AS DayOpen,
                CAST(p.[Close] AS decimal(20,8)) AS DayClose,
                CAST(CASE WHEN p.Volume > 0 THEN ISNULL(p.[Value], 0) / CAST(p.Volume AS decimal(20,8)) END AS decimal(20,8)) AS DayVWAP,
                ROW_NUMBER() OVER (PARTITION BY pc.ASXCode, pc.ObservationDate ORDER BY pc.Pref) AS RN
            FROM PriceCodeCandidates pc
            INNER JOIN StockData.PriceHistory p
                ON p.ObservationDate = pc.ObservationDate
               AND p.ASXCode = pc.LookupASXCode
        )
        SELECT c.ASXCode, c.ObservationDate, px.DayOpen, px.DayClose, px.DayVWAP,
               CASE WHEN px.DayOpen IS NULL OR px.DayOpen <= 0 OR px.DayClose IS NULL THEN 1
                    WHEN ABS(px.DayClose - px.DayOpen) / px.DayOpen <= 0.003 THEN 1 ELSE 0 END AS IsDojiDay,
               CASE WHEN px.DayOpen IS NULL OR px.DayClose IS NULL THEN 0
                    WHEN ABS(px.DayClose - px.DayOpen) / NULLIF(px.DayOpen, 0) <= 0.003 THEN 0
                    WHEN px.DayClose > px.DayOpen THEN 1 ELSE 0 END AS IsGreenDay,
               CASE WHEN px.DayOpen IS NULL OR px.DayClose IS NULL THEN 0
                    WHEN ABS(px.DayClose - px.DayOpen) / NULLIF(px.DayOpen, 0) <= 0.003 THEN 0
                    WHEN px.DayClose < px.DayOpen THEN 1 ELSE 0 END AS IsRedDay
        INTO #PriceRef
        FROM #CoverageScope c
        LEFT JOIN
        (
            SELECT r.ASXCode, r.ObservationDate, r.DayOpen, r.DayClose, r.DayVWAP
            FROM PriceRefRanked r
            WHERE r.RN = 1
        ) px
          ON px.ASXCode = c.ASXCode
         AND px.ObservationDate = c.ObservationDate;

        CREATE CLUSTERED INDEX IX_PriceRef_ASXDate
            ON #PriceRef (ASXCode, ObservationDate);

        SELECT t.ASXCode, t.ObservationDate, t.Price, t.Value,
               CAST(ISNULL(buyerLkp.BrokerScore, 0) AS decimal(18,8)) AS BuyerBrokerScore,
               CAST(ISNULL(sellerLkp.BrokerScore, 0) AS decimal(18,8)) AS SellerBrokerScore,
               CAST(
                   CASE
                       WHEN 0.75 + (ABS(ISNULL(CAST(buyerLkp.BrokerScore AS float), 0.0)) + ABS(ISNULL(CAST(sellerLkp.BrokerScore AS float), 0.0))) / 4.0 > 1.60 THEN 1.60
                       WHEN 0.75 + (ABS(ISNULL(CAST(buyerLkp.BrokerScore AS float), 0.0)) + ABS(ISNULL(CAST(sellerLkp.BrokerScore AS float), 0.0))) / 4.0 < 0.75 THEN 0.75
                       ELSE 0.75 + (ABS(ISNULL(CAST(buyerLkp.BrokerScore AS float), 0.0)) + ABS(ISNULL(CAST(sellerLkp.BrokerScore AS float), 0.0))) / 4.0
                   END AS decimal(18,8)
               ) AS PairSignificanceWeight,
               CASE
                   WHEN LOWER(t.BuyerBrokerName) LIKE '%commsec%' OR LOWER(t.BuyerBrokerName) LIKE '%commonwealth securities%'
                     OR LOWER(t.BuyerBrokerName) LIKE '%wealthhub%' OR LOWER(t.BuyerBrokerName) LIKE '%webull%'
                     OR LOWER(t.BuyerBrokerName) LIKE '%cmc markets%' OR LOWER(t.BuyerBrokerName) LIKE '%selfwealth%'
                     OR LOWER(t.BuyerBrokerName) LIKE '%nabtrade%' OR LOWER(t.BuyerBrokerName) LIKE '%bell direct%'
                     OR LOWER(t.BuyerBrokerName) LIKE '%stake%' OR LOWER(t.BuyerBrokerName) LIKE '%pearler%' THEN 'retail'
                   WHEN buyerLkp.BrokerCode IS NULL THEN 'unknown' ELSE 'institutional'
               END AS BuyerCategory,
               CASE
                   WHEN LOWER(t.SellerBrokerName) LIKE '%commsec%' OR LOWER(t.SellerBrokerName) LIKE '%commonwealth securities%'
                     OR LOWER(t.SellerBrokerName) LIKE '%wealthhub%' OR LOWER(t.SellerBrokerName) LIKE '%webull%'
                     OR LOWER(t.SellerBrokerName) LIKE '%cmc markets%' OR LOWER(t.SellerBrokerName) LIKE '%selfwealth%'
                     OR LOWER(t.SellerBrokerName) LIKE '%nabtrade%' OR LOWER(t.SellerBrokerName) LIKE '%bell direct%'
                     OR LOWER(t.SellerBrokerName) LIKE '%stake%' OR LOWER(t.SellerBrokerName) LIKE '%pearler%' THEN 'retail'
                   WHEN sellerLkp.BrokerCode IS NULL THEN 'unknown' ELSE 'institutional'
               END AS SellerCategory,
               pr.DayVWAP
        INTO #TxClassified
        FROM #TxWindow t
        LEFT JOIN #PriceRef pr
            ON pr.ASXCode = t.ASXCode AND pr.ObservationDate = t.ObservationDate
        LEFT JOIN #BrokerLookupResolved buyerLkp
            ON buyerLkp.LookupName = UPPER(LTRIM(RTRIM(t.BuyerBrokerName)))
        LEFT JOIN #BrokerLookupResolved sellerLkp
            ON sellerLkp.LookupName = UPPER(LTRIM(RTRIM(t.SellerBrokerName)));

        CREATE CLUSTERED INDEX IX_TxClassified_ASXDate
            ON #TxClassified (ASXCode, ObservationDate);

        SELECT t.ASXCode, t.ObservationDate,
               CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'retail' THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS RetailToInstValue,
               CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'institutional' THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS InstToRetailValue,
               CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'retail' AND t.DayVWAP IS NOT NULL AND t.Price <= t.DayVWAP * 0.997 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS RetailToInstLowPxValue,
               CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'retail' AND t.DayVWAP IS NOT NULL AND t.Price >= t.DayVWAP * 1.003 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS RetailToInstHighPxValue,
               CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'institutional' AND t.DayVWAP IS NOT NULL AND t.Price >= t.DayVWAP * 1.003 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS InstToRetailHighPxValue,
               CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'institutional' AND t.DayVWAP IS NOT NULL AND t.Price <= t.DayVWAP * 0.997 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS InstToRetailLowPxValue
        INTO #RetailFlowAgg
        FROM #TxClassified t
        GROUP BY t.ASXCode, t.ObservationDate;

        CREATE CLUSTERED INDEX IX_RetailFlowAgg_ASXDate
            ON #RetailFlowAgg (ASXCode, ObservationDate);

        SELECT
            c.SnapshotDate,
            c.ASXCode,
            c.PriceASXCode,
            c.ObservationDate,
            c.CaptureSource,
            c.BullishSetupScore,
            c.BearishSetupScore,
            c.TransactionCount,
            c.DistinctBuyerCount,
            c.DistinctSellerCount,
            c.TotalValue,
            c.TotalVolume,
            ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0) AS NetFlowValue,
            CAST(CASE WHEN c.TotalValue > 0 THEN (ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue ELSE 0 END AS decimal(18,8)) AS NetFlowPctTotal,
            CAST(CASE WHEN c.TotalValue > 0 THEN ISNULL(c.TopBuyerValue, 0) / c.TotalValue ELSE 0 END AS decimal(18,8)) AS TopBuyerValueShare,
            CAST(CASE WHEN c.TotalValue > 0 THEN ISNULL(c.TopSellerValue, 0) / c.TotalValue ELSE 0 END AS decimal(18,8)) AS TopSellerValueShare,
            CAST(CASE WHEN c.TotalValue <= 0 THEN 0 ELSE PERCENT_RANK() OVER (PARTITION BY c.SnapshotDate ORDER BY CASE WHEN c.TotalValue <= 0 THEN 0 ELSE 0.70 * (ISNULL(c.TopBuyerValue, 0) / c.TotalValue) + 0.30 * ISNULL(bc.BuyerHHI, 0) END) END AS decimal(18,8)) AS BuyerAggressionScore,
            CAST(CASE WHEN c.TotalValue <= 0 THEN 0 ELSE PERCENT_RANK() OVER (PARTITION BY c.SnapshotDate ORDER BY CASE WHEN c.TotalValue <= 0 THEN 0 ELSE 0.70 * (ISNULL(c.TopSellerValue, 0) / c.TotalValue) + 0.30 * ISNULL(sc.SellerHHI, 0) END) END AS decimal(18,8)) AS SellerAggressionScore,
            CAST(
                  0.45 * CASE
                             WHEN c.TotalValue <= 0 THEN 0
                             ELSE
                                 (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                 * CASE
                                       WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                       ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                   END
                         END
                + 0.35 * CASE
                             WHEN c.TotalValue <= 0 THEN 0
                             ELSE
                                 (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                 * CASE
                                       WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                       ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                   END
                         END
                + 0.20 * CASE
                             WHEN c.TotalValue <= 0 THEN 0
                             WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                             ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                         END
                AS decimal(18,8)
            ) AS AbsorptionScore,
            CAST(
                CASE
                    WHEN c.TotalValue <= 0 THEN 0
                    WHEN (ISNULL(rf.RetailToInstValue, 0) + ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue >= 0.60 THEN 1.0
                    ELSE ((ISNULL(rf.RetailToInstValue, 0) + ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue) / 0.60
                END AS decimal(18,8)
            ) AS TransferScore,
            CAST(
                (
                    CASE
                        WHEN c.TransactionCount >= 4000 THEN 1.0
                        ELSE CAST(c.TransactionCount AS float) / 4000.0
                    END
                )
                * (
                    CASE
                        WHEN c.DistinctBuyerCount <= 0 OR c.DistinctSellerCount <= 0 THEN 0
                        WHEN c.DistinctBuyerCount <= c.DistinctSellerCount THEN CAST(c.DistinctBuyerCount AS float) / NULLIF(c.DistinctSellerCount, 0)
                        ELSE CAST(c.DistinctSellerCount AS float) / NULLIF(c.DistinctBuyerCount, 0)
                    END
                ) AS decimal(18,8)
            ) AS ChurnScore,
            CAST(
                  0.65 * (
                             0.45 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.35 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.20 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                        ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                                    END
                        )
                + 0.35 * (
                             1.0 - (
                                 0.45 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            ELSE
                                                (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                                * CASE
                                                      WHEN ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                      ELSE (ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue) / 0.20
                                                  END
                                        END
                               + 0.35 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            ELSE
                                                (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                                * CASE
                                                      WHEN ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                      ELSE (ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue) / 0.20
                                                  END
                                        END
                               + 0.20 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            WHEN ISNULL(rf.InstToRetailValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                            ELSE (ISNULL(rf.InstToRetailValue, 0) / c.TotalValue) / 0.35
                                        END
                             )
                        )
                AS decimal(18,8)
            ) AS SuppressionReacquisitionScore,
            CAST(
                  0.50 * (
                             0.45 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.35 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.20 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        WHEN ISNULL(rf.InstToRetailValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                        ELSE (ISNULL(rf.InstToRetailValue, 0) / c.TotalValue) / 0.35
                                    END
                        )
                + 0.30 * (
                             1.0 - (
                                 0.45 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            ELSE
                                                (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                                * CASE
                                                      WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                      ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                                  END
                                        END
                               + 0.35 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            ELSE
                                                (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                                * CASE
                                                      WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                      ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                                  END
                                        END
                               + 0.20 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                            ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                                        END
                             )
                        )
                + 0.20 * CASE
                             WHEN c.TotalValue <= 0 THEN 0
                             WHEN (ISNULL(rf.InstToRetailValue, 0) - ISNULL(rf.RetailToInstValue, 0)) / c.TotalValue <= 0 THEN 0
                             WHEN (ISNULL(rf.InstToRetailValue, 0) - ISNULL(rf.RetailToInstValue, 0)) / c.TotalValue >= 0.15 THEN 1.0
                             ELSE ((ISNULL(rf.InstToRetailValue, 0) - ISNULL(rf.RetailToInstValue, 0)) / c.TotalValue) / 0.15
                         END
                AS decimal(18,8)
            ) AS LiveDistributionScore,
            CAST(
                  0.50 * (
                             0.45 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.35 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.20 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                        ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                                    END
                        )
                + 0.30 * (
                             1.0 - (
                                 0.45 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            ELSE
                                                (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                                * CASE
                                                      WHEN ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                      ELSE (ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue) / 0.20
                                                  END
                                        END
                               + 0.35 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            ELSE
                                                (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                                * CASE
                                                      WHEN ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                      ELSE (ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue) / 0.20
                                                  END
                                        END
                               + 0.20 * CASE
                                            WHEN c.TotalValue <= 0 THEN 0
                                            WHEN ISNULL(rf.InstToRetailValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                            ELSE (ISNULL(rf.InstToRetailValue, 0) / c.TotalValue) / 0.35
                                        END
                             )
                        )
                + 0.20 * CASE
                             WHEN c.TotalValue <= 0 THEN 0
                             WHEN (ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue <= 0 THEN 0
                             WHEN (ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue >= 0.15 THEN 1.0
                             ELSE ((ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue) / 0.15
                         END
                AS decimal(18,8)
            ) AS LiveExecutionQualityScore,
            l.LeadAggressorBroker,
            l.LeadDistributorBroker
        INTO #MicroBase
        FROM #CoverageScope c
        LEFT JOIN #RetailFlowAgg rf ON rf.ASXCode = c.ASXCode AND rf.ObservationDate = c.ObservationDate
        LEFT JOIN #PriceRef pr ON pr.ASXCode = c.ASXCode AND pr.ObservationDate = c.ObservationDate
        LEFT JOIN #BuyerConcentration bc ON bc.ASXCode = c.ASXCode AND bc.ObservationDate = c.ObservationDate
        LEFT JOIN #SellerConcentration sc ON sc.ASXCode = c.ASXCode AND sc.ObservationDate = c.ObservationDate
        LEFT JOIN #BrokerLeads l ON l.ASXCode = c.ASXCode AND l.ObservationDate = c.ObservationDate;

        DELETE m
        FROM Transform.BrokerTxMicrostructureDay m
        INNER JOIN #Candidates c
            ON c.ASXCode = m.ASXCode
        WHERE m.SnapshotDate = @vAsOfDate
          AND m.ObservationDate >= @vWindowStartDate
          AND m.ObservationDate <= @vAsOfDate;

        INSERT INTO Transform.BrokerTxMicrostructureDay
        (
            SnapshotDate, ASXCode, PriceASXCode, ObservationDate,
            CaptureSource, BullishSetupScore, BearishSetupScore,
            TransactionCount, DistinctBuyerCount, DistinctSellerCount, TotalValue, TotalVolume,
            NetFlowValue, NetFlowPctTotal, TopBuyerValueShare, TopSellerValueShare,
            BuyerAggressionScore, SellerAggressionScore, AbsorptionScore, TransferScore, ChurnScore,
            SuppressionReacquisitionScore, LiveDistributionScore, LiveExecutionQualityScore,
            LeadAggressorBroker, LeadDistributorBroker, ScoreVersion, CreatedDate
        )
        SELECT
            SnapshotDate, ASXCode, PriceASXCode, ObservationDate,
            CaptureSource, BullishSetupScore, BearishSetupScore,
            TransactionCount, DistinctBuyerCount, DistinctSellerCount, TotalValue, TotalVolume,
            NetFlowValue, NetFlowPctTotal, TopBuyerValueShare, TopSellerValueShare,
            BuyerAggressionScore, SellerAggressionScore, AbsorptionScore, TransferScore, ChurnScore,
            SuppressionReacquisitionScore, LiveDistributionScore, LiveExecutionQualityScore,
            LeadAggressorBroker, LeadDistributorBroker, @vScoreVersionPhase3, SYSUTCDATETIME()
        FROM #MicroBase;
    END;

    UPDATE u
    SET
        u.LastEvaluatedDate = @vAsOfDate,
        u.ModifiedDate = SYSUTCDATETIME()
    FROM Transform.BrokerTxCaptureUniverse u
    INNER JOIN #Candidates c
        ON c.ASXCode = u.ASXCode;

    UPDATE r
    SET
        r.ArchivedRowCount = CASE WHEN @pPersistArchive = 1 THEN (SELECT COUNT(*) FROM #TxBase) ELSE 0 END,
        r.CoverageRowCount = (SELECT COUNT(*) FROM #CoverageAgg)
    FROM Transform.BrokerTxCaptureRun r
    WHERE r.BrokerTxCaptureRunID = @vCaptureRunID;
END
