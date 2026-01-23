-- Stored procedure: [Transform].[usp_CalculateBreakoutWatchlist]

-- =============================================
-- Updated Stored Procedure: Calculate Breakout Watchlist with BreakoutDate
-- =============================================
-- This version populates the BreakoutDate column
-- For FRESH BREAKOUT: BreakoutDate = ObservationDate
-- For CONSOLIDATION: BreakoutDate = actual breakout date (2-4 days ago)
-- =============================================


CREATE PROCEDURE Transform.usp_CalculateBreakoutWatchlist
    @ObservationDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Fixed thresholds
    DECLARE @MinTurnover DECIMAL(18, 2) = 500000;
    DECLARE @MinPctGain DECIMAL(10, 2) = 8.0;
    DECLARE @MaxPrice DECIMAL(10, 4) = 5.00;
    DECLARE @MaxDay2IncreasePct DECIMAL(10, 2) = 20.0;

    -- Delete existing results for this date
    DELETE FROM StockDB.Transform.BreakoutWatchlist
    WHERE ObservationDate = @ObservationDate;

    -- Create temp table for better performance
    CREATE TABLE #TodayCandidates (
        ASXCode VARCHAR(20) PRIMARY KEY
    );

    -- Step 1: Get candidates (stocks <= $5 on observation date)
    INSERT INTO #TodayCandidates (ASXCode)
    SELECT DISTINCT a.ASXCode
    FROM StockDB.[Transform].[PriceHistory] AS a WITH (NOLOCK)
    WHERE a.ObservationDate = @ObservationDate
      AND a.[Close] <= @MaxPrice
      AND a.[Close] IS NOT NULL
      AND a.[Value] >= 10000;

    -- Create temp table for ranked data
    CREATE TABLE #RankedData (
        ASXCode VARCHAR(20),
        ObservationDate DATE,
        [Open] DECIMAL(10, 4),
        [Close] DECIMAL(10, 4),
        [High] DECIMAL(10, 4),
        [Low] DECIMAL(10, 4),
        [Value] DECIMAL(18, 2),
        PriceChangeVsPrevClose DECIMAL(10, 4),
        TomorrowChange DECIMAL(10, 2),
        Next2DaysChange DECIMAL(10, 2),
        Next5DaysChange DECIMAL(10, 2),
        Next10DaysChange DECIMAL(10, 2),
        rn INT,
        INDEX IX_ASXCode_rn (ASXCode, rn)
    );

    -- Step 2: Get last 25 trading days for each candidate
    INSERT INTO #RankedData
    SELECT
        a.ASXCode,
        a.ObservationDate,
        a.[Open],
        a.[Close],
        a.[High],
        a.[Low],
        a.[Value],
        a.PriceChangeVsPrevClose,
        b.TomorrowChange,
        b.Next2DaysChange,
        b.Next5DaysChange,
        b.Next10DaysChange,
        ROW_NUMBER() OVER(PARTITION BY a.ASXCode ORDER BY a.ObservationDate DESC) as rn
    FROM StockDB.[Transform].[PriceHistory] as a WITH (NOLOCK)
    LEFT JOIN StockDB.[Transform].[PriceHistory24Month] as b WITH (NOLOCK)
        ON a.ASXCode = b.ASXCode
        AND a.ObservationDate = b.ObservationDate
    INNER JOIN #TodayCandidates tc
        ON tc.ASXCode = a.ASXCode
    WHERE a.ObservationDate <= @ObservationDate
      AND a.ObservationDate >= DATEADD(DAY, -60, @ObservationDate);

    -- Delete rows beyond 25 per stock
    DELETE FROM #RankedData WHERE rn > 25;

    -- Step 3: Calculate 20-day average volume
    CREATE TABLE #VolumeAverage (
        ASXCode VARCHAR(20) PRIMARY KEY,
        AvgVolume20d DECIMAL(18, 2)
    );

    INSERT INTO #VolumeAverage
    SELECT
        ASXCode,
        AVG([Value]) AS AvgVolume20d
    FROM #RankedData
    WHERE rn <= 20
      AND [Value] IS NOT NULL
    GROUP BY ASXCode
    HAVING COUNT(*) >= 10;

    -- Step 4: Create stock data with volume average
    CREATE TABLE #StockData (
        ASXCode VARCHAR(20),
        ObservationDate DATE,
        [Open] DECIMAL(10, 4),
        [Close] DECIMAL(10, 4),
        [High] DECIMAL(10, 4),
        [Low] DECIMAL(10, 4),
        [Value] DECIMAL(18, 2),
        TomorrowChange DECIMAL(10, 2),
        Next2DaysChange DECIMAL(10, 2),
        Next5DaysChange DECIMAL(10, 2),
        Next10DaysChange DECIMAL(10, 2),
        rn INT,
        AvgVolume20d DECIMAL(18, 2),
        INDEX IX_ASXCode_rn (ASXCode, rn)
    );

    INSERT INTO #StockData
    SELECT
        r.ASXCode,
        r.ObservationDate,
        r.[Open],
        r.[Close],
        r.[High],
        r.[Low],
        r.[Value],
        r.TomorrowChange,
        r.Next2DaysChange,
        r.Next5DaysChange,
        r.Next10DaysChange,
        r.rn,
        v.AvgVolume20d
    FROM #RankedData r
    INNER JOIN #VolumeAverage v ON r.ASXCode = v.ASXCode
    WHERE r.rn <= 25;

    -- Step 5: FRESH BREAKOUT Pattern
    INSERT INTO StockDB.Transform.BreakoutWatchlist (
        ObservationDate,
        ASXCode,
        Pattern,
        Price,
        ChangePercent,
        VolumeValue,
        VolumeRatio,
        Note,
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange,
        BreakoutDate
    )
    SELECT
        @ObservationDate,
        t0.ASXCode,
        'FRESH BREAKOUT',
        ROUND(t0.[Close], 3),
        ROUND(((t0.[Close] - t1.[Close]) / t1.[Close] * 100), 2),
        t0.[Value],
        ROUND((t0.[Value] / t0.AvgVolume20d), 2),
        '',
        t0.TomorrowChange,
        t0.Next2DaysChange,
        t0.Next5DaysChange,
        t0.Next10DaysChange,
        @ObservationDate  -- For fresh breakout, breakout date = observation date
    FROM #StockData t0
    INNER JOIN #StockData t1 ON t0.ASXCode = t1.ASXCode AND t1.rn = 2
    WHERE t0.rn = 1
      AND t0.[Value] IS NOT NULL
      AND t0.[Close] IS NOT NULL
      AND t1.[Close] IS NOT NULL
      AND t1.[Close] > 0
      AND ((t0.[Close] - t1.[Close]) / t1.[Close] * 100) >= @MinPctGain
      AND (t0.[Value] / t0.AvgVolume20d) >= 2.0
      AND t0.[Value] >= @MinTurnover;

    -- Step 6: CONSOLIDATION Pattern
    -- First, find valid breakout days
    CREATE TABLE #BreakoutDays (
        ASXCode VARCHAR(20),
        BreakoutRN INT,
        BreakoutDate DATE,
        BreakoutClose DECIMAL(10, 4),
        BreakoutOpen DECIMAL(10, 4),
        BreakoutHigh DECIMAL(10, 4),
        BreakoutLow DECIMAL(10, 4),
        BreakoutValue DECIMAL(18, 2),
        BreakoutGain DECIMAL(10, 2),
        BreakoutVolRatio DECIMAL(10, 2),
        BreakoutMidPrice DECIMAL(10, 4),
        MaxConsolidationClose DECIMAL(10, 4),
        INDEX IX_ASXCode (ASXCode)
    );

    INSERT INTO #BreakoutDays
    SELECT
        t_breakout.ASXCode,
        t_breakout.rn AS BreakoutRN,
        t_breakout.ObservationDate AS BreakoutDate,
        t_breakout.[Close] AS BreakoutClose,
        t_breakout.[Open] AS BreakoutOpen,
        t_breakout.[High] AS BreakoutHigh,
        t_breakout.[Low] AS BreakoutLow,
        t_breakout.[Value] AS BreakoutValue,
        ((t_breakout.[Close] - t_prior.[Close]) / t_prior.[Close] * 100) AS BreakoutGain,
        (t_breakout.[Value] / t_breakout.AvgVolume20d) AS BreakoutVolRatio,
        CASE
            WHEN t_breakout.[High] IS NOT NULL AND t_breakout.[Low] IS NOT NULL
            THEN (t_breakout.[High] + t_breakout.[Low]) / 2
            ELSE t_breakout.[Close]
        END AS BreakoutMidPrice,
        CASE
            WHEN t_breakout.[Open] IS NOT NULL AND t_breakout.[Close] IS NOT NULL
            THEN t_breakout.[Close] + ((t_breakout.[Close] - t_breakout.[Open]) / 2)
            ELSE t_breakout.[Close] * 1.05
        END AS MaxConsolidationClose
    FROM #StockData t_breakout
    INNER JOIN #StockData t_prior ON t_breakout.ASXCode = t_prior.ASXCode AND t_prior.rn = t_breakout.rn + 1
    WHERE t_breakout.rn BETWEEN 2 AND 4
      AND t_breakout.[Value] IS NOT NULL
      AND t_breakout.[Close] IS NOT NULL
      AND t_prior.[Close] IS NOT NULL
      AND t_prior.[Close] > 0
      AND t_breakout.[Value] >= @MinTurnover
      AND ((t_breakout.[Close] - t_prior.[Close]) / t_prior.[Close] * 100) >= @MinPctGain
      AND (t_breakout.[Value] / t_breakout.AvgVolume20d) >= 2.0;

    -- Validate consolidation patterns and insert
    INSERT INTO StockDB.Transform.BreakoutWatchlist (
        ObservationDate,
        ASXCode,
        Pattern,
        Price,
        ChangePercent,
        VolumeValue,
        VolumeRatio,
        Note,
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange,
        BreakoutDate
    )
    SELECT
        @ObservationDate,
        bd.ASXCode,
        'CONSOLIDATION',
        ROUND(t0.[Close], 3),
        ROUND(CASE WHEN t1.[Close] > 0 THEN ((t0.[Close] - t1.[Close]) / t1.[Close] * 100) ELSE 0 END, 2),
        t0.[Value],
        ROUND(bd.BreakoutVolRatio, 2),
        'Ran ' + CAST(ROUND(bd.BreakoutGain, 1) AS VARCHAR(20)) + '% on ' +
            CONVERT(VARCHAR(10), bd.BreakoutDate, 120) + ' (' + CAST(bd.BreakoutRN - 1 AS VARCHAR(10)) + 'd ago)',
        t0.TomorrowChange,
        t0.Next2DaysChange,
        t0.Next5DaysChange,
        t0.Next10DaysChange,
        bd.BreakoutDate  -- Use the actual breakout date (2-4 days ago)
    FROM #BreakoutDays bd
    INNER JOIN #StockData t0 ON bd.ASXCode = t0.ASXCode AND t0.rn = 1
    LEFT JOIN #StockData t1 ON bd.ASXCode = t1.ASXCode AND t1.rn = 2
    LEFT JOIN #StockData t2 ON bd.ASXCode = t2.ASXCode AND t2.rn = 3
    WHERE t0.[Value] >= 10000
      AND t0.[Close] >= bd.BreakoutMidPrice
      AND t0.[Close] <= bd.MaxConsolidationClose
      AND bd.BreakoutRN >= 3
      AND DATEDIFF(DAY, bd.BreakoutDate, t0.ObservationDate) <= 10
      AND (
          -- Validate volume pattern based on breakout position
          (bd.BreakoutRN = 2 AND t0.[Value] < bd.BreakoutValue)
          OR
          (bd.BreakoutRN = 3 AND (
              (t1.[Value] < bd.BreakoutValue * 0.5 AND t0.[Value] < bd.BreakoutValue * 0.5 AND t0.[Value] <= t1.[Value] * (1 + @MaxDay2IncreasePct / 100))
              OR
              (t0.[Value] < t1.[Value] AND t1.[Value] < bd.BreakoutValue)
          ))
          OR
          (bd.BreakoutRN = 4 AND (
              (t2.[Value] < bd.BreakoutValue * 0.5 AND t1.[Value] < bd.BreakoutValue * 0.5 AND t1.[Value] <= t2.[Value] * (1 + @MaxDay2IncreasePct / 100) AND t0.[Value] < t1.[Value])
              OR
              (t0.[Value] < t1.[Value] AND t1.[Value] < t2.[Value] AND t2.[Value] < bd.BreakoutValue)
          ))
      );

    -- Clean up temp tables
    DROP TABLE #TodayCandidates;
    DROP TABLE #RankedData;
    DROP TABLE #VolumeAverage;
    DROP TABLE #StockData;
    DROP TABLE #BreakoutDays;

    -- Return count
    SELECT
        COUNT(*) AS TotalCandidates,
        SUM(CASE WHEN Pattern = 'FRESH BREAKOUT' THEN 1 ELSE 0 END) AS FreshBreakouts,
        SUM(CASE WHEN Pattern = 'CONSOLIDATION' THEN 1 ELSE 0 END) AS Consolidations
    FROM StockDB.Transform.BreakoutWatchlist
    WHERE ObservationDate = @ObservationDate;

END;
