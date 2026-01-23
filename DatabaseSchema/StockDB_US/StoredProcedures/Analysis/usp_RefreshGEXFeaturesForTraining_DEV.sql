-- Stored procedure: [Analysis].[usp_RefreshGEXFeaturesForTraining_DEV]


CREATE   PROCEDURE [Analysis].[usp_RefreshGEXFeaturesForTraining_DEV]
    @ASXCode NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    -- =============================================
    -- CONFIGURATION & DATES
    -- =============================================

    declare @dtLastTradingDate as date = Common.DateAddBusinessDay_Plus(-1, getdate())
    select @dtLastTradingDate

    DECLARE @ObservationDateTo AS DATE = cast(getdate() as date)
    -- 1 Year rolling window for training data
    DECLARE @ObservationDateFrom AS DATE = DATEADD(DAY, -365*3, @ObservationDateTo);
    -- Buffer for window functions (SMA/Vol calculations)
    DECLARE @LookbackDate DATE = DATEADD(DAY, -60, @ObservationDateFrom);

    -- =============================================
    -- STEP 1: Fetch Base Data (Merged Columns)
    -- =============================================
    WITH BaseData AS (
        SELECT
            dr.ObservationDate,
            dr.ASXCode,
            -- GEX Raw Fields
            gex.FormattedGEX,
            gex.FormattedPrev1GEX,
            gex.GEXChange,
            gex.SwingIndicator,
            gex.PotentialSwingIndicator,
            -- Capital Type GEX
            bc_curr.GEXDeltaPerc as BuyCall_GEXDeltaPerc,
            bp_curr.GEXDeltaPerc as BuyPut_GEXDeltaPerc,
            sc_curr.GEXDeltaPerc as SellCall_GEXDeltaPerc,
            sp_curr.GEXDeltaPerc as SellPut_GEXDeltaPerc,
            -- Market Context
            btc.[Close] as BTC,
            vix.[Close] as VIX,
            gold.[Close] as Gold,
            nasdaq.[Close] as NASDAQ,
            -- Dark Pool Sentiment
            dp.BuyRatio as Stock_DarkPoolBuySellRatio,
            dp.DPIndex as Stock_DarkPoolIndex,
            dp_svix.BuyRatio as SVix_DarkPoolBuyRatio,
            dp_svix.DPIndex as SVix_DarkPoolIndex,
            -- Stock Price Data
            bc_curr.[Close],
            ph.TodayChange,
            ph.TomorrowChange,
            ph.Next2DaysChange,
            ph.Next5DaysChange,
            ph.Next10DaysChange,
            ph.Next20DaysChange,
            ph.Prev2DaysChange,
            ph.Prev10DaysChange,
            -- RSI Helper (Inline Calculation)
            AVG(CASE WHEN ph.TodayChange > 0 THEN ph.TodayChange ELSE 0 END)
                OVER (PARTITION BY dr.ASXCode ORDER BY dr.ObservationDate ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as RSI_Gain,
            AVG(CASE WHEN ph.TodayChange < 0 THEN ABS(ph.TodayChange) ELSE 0 END)
                OVER (PARTITION BY dr.ASXCode ORDER BY dr.ObservationDate ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as RSI_Loss
        FROM (
            SELECT DISTINCT ObservationDate, ASXCode
            FROM StockDB_US.Transform.v_OptionGexChangeCapitalType
            WHERE ASXCode = @ASXCode
            AND ObservationDate >= @LookbackDate AND ObservationDate <= @ObservationDateTo
            AND CapitalType = 'BC'
        ) dr
        -- Joins for Capital Types
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType bc_curr
            ON dr.ASXCode = bc_curr.ASXCode AND dr.ObservationDate = bc_curr.ObservationDate AND bc_curr.CapitalType = 'BC'
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType bp_curr
            ON dr.ASXCode = bp_curr.ASXCode AND dr.ObservationDate = bp_curr.ObservationDate AND bp_curr.CapitalType = 'BP'
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType sc_curr
            ON dr.ASXCode = sc_curr.ASXCode AND dr.ObservationDate = sc_curr.ObservationDate AND sc_curr.CapitalType = 'SC'
        LEFT JOIN StockDB_US.Transform.v_OptionGexChangeCapitalType sp_curr
            ON dr.ASXCode = sp_curr.ASXCode AND dr.ObservationDate = sp_curr.ObservationDate AND sp_curr.CapitalType = 'SP'
        -- Joins for Price History & Market Data
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] ph
            ON dr.ASXCode = ph.ASXCode AND dr.ObservationDate = ph.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] btc
            ON btc.ASXCode = 'BTC' AND dr.ObservationDate = btc.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] vix
            ON vix.ASXCode = '_VIX.US' AND dr.ObservationDate = vix.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] gold
            ON gold.ASXCode = 'GOLD' AND dr.ObservationDate = gold.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] nasdaq
            ON nasdaq.ASXCode = 'NASDAQ' AND dr.ObservationDate = nasdaq.ObservationDate
        -- Joins for Dark Pool
        LEFT JOIN (
            SELECT Symbol+'.US' as ASXCode, ObservationDate, BuyRatio, DPIndex
            FROM StockDB.StockData.v_FinraDIX_Norm_All
        ) as dp
            ON CASE WHEN dr.ASXCode = 'SPXW.US' THEN 'SPY.US' ELSE dr.ASXCode END = dp.ASXCode
            AND dr.ObservationDate = dp.ObservationDate
        LEFT JOIN (
            SELECT Symbol+'.US' as ASXCode, ObservationDate, BuyRatio, DPIndex
            FROM StockDB.StockData.v_FinraDIX_Norm_All WHERE Symbol = 'svix'
        ) as dp_svix
            ON dr.ObservationDate = dp_svix.ObservationDate
        -- Join for GEX Calculated
        LEFT JOIN (
            SELECT ASXCode, ObservationDate, FormattedGEX, FormattedPrev1GEX, SwingIndicator, PotentialSwingIndicator, GEXChange
            FROM StockDB_US.StockData.v_CalculatedGEXPlus_V2
            WHERE ASXCode IS NOT NULL
        ) as gex
            ON dr.ObservationDate = gex.ObservationDate AND dr.ASXCode = gex.ASXCode
        WHERE bc_curr.GEXDeltaPerc IS NOT NULL
    ),

    -- =============================================
    -- STEP 2: Parse Strings to Numbers
    -- =============================================
    ParsedGEX AS (
        SELECT
            *,
            -- GEX Parsing
            CASE WHEN FormattedGEX IS NULL OR LTRIM(RTRIM(FormattedGEX)) = '' THEN 0
                 ELSE CAST(REPLACE(FormattedGEX, ',', '') AS FLOAT) END as GEX,
            CASE WHEN FormattedPrev1GEX IS NULL OR LTRIM(RTRIM(FormattedPrev1GEX)) = '' THEN 0
                 ELSE CAST(REPLACE(FormattedPrev1GEX, ',', '') AS FLOAT) END as Prev1GEX,
            -- RSI Calculation
            CASE WHEN RSI_Loss IS NULL OR RSI_Loss = 0 THEN NULL
                 WHEN RSI_Gain IS NULL THEN NULL
                 ELSE 100 - (100.0 / (1 + RSI_Gain / NULLIF(RSI_Loss, 0))) END as RSI
        FROM BaseData
    ),

    -- =============================================
    -- STEP 3: Rolling Statistics (Extended with more MAs)
    -- =============================================
    StatisticalFeatures AS (
        SELECT
            *,
            -- === GEX Stats ===
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_Mean20,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_Std20,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Mean60,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Std60,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) as GEX_SMA5,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as GEX_SMA10,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_SMA20,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as GEX_Volatility,
            LAG(GEX, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as GEX_Lag1,
            MIN(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Min60,
            MAX(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Max60,

            -- === NEW: Additional Price Moving Averages ===
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) as Price_SMA5,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as Price_SMA10,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as Price_SMA20,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) as Price_SMA50,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) as Price_SMA100,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) as Price_SMA200,

            -- MACD components
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as Price_SMA12,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 25 PRECEDING AND CURRENT ROW) as Price_SMA26,

            -- === NEW: Multiple Bollinger Bands (10, 20, 50 day) ===
            -- 10-day BB
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as BB10_Middle,
            STDEV([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as BB10_Std,

            -- 20-day BB (existing)
            STDEV([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as Price_Std20,

            -- 50-day BB
            STDEV([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) as BB50_Std,

            -- === NEW: Price Momentum & Rate of Change ===
            LAG([Close], 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as Price_Lag1,
            LAG([Close], 2) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as Price_Lag2,
            LAG([Close], 5) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as Price_Lag5,
            LAG([Close], 10) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as Price_Lag10,
            LAG([Close], 20) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as Price_Lag20

        FROM ParsedGEX
    ),

    -- =============================================
    -- STEP 4: Derived Calculations (Extended)
    -- =============================================
    DerivedFeatures AS (
        SELECT
            *,
            -- === Existing GEX Features ===
            CASE WHEN GEX_Std20 = 0 THEN 0 ELSE (GEX - GEX_Mean20) / GEX_Std20 END as GEX_ZScore,
            CASE WHEN GEX_Std60 = 0 THEN 0 ELSE (GEX - GEX_Mean60) / GEX_Std60 END as GEX_ZScore_60day,
            CASE WHEN GEX_Max60 = GEX_Min60 THEN 50.0
                 ELSE ((GEX - GEX_Min60) / (GEX_Max60 - GEX_Min60)) * 100.0 END as GEX_Percentile,
            GEX - ISNULL(Prev1GEX, 0) as GEX_DayChange,
            CASE WHEN ABS(Prev1GEX) < 0.01 THEN 0 ELSE ((GEX - Prev1GEX) / ABS(Prev1GEX)) * 100 END as GEX_PctChange,
            CASE WHEN LAG(GEX_Std20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) = 0 THEN 0
                 ELSE (LAG(GEX, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) - LAG(GEX_Mean20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate))
                      / LAG(GEX_Std20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) END as Prev_GEX_ZScore,
            CASE WHEN MAX(GEX_Volatility) OVER (PARTITION BY ASXCode) = MIN(GEX_Volatility) OVER (PARTITION BY ASXCode) THEN 0.5
                 ELSE (GEX_Volatility - MIN(GEX_Volatility) OVER (PARTITION BY ASXCode))
                      / (MAX(GEX_Volatility) OVER (PARTITION BY ASXCode) - MIN(GEX_Volatility) OVER (PARTITION BY ASXCode)) END as GEX_Vol_Percentile,

            -- === NEW: Multiple Bollinger Bands ===
            -- 10-day BB
            BB10_Middle + (2 * ISNULL(BB10_Std, 0)) as BB10_Upper,
            BB10_Middle - (2 * ISNULL(BB10_Std, 0)) as BB10_Lower,

            -- 20-day BB (existing + enhanced)
            Price_SMA20 + (2 * ISNULL(Price_Std20, 0)) as BB20_Upper,
            Price_SMA20 - (2 * ISNULL(Price_Std20, 0)) as BB20_Lower,
            Price_SMA20 + (1 * ISNULL(Price_Std20, 0)) as BB20_Upper_1Std,
            Price_SMA20 - (1 * ISNULL(Price_Std20, 0)) as BB20_Lower_1Std,

            -- 50-day BB
            Price_SMA50 + (2 * ISNULL(BB50_Std, 0)) as BB50_Upper,
            Price_SMA50 - (2 * ISNULL(BB50_Std, 0)) as BB50_Lower,

            -- === NEW: Price Momentum (Rate of Change) ===
            CASE WHEN Price_Lag1 = 0 OR Price_Lag1 IS NULL THEN 0
                 ELSE (([Close] - Price_Lag1) / Price_Lag1) * 100 END as Price_ROC_1day,
            CASE WHEN Price_Lag2 = 0 OR Price_Lag2 IS NULL THEN 0
                 ELSE (([Close] - Price_Lag2) / Price_Lag2) * 100 END as Price_ROC_2day,
            CASE WHEN Price_Lag5 = 0 OR Price_Lag5 IS NULL THEN 0
                 ELSE (([Close] - Price_Lag5) / Price_Lag5) * 100 END as Price_ROC_5day,
            CASE WHEN Price_Lag10 = 0 OR Price_Lag10 IS NULL THEN 0
                 ELSE (([Close] - Price_Lag10) / Price_Lag10) * 100 END as Price_ROC_10day,
            CASE WHEN Price_Lag20 = 0 OR Price_Lag20 IS NULL THEN 0
                 ELSE (([Close] - Price_Lag20) / Price_Lag20) * 100 END as Price_ROC_20day,

            -- === Existing MACD ===
            Price_SMA12 - Price_SMA26 as MACD_Line

        FROM StatisticalFeatures
    ),

    -- =============================================
    -- STEP 5: Distance & Proximity Features
    -- =============================================
    ProximityFeatures AS (
        SELECT
            *,

            -- === NEW: Distance to Bollinger Bands (Absolute & Percentage) ===
            -- 10-day BB Distance
            [Close] - BB10_Upper as Dist_To_BB10_Upper,
            BB10_Lower - [Close] as Dist_To_BB10_Lower,
            CASE WHEN BB10_Upper = 0 THEN 0 ELSE (([Close] - BB10_Upper) / BB10_Upper) * 100 END as Dist_To_BB10_Upper_Pct,
            CASE WHEN BB10_Lower = 0 THEN 0 ELSE ((BB10_Lower - [Close]) / BB10_Lower) * 100 END as Dist_To_BB10_Lower_Pct,

            -- 20-day BB Distance
            [Close] - BB20_Upper as Dist_To_BB20_Upper,
            BB20_Lower - [Close] as Dist_To_BB20_Lower,
            CASE WHEN BB20_Upper = 0 THEN 0 ELSE (([Close] - BB20_Upper) / BB20_Upper) * 100 END as Dist_To_BB20_Upper_Pct,
            CASE WHEN BB20_Lower = 0 THEN 0 ELSE ((BB20_Lower - [Close]) / BB20_Lower) * 100 END as Dist_To_BB20_Lower_Pct,

            -- 50-day BB Distance
            [Close] - BB50_Upper as Dist_To_BB50_Upper,
            BB50_Lower - [Close] as Dist_To_BB50_Lower,
            CASE WHEN BB50_Upper = 0 THEN 0 ELSE (([Close] - BB50_Upper) / BB50_Upper) * 100 END as Dist_To_BB50_Upper_Pct,
            CASE WHEN BB50_Lower = 0 THEN 0 ELSE ((BB50_Lower - [Close]) / BB50_Lower) * 100 END as Dist_To_BB50_Lower_Pct,

            -- === NEW: Distance to Moving Averages (Absolute & Percentage) ===
            [Close] - Price_SMA5 as Dist_To_SMA5,
            [Close] - Price_SMA10 as Dist_To_SMA10,
            [Close] - Price_SMA20 as Dist_To_SMA20,
            [Close] - Price_SMA50 as Dist_To_SMA50,
            [Close] - Price_SMA100 as Dist_To_SMA100,
            [Close] - Price_SMA200 as Dist_To_SMA200,

            CASE WHEN Price_SMA5 = 0 THEN 0 ELSE (([Close] - Price_SMA5) / Price_SMA5) * 100 END as Dist_To_SMA5_Pct,
            CASE WHEN Price_SMA10 = 0 THEN 0 ELSE (([Close] - Price_SMA10) / Price_SMA10) * 100 END as Dist_To_SMA10_Pct,
            CASE WHEN Price_SMA20 = 0 THEN 0 ELSE (([Close] - Price_SMA20) / Price_SMA20) * 100 END as Dist_To_SMA20_Pct,
            CASE WHEN Price_SMA50 = 0 THEN 0 ELSE (([Close] - Price_SMA50) / Price_SMA50) * 100 END as Dist_To_SMA50_Pct,
            CASE WHEN Price_SMA100 = 0 THEN 0 ELSE (([Close] - Price_SMA100) / Price_SMA100) * 100 END as Dist_To_SMA100_Pct,
            CASE WHEN Price_SMA200 = 0 THEN 0 ELSE (([Close] - Price_SMA200) / Price_SMA200) * 100 END as Dist_To_SMA200_Pct,

            -- === NEW: BB PercentB for all timeframes ===
            CASE WHEN (BB10_Upper - BB10_Lower) = 0 THEN 0.5
                 ELSE ([Close] - BB10_Lower) / (BB10_Upper - BB10_Lower) END as BB10_PercentB,
            CASE WHEN (BB20_Upper - BB20_Lower) = 0 THEN 0.5
                 ELSE ([Close] - BB20_Lower) / (BB20_Upper - BB20_Lower) END as BB20_PercentB,
            CASE WHEN (BB50_Upper - BB50_Lower) = 0 THEN 0.5
                 ELSE ([Close] - BB50_Lower) / (BB50_Upper - BB50_Lower) END as BB50_PercentB,

            -- === NEW: BB Bandwidth for all timeframes ===
            CASE WHEN BB10_Middle = 0 THEN 0 ELSE (BB10_Upper - BB10_Lower) / BB10_Middle END as BB10_Bandwidth,
            CASE WHEN Price_SMA20 = 0 THEN 0 ELSE (BB20_Upper - BB20_Lower) / Price_SMA20 END as BB20_Bandwidth,
            CASE WHEN Price_SMA50 = 0 THEN 0 ELSE (BB50_Upper - BB50_Lower) / Price_SMA50 END as BB50_Bandwidth

        FROM DerivedFeatures
    )

    -- =============================================
    -- STEP 6: Final Selection with Enhanced Features
    -- =============================================
    SELECT
        ObservationDate,
        ASXCode,

        -- =============================================
        -- 1. MARKET CONTEXT
        -- =============================================
        BTC,
        VIX,
        Gold,
        NASDAQ,
        Stock_DarkPoolBuySellRatio,
        Stock_DarkPoolIndex,
        SVix_DarkPoolBuyRatio,
        SVix_DarkPoolIndex,
        BuyCall_GEXDeltaPerc,
        BuyPut_GEXDeltaPerc,

        -- =============================================
        -- 2. PRICE & TARGETS
        -- =============================================
        [Close],
        TodayChange,
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange,
        Next20DaysChange,
        Prev2DaysChange,
        Prev10DaysChange,

        -- =============================================
        -- 3. OSCILLATORS
        -- =============================================
        RSI,

        -- =============================================
        -- 4. GEX FEATURES
        -- =============================================
        GEX,
        Prev1GEX,
        GEXChange,
        CASE WHEN GEX > 0 THEN 1 ELSE 0 END as GEX_Positive,
        CASE WHEN GEX < 0 THEN 1 ELSE 0 END as GEX_Negative,
        GEX_DayChange,
        GEX_ZScore,
        GEX_ZScore_60day,
        GEX_Percentile,
        CASE WHEN GEX_ZScore < -2.0 THEN 1 ELSE 0 END as GEX_ZScore_VeryLow,
        CASE WHEN GEX_ZScore >= -2.0 AND GEX_ZScore < -1.5 THEN 1 ELSE 0 END as GEX_ZScore_Low,
        CASE WHEN GEX_ZScore >= -1.5 AND GEX_ZScore < -1.0 THEN 1 ELSE 0 END as GEX_ZScore_Moderate_Low,
        CASE WHEN GEX_ZScore > 1.5 AND GEX_ZScore <= 2.0 THEN 1 ELSE 0 END as GEX_ZScore_High,
        CASE WHEN GEX_ZScore > 2.0 THEN 1 ELSE 0 END as GEX_ZScore_VeryHigh,
        CASE WHEN GEX_Percentile < 5 THEN 1 ELSE 0 END as GEX_Percentile_VeryLow,
        CASE WHEN GEX_Percentile < 15 THEN 1 ELSE 0 END as GEX_Percentile_Low,
        CASE WHEN GEX_Percentile > 85 THEN 1 ELSE 0 END as GEX_Percentile_High,
        CASE WHEN GEX_Percentile > 95 THEN 1 ELSE 0 END as GEX_Percentile_VeryHigh,

        -- =============================================
        -- 5. GEX TREND FEATURES
        -- =============================================
        GEX_SMA5,
        GEX_SMA10,
        GEX_SMA20,
        CASE WHEN GEX > GEX_SMA10 THEN 1 ELSE 0 END as GEX_Above_SMA10,
        CASE WHEN GEX > GEX_SMA20 THEN 1 ELSE 0 END as GEX_Above_SMA20,
        CASE WHEN GEX_SMA5 > GEX_SMA20 THEN 1 ELSE 0 END as GEX_Trending_Up,
        GEX_PctChange,
        CASE WHEN GEX_DayChange > 0 THEN 1 ELSE 0 END as GEX_Rising,
        CASE WHEN GEX_DayChange < 0 THEN 1 ELSE 0 END as GEX_Falling,

        -- =============================================
        -- 6. GEX VOLATILITY FEATURES
        -- =============================================
        GEX_Volatility,
        CASE WHEN GEX_Vol_Percentile > 0.75 THEN 1 ELSE 0 END as GEX_HighVolatility,
        CASE WHEN GEX_Vol_Percentile < 0.25 THEN 1 ELSE 0 END as GEX_StableRegime,

        -- =============================================
        -- 7. GEX REGIME TRANSITION FEATURES
        -- =============================================
        CASE WHEN GEX > 0 AND GEX_Lag1 < 0 THEN 1 ELSE 0 END as GEX_Turned_Positive,
        CASE WHEN GEX < 0 AND GEX_Lag1 > 0 THEN 1 ELSE 0 END as GEX_Turned_Negative,
        CASE WHEN Prev_GEX_ZScore < -2.0 AND GEX_ZScore > -2.0 THEN 1 ELSE 0 END as GEX_Escaped_VeryLow_Zscore,
        CASE WHEN Prev_GEX_ZScore > 2.0 AND GEX_ZScore < 2.0 THEN 1 ELSE 0 END as GEX_Escaped_VeryHigh_Zscore,

        -- =============================================
        -- 8. SWING INDICATOR FEATURES
        -- =============================================
        SwingIndicator,
        PotentialSwingIndicator,
        CASE WHEN SwingIndicator = 'swing up' THEN 1 ELSE 0 END as Is_Swing_Up,
        CASE WHEN SwingIndicator = 'swing down' THEN 1 ELSE 0 END as Is_Swing_Down,
        CASE WHEN PotentialSwingIndicator = 'Potential swing up' THEN 1 ELSE 0 END as Is_Potential_Swing_Up,
        CASE WHEN PotentialSwingIndicator = 'Potential swing down' THEN 1 ELSE 0 END as Is_Potential_Swing_Down,
        CASE WHEN ISNULL(CAST(GEXChange AS FLOAT), 0) > 0 THEN 1 ELSE 0 END as GEXChange_Positive,
        CASE WHEN ISNULL(CAST(GEXChange AS FLOAT), 0) < 0 THEN 1 ELSE 0 END as GEXChange_Negative,

        -- =============================================
        -- 9. GEX BIG MOVE FLAGS
        -- =============================================
        CASE WHEN GEX_PctChange < -10 THEN 1 ELSE 0 END as GEX_BigDrop,
        CASE WHEN GEX_PctChange > 10 THEN 1 ELSE 0 END as GEX_BigRise,

        -- =============================================
        -- 10. PRICE MOVING AVERAGES (NEW: Extended)
        -- =============================================
        Price_SMA5,
        Price_SMA10,
        Price_SMA20,
        Price_SMA50,
        Price_SMA100,
        Price_SMA200,

        -- =============================================
        -- 11. NEW: PRICE vs MA POSITION FLAGS
        -- =============================================
        CASE WHEN [Close] > Price_SMA5 THEN 1 ELSE 0 END as Price_Above_SMA5,
        CASE WHEN [Close] > Price_SMA10 THEN 1 ELSE 0 END as Price_Above_SMA10,
        CASE WHEN [Close] > Price_SMA20 THEN 1 ELSE 0 END as Price_Above_SMA20,
        CASE WHEN [Close] > Price_SMA50 THEN 1 ELSE 0 END as Price_Above_SMA50,
        CASE WHEN [Close] > Price_SMA100 THEN 1 ELSE 0 END as Price_Above_SMA100,
        CASE WHEN [Close] > Price_SMA200 THEN 1 ELSE 0 END as Price_Above_SMA200,

        CASE WHEN [Close] < Price_SMA5 THEN 1 ELSE 0 END as Price_Below_SMA5,
        CASE WHEN [Close] < Price_SMA10 THEN 1 ELSE 0 END as Price_Below_SMA10,
        CASE WHEN [Close] < Price_SMA20 THEN 1 ELSE 0 END as Price_Below_SMA20,
        CASE WHEN [Close] < Price_SMA50 THEN 1 ELSE 0 END as Price_Below_SMA50,
        CASE WHEN [Close] < Price_SMA100 THEN 1 ELSE 0 END as Price_Below_SMA100,
        CASE WHEN [Close] < Price_SMA200 THEN 1 ELSE 0 END as Price_Below_SMA200,

        -- =============================================
        -- 12. NEW: PRICE NEAR MA FLAGS (Within 1%)
        -- =============================================
        CASE WHEN ABS(Dist_To_SMA5_Pct) < 1.0 THEN 1 ELSE 0 END as Price_Near_SMA5,
        CASE WHEN ABS(Dist_To_SMA10_Pct) < 1.0 THEN 1 ELSE 0 END as Price_Near_SMA10,
        CASE WHEN ABS(Dist_To_SMA20_Pct) < 1.0 THEN 1 ELSE 0 END as Price_Near_SMA20,
        CASE WHEN ABS(Dist_To_SMA50_Pct) < 1.0 THEN 1 ELSE 0 END as Price_Near_SMA50,
        CASE WHEN ABS(Dist_To_SMA100_Pct) < 1.0 THEN 1 ELSE 0 END as Price_Near_SMA100,
        CASE WHEN ABS(Dist_To_SMA200_Pct) < 1.0 THEN 1 ELSE 0 END as Price_Near_SMA200,

        -- =============================================
        -- 13. NEW: PRICE VERY CLOSE TO MA (Within 0.5%)
        -- =============================================
        CASE WHEN ABS(Dist_To_SMA20_Pct) < 0.5 THEN 1 ELSE 0 END as Price_VeryClose_SMA20,
        CASE WHEN ABS(Dist_To_SMA50_Pct) < 0.5 THEN 1 ELSE 0 END as Price_VeryClose_SMA50,
        CASE WHEN ABS(Dist_To_SMA200_Pct) < 0.5 THEN 1 ELSE 0 END as Price_VeryClose_SMA200,

        -- =============================================
        -- 14. NEW: MA DISTANCE (Raw values for ML)
        -- =============================================
        Dist_To_SMA5,
        Dist_To_SMA10,
        Dist_To_SMA20,
        Dist_To_SMA50,
        Dist_To_SMA100,
        Dist_To_SMA200,
        Dist_To_SMA5_Pct,
        Dist_To_SMA10_Pct,
        Dist_To_SMA20_Pct,
        Dist_To_SMA50_Pct,
        Dist_To_SMA100_Pct,
        Dist_To_SMA200_Pct,

        -- =============================================
        -- 15. NEW: MA ALIGNMENT & CROSSOVER FLAGS
        -- =============================================
        CASE WHEN Price_SMA5 > Price_SMA10 AND Price_SMA10 > Price_SMA20 THEN 1 ELSE 0 END as MA_Bullish_Alignment_Short,
        CASE WHEN Price_SMA20 > Price_SMA50 AND Price_SMA50 > Price_SMA100 THEN 1 ELSE 0 END as MA_Bullish_Alignment_Long,
        CASE WHEN Price_SMA5 < Price_SMA10 AND Price_SMA10 < Price_SMA20 THEN 1 ELSE 0 END as MA_Bearish_Alignment_Short,
        CASE WHEN Price_SMA20 < Price_SMA50 AND Price_SMA50 < Price_SMA100 THEN 1 ELSE 0 END as MA_Bearish_Alignment_Long,
        CASE WHEN Price_SMA20 > Price_SMA50 THEN 1 ELSE 0 END as SMA20_Above_SMA50,
        CASE WHEN Price_SMA50 > Price_SMA200 THEN 1 ELSE 0 END as SMA50_Above_SMA200,
        CASE WHEN Price_SMA20 > Price_SMA50 AND Price_SMA50 > Price_SMA200 THEN 1 ELSE 0 END as Golden_Cross_Formation,
        CASE WHEN Price_SMA20 < Price_SMA50 AND Price_SMA50 < Price_SMA200 THEN 1 ELSE 0 END as Death_Cross_Formation,

        -- =============================================
        -- 16. NEW: BOLLINGER BANDS (Multiple Timeframes)
        -- =============================================
        -- 10-day BB
        BB10_Upper,
        BB10_Middle,
        BB10_Lower,
        BB10_PercentB,
        BB10_Bandwidth,

        -- 20-day BB
        BB20_Upper,
        Price_SMA20 as BB20_Middle,
        BB20_Lower,
        BB20_Upper_1Std,
        BB20_Lower_1Std,
        BB20_PercentB,
        BB20_Bandwidth,

        -- 50-day BB
        BB50_Upper,
        Price_SMA50 as BB50_Middle,
        BB50_Lower,
        BB50_PercentB,
        BB50_Bandwidth,

        -- =============================================
        -- 17. NEW: BB POSITION FLAGS
        -- =============================================
        -- 10-day BB
        CASE WHEN [Close] > BB10_Upper THEN 1 ELSE 0 END as BB10_Breakout_Upper,
        CASE WHEN [Close] < BB10_Lower THEN 1 ELSE 0 END as BB10_Breakout_Lower,
        CASE WHEN [Close] >= BB10_Middle + (0.5 * (BB10_Upper - BB10_Middle)) THEN 1 ELSE 0 END as BB10_In_Upper_Half,
        CASE WHEN [Close] <= BB10_Middle - (0.5 * (BB10_Middle - BB10_Lower)) THEN 1 ELSE 0 END as BB10_In_Lower_Half,

        -- 20-day BB
        CASE WHEN [Close] > BB20_Upper THEN 1 ELSE 0 END as BB20_Breakout_Upper,
        CASE WHEN [Close] < BB20_Lower THEN 1 ELSE 0 END as BB20_Breakout_Lower,
        CASE WHEN [Close] >= Price_SMA20 + (0.5 * (BB20_Upper - Price_SMA20)) THEN 1 ELSE 0 END as BB20_In_Upper_Half,
        CASE WHEN [Close] <= Price_SMA20 - (0.5 * (Price_SMA20 - BB20_Lower)) THEN 1 ELSE 0 END as BB20_In_Lower_Half,

        -- 50-day BB
        CASE WHEN [Close] > BB50_Upper THEN 1 ELSE 0 END as BB50_Breakout_Upper,
        CASE WHEN [Close] < BB50_Lower THEN 1 ELSE 0 END as BB50_Breakout_Lower,

        -- =============================================
        -- 18. NEW: BB NEAR BAND FLAGS (Within 2% of band)
        -- =============================================
        CASE WHEN ABS(Dist_To_BB20_Upper_Pct) < 2.0 THEN 1 ELSE 0 END as Price_Near_BB20_Upper,
        CASE WHEN ABS(Dist_To_BB20_Lower_Pct) < 2.0 THEN 1 ELSE 0 END as Price_Near_BB20_Lower,
        CASE WHEN ABS(Dist_To_BB50_Upper_Pct) < 2.0 THEN 1 ELSE 0 END as Price_Near_BB50_Upper,
        CASE WHEN ABS(Dist_To_BB50_Lower_Pct) < 2.0 THEN 1 ELSE 0 END as Price_Near_BB50_Lower,

        -- =============================================
        -- 19. NEW: BB DISTANCE (Raw values for ML)
        -- =============================================
        Dist_To_BB10_Upper,
        Dist_To_BB10_Lower,
        Dist_To_BB10_Upper_Pct,
        Dist_To_BB10_Lower_Pct,
        Dist_To_BB20_Upper,
        Dist_To_BB20_Lower,
        Dist_To_BB20_Upper_Pct,
        Dist_To_BB20_Lower_Pct,
        Dist_To_BB50_Upper,
        Dist_To_BB50_Lower,
        Dist_To_BB50_Upper_Pct,
        Dist_To_BB50_Lower_Pct,

        -- =============================================
        -- 20. NEW: BB SQUEEZE & EXPANSION
        -- =============================================
        CASE WHEN BB20_Bandwidth < 0.05 THEN 1 ELSE 0 END as BB20_Squeeze_Tight,
        CASE WHEN BB20_Bandwidth < 0.10 THEN 1 ELSE 0 END as BB20_Squeeze_Moderate,
        CASE WHEN BB20_Bandwidth > 0.20 THEN 1 ELSE 0 END as BB20_Wide_Range,
        CASE WHEN BB50_Bandwidth < 0.05 THEN 1 ELSE 0 END as BB50_Squeeze_Tight,
        CASE WHEN BB50_Bandwidth > 0.20 THEN 1 ELSE 0 END as BB50_Wide_Range,

        -- =============================================
        -- 21. NEW: BB WALK (Price staying near bands)
        -- =============================================
        CASE WHEN BB20_PercentB > 0.9 THEN 1 ELSE 0 END as BB20_Walking_Upper_Band,
        CASE WHEN BB20_PercentB < 0.1 THEN 1 ELSE 0 END as BB20_Walking_Lower_Band,

        -- =============================================
        -- 22. NEW: PRICE MOMENTUM & RATE OF CHANGE
        -- =============================================
        Price_ROC_1day,
        Price_ROC_2day,
        Price_ROC_5day,
        Price_ROC_10day,
        Price_ROC_20day,

        -- Momentum flags
        CASE WHEN Price_ROC_5day > 5 THEN 1 ELSE 0 END as Strong_Upward_Momentum_5d,
        CASE WHEN Price_ROC_5day < -5 THEN 1 ELSE 0 END as Strong_Downward_Momentum_5d,
        CASE WHEN Price_ROC_20day > 10 THEN 1 ELSE 0 END as Strong_Upward_Momentum_20d,
        CASE WHEN Price_ROC_20day < -10 THEN 1 ELSE 0 END as Strong_Downward_Momentum_20d,

        -- =============================================
        -- 23. MACD FEATURES
        -- =============================================
        MACD_Line,
        CASE WHEN MACD_Line > 0 THEN 1 ELSE 0 END as MACD_Positive,
        CASE WHEN MACD_Line < 0 THEN 1 ELSE 0 END as MACD_Negative,

        -- =============================================
        -- 24. NEW: GEX + PRICE INTERACTION FEATURES
        -- =============================================
        CASE WHEN GEX > 0 AND [Close] > Price_SMA50 THEN 1 ELSE 0 END as Positive_GEX_AND_Uptrend,
        CASE WHEN GEX < 0 AND [Close] < Price_SMA50 THEN 1 ELSE 0 END as Negative_GEX_AND_Downtrend,
        CASE WHEN GEX > 0 AND [Close] < BB20_Lower THEN 1 ELSE 0 END as Positive_GEX_BUT_Oversold,
        CASE WHEN GEX < 0 AND [Close] > BB20_Upper THEN 1 ELSE 0 END as Negative_GEX_BUT_Overbought,
        CASE WHEN GEX_DayChange > 0 AND Price_ROC_5day > 0 THEN 1 ELSE 0 END as GEX_Rising_With_Price,
        CASE WHEN GEX_DayChange < 0 AND Price_ROC_5day < 0 THEN 1 ELSE 0 END as GEX_Falling_With_Price,
        CASE WHEN GEX_DayChange > 0 AND Price_ROC_5day < 0 THEN 1 ELSE 0 END as GEX_Price_Divergence_Bullish,
        CASE WHEN GEX_DayChange < 0 AND Price_ROC_5day > 0 THEN 1 ELSE 0 END as GEX_Price_Divergence_Bearish,

        -- =============================================
        -- 25. COMBINED SIGNALS (Existing + Enhanced)
        -- =============================================
        CASE WHEN PotentialSwingIndicator = 'Potential swing up' AND ISNULL(CAST(GEXChange AS FLOAT), 0) < 0 THEN 1 ELSE 0 END as Pot_Swing_Up_AND_Neg_GEXChange,
        CASE WHEN GEX_ZScore < -1.5 AND PotentialSwingIndicator = 'Potential swing up' THEN 1 ELSE 0 END as Low_GEX_Z_AND_Pot_Swing_Up,
        CASE WHEN VIX > 20 AND RSI < 35 THEN 1 ELSE 0 END as Golden_Setup,
        CASE WHEN VIX > 20 THEN 1 ELSE 0 END as VIX_Very_High,
        CASE WHEN GEX < 0 AND VIX > 20 THEN 1 ELSE 0 END as Negative_GEX_AND_High_VIX,
        CASE WHEN [Close] > Price_SMA50 AND [Close] < BB20_Lower THEN 1 ELSE 0 END as Setup_Trend_Dip,
        CASE WHEN GEX_Vol_Percentile < 0.2 AND BB20_Bandwidth < 0.05 THEN 1 ELSE 0 END as Setup_Dual_Squeeze,
        CASE WHEN VIX > 25 AND GEX > 0 THEN 1 ELSE 0 END as Setup_Volatility_Crush,

        -- NEW: Additional Combined Signals
        CASE WHEN RSI < 30 AND [Close] < BB20_Lower AND [Close] > Price_SMA200 THEN 1 ELSE 0 END as Oversold_Dip_In_Uptrend,
        CASE WHEN RSI > 70 AND [Close] > BB20_Upper AND [Close] < Price_SMA200 THEN 1 ELSE 0 END as Overbought_Pop_In_Downtrend,
        CASE WHEN GEX_ZScore < -1.5 AND RSI < 35 AND [Close] < BB20_Lower THEN 1 ELSE 0 END as Triple_Oversold_Signal,
        CASE WHEN [Close] > Price_SMA20 AND [Close] > Price_SMA50 AND MACD_Line > 0 AND GEX > 0 THEN 1 ELSE 0 END as Strong_Bullish_Confirmation,
        CASE WHEN BB20_Bandwidth < 0.05 AND ABS(Price_ROC_1day) < 1 THEN 1 ELSE 0 END as Coiling_For_Breakout

    --into #Temp_GEX_Features
	into Analysis.GEX_Features_DEV
    FROM ProximityFeatures
    WHERE ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo

    ---- De-duplicate / Cleanup
    --delete a
    --from Analysis.GEX_Features as a
    --inner join #Temp_GEX_Features as b
    --on a.ASXCode = b.ASXCode
    --and a.ObservationDate = b.ObservationDate

    ---- Final Insert
    --insert into Analysis.GEX_Features
    --select *
    --from #Temp_GEX_Features

END