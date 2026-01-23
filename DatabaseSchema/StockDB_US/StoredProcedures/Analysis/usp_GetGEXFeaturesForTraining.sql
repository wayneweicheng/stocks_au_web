-- Stored procedure: [Analysis].[usp_GetGEXFeaturesForTraining]


CREATE   PROCEDURE Analysis.usp_GetGEXFeaturesForTraining
    @ASXCode NVARCHAR(20),
    @ObservationDateFrom DATE,
    @ObservationDateTo DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Add 60-day buffer for rolling window calculations
    DECLARE @LookbackDate DATE = DATEADD(DAY, -60, @ObservationDateFrom);

    -- =============================================
    -- STEP 1: Fetch base training data with extended lookback
    -- =============================================
    WITH BaseData AS (
        SELECT
            dr.ObservationDate,
            dr.ASXCode,
            -- GEX fields (formatted strings, need parsing)
            gex.FormattedGEX,
            gex.FormattedPrev1GEX,
            gex.GEXChange,
            gex.SwingIndicator,
            gex.PotentialSwingIndicator,
            -- Capital type GEX percentages
            bc_curr.GEXDeltaPerc as BuyCall_GEXDeltaPerc,
            bp_curr.GEXDeltaPerc as BuyPut_GEXDeltaPerc,
            sc_curr.GEXDeltaPerc as SellCall_GEXDeltaPerc,
            sp_curr.GEXDeltaPerc as SellPut_GEXDeltaPerc,
            -- Market data
            btc.[Close] as BTC,
            vix.[Close] as VIX,
            gold.[Close] as Gold,
            nasdaq.[Close] as NASDAQ,
            -- Darkpool sentiment
            dp.BuyRatio as Stock_DarkPoolBuySellRatio,
            dp.DPIndex as Stock_DarkPoolIndex,
            dp_svix.BuyRatio as SVix_DarkPoolBuyRatio,
            dp_svix.DPIndex as SVix_DarkPoolIndex,
            -- Price data
            bc_curr.[Close],
            ph.TodayChange,
            ph.TomorrowChange,
            ph.Next2DaysChange,
            ph.Next5DaysChange,
            ph.Next10DaysChange,
            ph.Next20DaysChange,
            ph.Prev2DaysChange,
            ph.Prev10DaysChange,
            -- Calculate RSI (14-period) inline for Golden Setup
            -- Using simplified RSI calculation
            AVG(CASE WHEN ph.TodayChange > 0 THEN ph.TodayChange ELSE 0 END)
                OVER (PARTITION BY dr.ASXCode ORDER BY dr.ObservationDate ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as RSI_Gain,
            AVG(CASE WHEN ph.TodayChange < 0 THEN ABS(ph.TodayChange) ELSE 0 END)
                OVER (PARTITION BY dr.ASXCode ORDER BY dr.ObservationDate ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as RSI_Loss
        FROM (
            -- Date range with lookback buffer
            SELECT DISTINCT
                ObservationDate,
                ASXCode
            FROM StockDB_US.Transform.v_OptionGexChangeCapitalType
            WHERE ASXCode = @ASXCode
            AND ObservationDate >= @LookbackDate
            AND ObservationDate <= @ObservationDateTo
            AND CapitalType = 'BC'
        ) dr
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType bc_curr
            ON dr.ASXCode = bc_curr.ASXCode
            AND dr.ObservationDate = bc_curr.ObservationDate
            AND bc_curr.CapitalType = 'BC'
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType bp_curr
            ON dr.ASXCode = bp_curr.ASXCode
            AND dr.ObservationDate = bp_curr.ObservationDate
            AND bp_curr.CapitalType = 'BP'
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType sc_curr
            ON dr.ASXCode = sc_curr.ASXCode
            AND dr.ObservationDate = sc_curr.ObservationDate
            AND sc_curr.CapitalType = 'SC'
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType sp_curr
            ON dr.ASXCode = sp_curr.ASXCode
            AND dr.ObservationDate = sp_curr.ObservationDate
            AND sp_curr.CapitalType = 'SP'
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] ph
            ON dr.ASXCode = ph.ASXCode
            AND dr.ObservationDate = ph.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] btc
            ON btc.ASXCode = 'BTC'
            AND dr.ObservationDate = btc.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] vix
            ON vix.ASXCode = '_VIX.US'
            AND dr.ObservationDate = vix.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] gold
            ON gold.ASXCode = 'GOLD'
            AND dr.ObservationDate = gold.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] nasdaq
            ON nasdaq.ASXCode = 'NASDAQ'
            AND dr.ObservationDate = nasdaq.ObservationDate
        LEFT JOIN (
            SELECT Symbol+'.US' as ASXCode, ObservationDate, ShortExemptVolume, Bought, Sold, BuyRatio, DPIndex
            FROM StockDB.StockData.v_FinraDIX_Norm_All
        ) as dp
            ON CASE WHEN dr.ASXCode = 'SPXW.US' THEN 'SPY.US' ELSE dr.ASXCode END = dp.ASXCode
            AND dr.ObservationDate = dp.ObservationDate
        LEFT JOIN (
            SELECT Symbol+'.US' as ASXCode, ObservationDate, ShortExemptVolume, Bought, Sold, BuyRatio, DPIndex
            FROM StockDB.StockData.v_FinraDIX_Norm_All
            WHERE Symbol = 'svix'
        ) as dp_svix
            ON dr.ObservationDate = dp_svix.ObservationDate
        LEFT JOIN (
            SELECT ASXCode, ObservationDate, NoOfOption, GEX, FormattedGEX, [Close],
                   Prev1Close, Prev2Close, FormattedPrev1GEX, SwingIndicator, PotentialSwingIndicator,
                   GEXChange, ClosePriceChange
            FROM StockDB_US.StockData.v_CalculatedGEXPlus_V2
            WHERE ASXCode IS NOT NULL
        ) as gex
            ON dr.ObservationDate = gex.ObservationDate
            AND dr.ASXCode = gex.ASXCode
        WHERE bc_curr.GEXDeltaPerc IS NOT NULL
    ),

    -- =============================================
    -- STEP 2: Parse GEX and calculate core features
    -- =============================================
    ParsedGEX AS (
        SELECT
            *,
            -- Parse formatted GEX strings to numeric
            CAST(REPLACE(FormattedGEX, ',', '') AS FLOAT) as GEX,
            CAST(REPLACE(FormattedPrev1GEX, ',', '') AS FLOAT) as Prev1GEX,
            -- Calculate RSI from gains/losses
            100 - (100.0 / (1 + NULLIF(RSI_Gain, 0) / NULLIF(RSI_Loss, 0.001))) as RSI
        FROM BaseData
    ),

    -- =============================================
    -- STEP 3: Calculate statistical features (Z-scores, percentiles, SMAs)
    -- =============================================
    StatisticalFeatures AS (
        SELECT
            *,
            -- GEX 20-day statistics
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_Mean20,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_Std20,

            -- GEX 60-day statistics
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Mean60,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Std60,

            -- GEX Moving Averages
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) as GEX_SMA5,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as GEX_SMA10,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_SMA20,

            -- GEX Volatility (10-day rolling std)
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as GEX_Volatility,

            -- Previous day GEX for transitions
            LAG(GEX, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as GEX_Lag1,

            -- GEX Min/Max for 60-day window (for percentile calculation)
            MIN(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Min60,
            MAX(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Max60
        FROM ParsedGEX
    ),

    -- =============================================
    -- STEP 4: Calculate derived features (Z-scores, regime flags, transitions)
    -- =============================================
    DerivedFeatures AS (
        SELECT
            *,
            -- GEX Z-Scores
            (GEX - GEX_Mean20) / NULLIF(GEX_Std20, 0.001) as GEX_ZScore,
            (GEX - GEX_Mean60) / NULLIF(GEX_Std60, 0.001) as GEX_ZScore_60day,

            -- GEX Percentile (manual calculation using min-max normalization for 60-day window)
            CASE
                WHEN GEX_Max60 = GEX_Min60 THEN 50.0  -- If no variance, return middle
                ELSE ((GEX - GEX_Min60) / NULLIF(GEX_Max60 - GEX_Min60, 0.001)) * 100.0
            END as GEX_Percentile,

            -- GEX Day-over-Day Changes
            GEX - Prev1GEX as GEX_DayChange,
            ((GEX - Prev1GEX) / NULLIF(ABS(Prev1GEX), 1.0)) * 100 as GEX_PctChange,

            -- Previous day Z-score for transition detection
            (LAG(GEX, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) - LAG(GEX_Mean20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate))
                / NULLIF(LAG(GEX_Std20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate), 0.001) as Prev_GEX_ZScore,

            -- Volatility percentile using min-max for regime detection
            -- Calculate min/max volatility inline
            (GEX_Volatility - MIN(GEX_Volatility) OVER (PARTITION BY ASXCode))
                / NULLIF(MAX(GEX_Volatility) OVER (PARTITION BY ASXCode) - MIN(GEX_Volatility) OVER (PARTITION BY ASXCode), 0.001) as GEX_Vol_Percentile
        FROM StatisticalFeatures
    )

    -- =============================================
    -- STEP 5: Create binary feature flags and output
    -- =============================================
    SELECT
        -- Original columns
        ObservationDate,
        ASXCode,
        FormattedGEX,
        FormattedPrev1GEX,
        GEXChange,
        SwingIndicator,
        PotentialSwingIndicator,
        BuyCall_GEXDeltaPerc,
        BuyPut_GEXDeltaPerc,
        SellCall_GEXDeltaPerc,
        SellPut_GEXDeltaPerc,
        BTC,
        VIX,
        Gold,
        NASDAQ,
        Stock_DarkPoolBuySellRatio,
        Stock_DarkPoolIndex,
        SVix_DarkPoolBuyRatio,
        SVix_DarkPoolIndex,
        [Close],
        TodayChange,
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange,
        Next20DaysChange,
        Prev2DaysChange,
        Prev10DaysChange,
        RSI,

        -- ===== CORE GEX FEATURES (5 features) =====
        GEX,
        Prev1GEX,
        CASE WHEN GEX > 0 THEN 1 ELSE 0 END as GEX_Positive,
        CASE WHEN GEX < 0 THEN 1 ELSE 0 END as GEX_Negative,
        GEX_DayChange,

        -- ===== STATISTICAL FEATURES (13 features) =====
        GEX_ZScore,
        GEX_ZScore_60day,
        GEX_Percentile,

        -- Z-score regime flags (5 features)
        CASE WHEN GEX_ZScore < -2.0 THEN 1 ELSE 0 END as GEX_ZScore_VeryLow,
        CASE WHEN GEX_ZScore >= -2.0 AND GEX_ZScore < -1.5 THEN 1 ELSE 0 END as GEX_ZScore_Low,
        CASE WHEN GEX_ZScore >= -1.5 AND GEX_ZScore < -1.0 THEN 1 ELSE 0 END as GEX_ZScore_Moderate_Low,
        CASE WHEN GEX_ZScore > 1.5 AND GEX_ZScore <= 2.0 THEN 1 ELSE 0 END as GEX_ZScore_High,
        CASE WHEN GEX_ZScore > 2.0 THEN 1 ELSE 0 END as GEX_ZScore_VeryHigh,

        -- Percentile regime flags (4 features)
        CASE WHEN GEX_Percentile < 5 THEN 1 ELSE 0 END as GEX_Percentile_VeryLow,
        CASE WHEN GEX_Percentile < 15 THEN 1 ELSE 0 END as GEX_Percentile_Low,
        CASE WHEN GEX_Percentile > 85 THEN 1 ELSE 0 END as GEX_Percentile_High,
        CASE WHEN GEX_Percentile > 95 THEN 1 ELSE 0 END as GEX_Percentile_VeryHigh,

        -- ===== TREND FEATURES (9 features) =====
        GEX_SMA5,
        GEX_SMA10,
        GEX_SMA20,
        CASE WHEN GEX > GEX_SMA10 THEN 1 ELSE 0 END as GEX_Above_SMA10,
        CASE WHEN GEX > GEX_SMA20 THEN 1 ELSE 0 END as GEX_Above_SMA20,
        CASE WHEN GEX_SMA5 > GEX_SMA20 THEN 1 ELSE 0 END as GEX_Trending_Up,
        GEX_PctChange,
        CASE WHEN GEX_DayChange > 0 THEN 1 ELSE 0 END as GEX_Rising,
        CASE WHEN GEX_DayChange < 0 THEN 1 ELSE 0 END as GEX_Falling,

        -- ===== VOLATILITY FEATURES (3 features) =====
        GEX_Volatility,
        CASE WHEN GEX_Vol_Percentile > 0.75 THEN 1 ELSE 0 END as GEX_HighVolatility,
        CASE WHEN GEX_Vol_Percentile < 0.25 THEN 1 ELSE 0 END as GEX_StableRegime,

        -- ===== REGIME TRANSITION FEATURES (4 features) =====
        CASE WHEN GEX > 0 AND GEX_Lag1 < 0 THEN 1 ELSE 0 END as GEX_Turned_Positive,
        CASE WHEN GEX < 0 AND GEX_Lag1 > 0 THEN 1 ELSE 0 END as GEX_Turned_Negative,
        CASE WHEN Prev_GEX_ZScore < -2.0 AND GEX_ZScore > -2.0 THEN 1 ELSE 0 END as GEX_Escaped_VeryLow_Zscore,
        CASE WHEN Prev_GEX_ZScore > 2.0 AND GEX_ZScore < 2.0 THEN 1 ELSE 0 END as GEX_Escaped_VeryHigh_Zscore,

        -- ===== SWING INDICATOR FEATURES (6 features) =====
        CASE WHEN SwingIndicator = 'swing up' THEN 1 ELSE 0 END as Is_Swing_Up,
        CASE WHEN SwingIndicator = 'swing down' THEN 1 ELSE 0 END as Is_Swing_Down,
        CASE WHEN PotentialSwingIndicator = 'Potential swing up' THEN 1 ELSE 0 END as Is_Potential_Swing_Up,
        CASE WHEN PotentialSwingIndicator = 'Potential swing down' THEN 1 ELSE 0 END as Is_Potential_Swing_Down,
        CASE WHEN CAST(GEXChange AS FLOAT) > 0 THEN 1 ELSE 0 END as GEXChange_Positive,
        CASE WHEN CAST(GEXChange AS FLOAT) < 0 THEN 1 ELSE 0 END as GEXChange_Negative,

        -- ===== BIG MOVE FLAGS (2 features) =====
        CASE WHEN GEX_PctChange < -10 THEN 1 ELSE 0 END as GEX_BigDrop,
        CASE WHEN GEX_PctChange > 10 THEN 1 ELSE 0 END as GEX_BigRise,

        -- ===== COMBINED HIGH-VALUE SIGNALS (5 features) =====
        -- Best 1-2d signal: Pot Swing Up + Neg GEXChange (67% win @ 1d, 76% @ 2d)
        CASE WHEN PotentialSwingIndicator = 'Potential swing up' AND CAST(GEXChange AS FLOAT) < 0 THEN 1 ELSE 0 END as Pot_Swing_Up_AND_Neg_GEXChange,

        -- Best 5d signal: Low GEX Z + Pot Swing Up (100% win @ 5d!)
        CASE WHEN GEX_ZScore < -1.5 AND PotentialSwingIndicator = 'Potential swing up' THEN 1 ELSE 0 END as Low_GEX_Z_AND_Pot_Swing_Up,

        -- Golden Setup: VIX > 20 AND RSI < 35 (+1.16% @ 5d)
        CASE WHEN VIX > 20 AND RSI < 35 THEN 1 ELSE 0 END as Golden_Setup,
        CASE WHEN VIX > 20 THEN 1 ELSE 0 END as VIX_Very_High,

        -- Negative GEX + High VIX (75% win @ 5d)
        CASE WHEN GEX < 0 AND VIX > 20 THEN 1 ELSE 0 END as Negative_GEX_AND_High_VIX

    FROM DerivedFeatures
    WHERE ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo
    ORDER BY ObservationDate ASC;

END
