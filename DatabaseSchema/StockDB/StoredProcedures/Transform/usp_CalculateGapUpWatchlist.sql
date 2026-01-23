-- Stored procedure: [Transform].[usp_CalculateGapUpWatchlist]

-- =============================================
-- Stored Procedure: Calculate Gap Up Watchlist
-- =============================================
-- This procedure implements the gap up pattern detection logic
-- Fixed Parameters:
--   GAP_PCT = 6.0
--   VOLUME_MULTIPLIER = 5.0
--   MIN_VOLUME_VALUE = 600000
--   MIN_PRICE = 0.02
--   CLOSE_LOCATION = 0.5
-- =============================================


create PROCEDURE Transform.usp_CalculateGapUpWatchlist
    @ObservationDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Fixed thresholds
    DECLARE @GapPct DECIMAL(10, 2) = 6.0;
    DECLARE @VolumeMultiplier DECIMAL(10, 2) = 5.0;
    DECLARE @MinVolumeValue DECIMAL(18, 2) = 600000;
    DECLARE @MinPrice DECIMAL(10, 4) = 0.02;
    DECLARE @CloseLocation DECIMAL(10, 4) = 0.5;

    -- Delete existing results for this date
    DELETE FROM StockDB.Transform.GapUpWatchlist
    WHERE ObservationDate = @ObservationDate;

    -- Step 1: Get candidates (stocks with some volume on observation date)
    WITH TodayCandidates AS (
        SELECT a.ASXCode
        FROM StockDB.[Transform].[PriceHistory] AS a
        WHERE a.ObservationDate = @ObservationDate
          AND a.[Value] >= 10000
          AND a.[Close] IS NOT NULL
    ),
    -- Step 2: Get last 65 trading days for each candidate
    RankedData AS (
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
        FROM StockDB.[Transform].[PriceHistory] as a
        LEFT JOIN StockDB.[Transform].[PriceHistory24Month] as b
            ON a.ASXCode = b.ASXCode
            AND a.ObservationDate = b.ObservationDate
        INNER JOIN TodayCandidates tc
            ON tc.ASXCode = a.ASXCode
        WHERE a.ObservationDate <= @ObservationDate
    ),
    -- Step 3: Calculate 20-day average volume
    VolumeAverage AS (
        SELECT
            ASXCode,
            AVG([Value]) AS AvgVolume20d
        FROM RankedData
        WHERE rn <= 21
          AND [Value] IS NOT NULL
        GROUP BY ASXCode
        HAVING COUNT(*) >= 10  -- Need at least 10 days
    ),
    -- Step 4: Get 60-day high close for each stock
    HighOf60Days AS (
        SELECT
            ASXCode,
            MAX([Close]) AS MaxClose60d
        FROM RankedData
        WHERE rn BETWEEN 2 AND 61  -- Exclude today (rn=1)
          AND [Close] IS NOT NULL
        GROUP BY ASXCode
    ),
    -- Step 5: Analyze gap up patterns
    GapUpCandidates AS (
        SELECT
            t0.ASXCode,
            t0.[Close] AS Price,
            t0.[Open],
            t0.[High],
            t0.[Low],
            t0.[Value] AS VolumeValue,
            t1.[High] AS YesterdayHigh,
            v.AvgVolume20d,
            h.MaxClose60d,
            t0.TomorrowChange,
            t0.Next2DaysChange,
            t0.Next5DaysChange,
            t0.Next10DaysChange,
            t0.ObservationDate,
            -- Calculate gap percentage: (today's low - yesterday's high) / yesterday's high * 100
            CASE
                WHEN t1.[High] > 0 THEN ((t0.[Low] - t1.[High]) / t1.[High] * 100)
                ELSE 0
            END AS GapUpPercent,
            -- Calculate volume ratio
            CASE
                WHEN v.AvgVolume20d > 0 THEN (t0.[Value] / v.AvgVolume20d)
                ELSE 0
            END AS VolumeRatio,
            -- Calculate close location: (close - low) / (high - low)
            CASE
                WHEN t0.[High] > t0.[Low] THEN ((t0.[Close] - t0.[Low]) / (t0.[High] - t0.[Low]))
                ELSE 0
            END AS CloseLocation,
            -- Calculate price change percent: (close - open) / open * 100
            CASE
                WHEN t0.[Open] > 0 THEN ((t0.[Close] - t0.[Open]) / t0.[Open] * 100)
                ELSE 0
            END AS ChangePercent
        FROM RankedData t0
        INNER JOIN RankedData t1 ON t0.ASXCode = t1.ASXCode AND t1.rn = 2  -- Yesterday
        INNER JOIN VolumeAverage v ON t0.ASXCode = v.ASXCode
        INNER JOIN HighOf60Days h ON t0.ASXCode = h.ASXCode
        WHERE t0.rn = 1  -- Today
          AND t0.[Close] IS NOT NULL
          AND t0.[Low] IS NOT NULL
          AND t0.[High] IS NOT NULL
          AND t0.[Open] IS NOT NULL
          AND t0.[Value] IS NOT NULL
          AND t1.[High] IS NOT NULL
    )
    -- Insert results (only those meeting ALL conditions)
    INSERT INTO StockDB.Transform.GapUpWatchlist (
        ObservationDate,
        ASXCode,
        Price,
        ChangePercent,
        GapUpPercent,
        VolumeValue,
        VolumeRatio,
        CloseLocation,
        HighOf60Days,
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange
    )
    SELECT
        @ObservationDate,
        ASXCode,
        ROUND(Price, 3),
        ROUND(ChangePercent, 2),
        ROUND(GapUpPercent, 2),
        VolumeValue,
        ROUND(VolumeRatio, 2),
        CloseLocation,
        ROUND(MaxClose60d, 3),
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange
    FROM GapUpCandidates
    WHERE Price > @MinPrice                           -- Condition 6: Price above minimum
      AND GapUpPercent >= @GapPct                     -- Condition 1: Gap up >= 6%
      AND VolumeValue >= @MinVolumeValue              -- Condition 2a: Volume >= $600K
      AND VolumeRatio >= @VolumeMultiplier            -- Condition 2b: Volume >= 5x average
      AND CloseLocation > @CloseLocation              -- Condition 3: Close location > 0.5
      AND Price > [Open]                              -- Condition 4: Close > Open (bullish)
      AND Price > MaxClose60d                         -- Condition 5: Close > 60-day high
    ORDER BY GapUpPercent DESC;

    -- Return count
    SELECT COUNT(*) AS TotalCandidates
    FROM StockDB.Transform.GapUpWatchlist
    WHERE ObservationDate = @ObservationDate;

END;
