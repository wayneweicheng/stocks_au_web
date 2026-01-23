-- Stored procedure: [Analysis].[usp_RefreshGEXFeaturesForTraining_2]


CREATE   PROCEDURE [Analysis].[usp_RefreshGEXFeaturesForTraining_2]
	@ASXCode as varchar(10),
	@NumberOfBackDays int = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- =============================================
    -- CONFIGURATION & DATES
    -- =============================================

	--declare @ASXCode as varchar(10) = 'SPXW.US'
	--declare @NumberOfBackDays as int = 2
	declare @dtLastTradingDate as date = Common.DateAddBusinessDay_Plus(-1*@NumberOfBackDays, getdate())
	select @dtLastTradingDate
	if not exists
	(
		select 1
		from [StockDB_US].[Transform].[OptionGEXChange]
		where ObservationDate = @dtLastTradingDate
		AND ASXCode = @ASXCode
		and GEXDeltaAdjusted is not null
	)
	begin
		print('skip processing, data not available: ' + @ASXCode)
		return
	end

	if exists
	(
		select 1
		from StockDB_US.Analysis.GEX_Features
		where ObservationDate = @dtLastTradingDate
		AND ASXCode = @ASXCode
	)
	begin
		print('skip processing, already processed: ' + @ASXCode)
		return
	end

	if object_id(N'Tempdb.dbo.#TempOptionGexChangeCapitalType') is not null
		drop table #TempOptionGexChangeCapitalType

	select *
	into #TempOptionGexChangeCapitalType
	from StockDB_US.Transform.v_OptionGexChangeCapitalType
	where ASXCode = @ASXCode
	option(recompile)

	if object_id(N'Tempdb.dbo.#Tempv_CalculatedGEXPlus_V2') is not null
		drop table #Tempv_CalculatedGEXPlus_V2

	SELECT ASXCode, ObservationDate, FormattedGEX, FormattedPrev1GEX, SwingIndicator, PotentialSwingIndicator, GEXChange
	into #Tempv_CalculatedGEXPlus_V2
	FROM StockDB_US.StockData.v_CalculatedGEXPlus_V2
	where ASXCode = @ASXCode
	option(recompile)

	if object_id(N'Tempdb.dbo.#Temp_GEX_Features') is not null
		drop table #Temp_GEX_Features

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
            gex.ObservationDate,
            gex.ASXCode,
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
            -- [ADDED from Script]: Previous History
            ph.Prev2DaysChange,
            ph.Prev10DaysChange,
            -- RSI Helper (Inline Calculation)
            AVG(CASE WHEN ph.TodayChange > 0 THEN ph.TodayChange ELSE 0 END)
                OVER (PARTITION BY dr.ASXCode ORDER BY dr.ObservationDate ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as RSI_Gain,
            AVG(CASE WHEN ph.TodayChange < 0 THEN ABS(ph.TodayChange) ELSE 0 END)
                OVER (PARTITION BY dr.ASXCode ORDER BY dr.ObservationDate ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) as RSI_Loss
        FROM (
			SELECT ASXCode, ObservationDate, FormattedGEX, FormattedPrev1GEX, SwingIndicator, PotentialSwingIndicator, GEXChange
			FROM #Tempv_CalculatedGEXPlus_V2
        ) as gex
        -- Joins for Price History & Market Data
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] ph
            ON gex.ASXCode = ph.ASXCode AND gex.ObservationDate = ph.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] btc
            ON btc.ASXCode = 'BTC' AND gex.ObservationDate = btc.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] vix
            ON vix.ASXCode = '_VIX.US' AND gex.ObservationDate = vix.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] gold
            ON gold.ASXCode = 'GOLD' AND gex.ObservationDate = gold.ObservationDate
        LEFT JOIN StockDB_US.Transform.[PriceHistory24Month] nasdaq
            ON nasdaq.ASXCode = 'NASDAQ' AND gex.ObservationDate = nasdaq.ObservationDate
        -- Joins for Dark Pool
        LEFT JOIN (
            SELECT Symbol+'.US' as ASXCode, ObservationDate, BuyRatio, DPIndex
            FROM StockDB.StockData.v_FinraDIX_Norm_All
        ) as dp
            ON CASE WHEN gex.ASXCode = 'SPXW.US' THEN 'SPY.US' ELSE gex.ASXCode END = dp.ASXCode
            AND gex.ObservationDate = dp.ObservationDate
        LEFT JOIN (
            SELECT Symbol+'.US' as ASXCode, ObservationDate, BuyRatio, DPIndex
            FROM StockDB.StockData.v_FinraDIX_Norm_All WHERE Symbol = 'svix'
        ) as dp_svix
            ON gex.ObservationDate = dp_svix.ObservationDate
		LEFT JOIN
		(
            SELECT DISTINCT ObservationDate, ASXCode
            FROM #TempOptionGexChangeCapitalType
            WHERE 1 = 1
            AND ObservationDate >= @LookbackDate AND ObservationDate <= @ObservationDateTo
            AND CapitalType = 'BC'
        ) dr
            ON dr.ObservationDate = gex.ObservationDate AND dr.ASXCode = gex.ASXCode
        -- Joins for Capital Types
        LEFT JOIN #TempOptionGexChangeCapitalType bc_curr
            ON dr.ASXCode = bc_curr.ASXCode AND dr.ObservationDate = bc_curr.ObservationDate AND bc_curr.CapitalType = 'BC'
        LEFT JOIN #TempOptionGexChangeCapitalType bp_curr
            ON dr.ASXCode = bp_curr.ASXCode AND dr.ObservationDate = bp_curr.ObservationDate AND bp_curr.CapitalType = 'BP'
        LEFT JOIN #TempOptionGexChangeCapitalType sc_curr
            ON dr.ASXCode = sc_curr.ASXCode AND dr.ObservationDate = sc_curr.ObservationDate AND sc_curr.CapitalType = 'SC'
        LEFT JOIN #TempOptionGexChangeCapitalType sp_curr
            ON dr.ASXCode = sp_curr.ASXCode AND dr.ObservationDate = sp_curr.ObservationDate AND sp_curr.CapitalType = 'SP'
        WHERE gex.ASXCode IS NOT NULL
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
    -- STEP 3: Rolling Statistics (Merged GEX & Price TA)
    -- =============================================
    StatisticalFeatures AS (
        SELECT
            *,
            -- === GEX Stats (Extended from Script) ===
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_Mean20,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_Std20,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Mean60,
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Std60,
            
            -- [ADDED from Script]: GEX SMAs
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) as GEX_SMA5,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as GEX_SMA10,
            AVG(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as GEX_SMA20,
            
            -- [ADDED from Script]: GEX Volatility & Limits
            STDEV(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as GEX_Volatility,
            LAG(GEX, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) as GEX_Lag1,
            MIN(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Min60,
            MAX(GEX) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 59 PRECEDING AND CURRENT ROW) as GEX_Max60,

            -- === Price TA Stats (Original SP Features) ===
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as Price_SMA20,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) as Price_SMA50,
            -- MACD Proxy components
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as Price_SMA12,
            AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 25 PRECEDING AND CURRENT ROW) as Price_SMA26,
            -- BB Std Dev
            STDEV([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) as Price_Std20
        FROM ParsedGEX
    ),

    -- =============================================
    -- STEP 4: Derived Calculations
    -- =============================================
    DerivedFeatures AS (
        SELECT
            *,
            -- GEX Z-Scores
            CASE WHEN GEX_Std20 = 0 THEN 0 ELSE (GEX - GEX_Mean20) / GEX_Std20 END as GEX_ZScore,
            CASE WHEN GEX_Std60 = 0 THEN 0 ELSE (GEX - GEX_Mean60) / GEX_Std60 END as GEX_ZScore_60day,
        
            -- GEX Percentile
            CASE WHEN GEX_Max60 = GEX_Min60 THEN 50.0
                 ELSE ((GEX - GEX_Min60) / (GEX_Max60 - GEX_Min60)) * 100.0 END as GEX_Percentile,
        
            -- GEX Change
            GEX - ISNULL(Prev1GEX, 0) as GEX_DayChange,
            CASE WHEN ABS(Prev1GEX) < 0.01 THEN 0 ELSE ((GEX - Prev1GEX) / ABS(Prev1GEX)) * 100 END as GEX_PctChange,
        
            -- [ADDED from Script]: Previous Z-Score for Transitions
            CASE WHEN LAG(GEX_Std20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) = 0 THEN 0
                 ELSE (LAG(GEX, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) - LAG(GEX_Mean20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate))
                      / LAG(GEX_Std20, 1) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) END as Prev_GEX_ZScore,
        
            -- [ADDED from Script]: GEX Volatility Percentile
            CASE WHEN MAX(GEX_Volatility) OVER (PARTITION BY ASXCode) = MIN(GEX_Volatility) OVER (PARTITION BY ASXCode) THEN 0.5
                 ELSE (GEX_Volatility - MIN(GEX_Volatility) OVER (PARTITION BY ASXCode))
                      / (MAX(GEX_Volatility) OVER (PARTITION BY ASXCode) - MIN(GEX_Volatility) OVER (PARTITION BY ASXCode)) END as GEX_Vol_Percentile,

            -- === Price TA Derived (Original SP) ===
            Price_SMA20 + (2 * ISNULL(Price_Std20, 0)) as BB_Upper,
            Price_SMA20 - (2 * ISNULL(Price_Std20, 0)) as BB_Lower,
            Price_SMA12 - Price_SMA26 as MACD_Line
        FROM StatisticalFeatures
    )

    -- =============================================
    -- STEP 5: Final Selection (Merging Script + SP)
    -- =============================================
    SELECT
        ObservationDate,
        ASXCode,
    
        -- 1. ORIGINAL MARKET CONTEXT
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
    
        -- 2. PRICE & TARGETS (Includes new history columns)
        [Close],
        TodayChange,
        TomorrowChange,
        Next2DaysChange,
        Next5DaysChange,
        Next10DaysChange,
        Next20DaysChange,
        Prev2DaysChange,  -- [From Script]
        Prev10DaysChange, -- [From Script]
    
        -- 3. OSCILLATORS
        RSI,
    
        -- 4. GEX FEATURES (Enhanced)
        GEX,
        Prev1GEX,
        GEXChange, -- Raw string/value from source
        
        -- [ADDED from Script]: Core Boolean Flags
        CASE WHEN GEX > 0 THEN 1 ELSE 0 END as GEX_Positive,
        CASE WHEN GEX < 0 THEN 1 ELSE 0 END as GEX_Negative,
        
        GEX_DayChange,
        
        -- 5. STATISTICAL FEATURES
        GEX_ZScore,
        GEX_ZScore_60day,
        GEX_Percentile,

        -- [ADDED from Script]: Detailed Z-Score Flags
        CASE WHEN GEX_ZScore < -2.0 THEN 1 ELSE 0 END as GEX_ZScore_VeryLow,
        CASE WHEN GEX_ZScore >= -2.0 AND GEX_ZScore < -1.5 THEN 1 ELSE 0 END as GEX_ZScore_Low,
        CASE WHEN GEX_ZScore >= -1.5 AND GEX_ZScore < -1.0 THEN 1 ELSE 0 END as GEX_ZScore_Moderate_Low,
        CASE WHEN GEX_ZScore > 1.5 AND GEX_ZScore <= 2.0 THEN 1 ELSE 0 END as GEX_ZScore_High,
        CASE WHEN GEX_ZScore > 2.0 THEN 1 ELSE 0 END as GEX_ZScore_VeryHigh,

        -- [ADDED from Script]: Detailed Percentile Flags
        CASE WHEN GEX_Percentile < 5 THEN 1 ELSE 0 END as GEX_Percentile_VeryLow,
        CASE WHEN GEX_Percentile < 15 THEN 1 ELSE 0 END as GEX_Percentile_Low,
        CASE WHEN GEX_Percentile > 85 THEN 1 ELSE 0 END as GEX_Percentile_High,
        CASE WHEN GEX_Percentile > 95 THEN 1 ELSE 0 END as GEX_Percentile_VeryHigh,

        -- 6. TREND FEATURES
        GEX_SMA5,
        GEX_SMA10,
        GEX_SMA20,
        CASE WHEN GEX > GEX_SMA10 THEN 1 ELSE 0 END as GEX_Above_SMA10,
        CASE WHEN GEX > GEX_SMA20 THEN 1 ELSE 0 END as GEX_Above_SMA20,
        CASE WHEN GEX_SMA5 > GEX_SMA20 THEN 1 ELSE 0 END as GEX_Trending_Up,
        GEX_PctChange,
        CASE WHEN GEX_DayChange > 0 THEN 1 ELSE 0 END as GEX_Rising,
        CASE WHEN GEX_DayChange < 0 THEN 1 ELSE 0 END as GEX_Falling,

        -- 7. VOLATILITY FEATURES
        GEX_Volatility,
        CASE WHEN GEX_Vol_Percentile > 0.75 THEN 1 ELSE 0 END as GEX_HighVolatility,
        CASE WHEN GEX_Vol_Percentile < 0.25 THEN 1 ELSE 0 END as GEX_StableRegime,

        -- 8. REGIME TRANSITION FEATURES (From Script)
        CASE WHEN GEX > 0 AND GEX_Lag1 < 0 THEN 1 ELSE 0 END as GEX_Turned_Positive,
        CASE WHEN GEX < 0 AND GEX_Lag1 > 0 THEN 1 ELSE 0 END as GEX_Turned_Negative,
        CASE WHEN Prev_GEX_ZScore < -2.0 AND GEX_ZScore > -2.0 THEN 1 ELSE 0 END as GEX_Escaped_VeryLow_Zscore,
        CASE WHEN Prev_GEX_ZScore > 2.0 AND GEX_ZScore < 2.0 THEN 1 ELSE 0 END as GEX_Escaped_VeryHigh_Zscore,

        -- 9. SWING INDICATOR FEATURES (From Script)
        SwingIndicator,
        PotentialSwingIndicator,
        CASE WHEN SwingIndicator = 'swing up' THEN 1 ELSE 0 END as Is_Swing_Up,
        CASE WHEN SwingIndicator = 'swing down' THEN 1 ELSE 0 END as Is_Swing_Down,
        CASE WHEN PotentialSwingIndicator = 'Potential swing up' THEN 1 ELSE 0 END as Is_Potential_Swing_Up,
        CASE WHEN PotentialSwingIndicator = 'Potential swing down' THEN 1 ELSE 0 END as Is_Potential_Swing_Down,
        CASE WHEN ISNULL(CAST(GEXChange AS FLOAT), 0) > 0 THEN 1 ELSE 0 END as GEXChange_Positive,
        CASE WHEN ISNULL(CAST(GEXChange AS FLOAT), 0) < 0 THEN 1 ELSE 0 END as GEXChange_Negative,

        -- 10. BIG MOVE FLAGS
        CASE WHEN GEX_PctChange < -10 THEN 1 ELSE 0 END as GEX_BigDrop,
        CASE WHEN GEX_PctChange > 10 THEN 1 ELSE 0 END as GEX_BigRise,

        -- 11. PRICE TECHNICAL ANALYSIS (From Original SP)
        Price_SMA20,
        Price_SMA50,
        CASE WHEN [Close] > Price_SMA20 THEN 1 ELSE 0 END as Price_Above_SMA20,
        CASE WHEN [Close] > Price_SMA50 THEN 1 ELSE 0 END as Price_Above_SMA50,
        CASE WHEN Price_SMA20 > Price_SMA50 THEN 1 ELSE 0 END as SMA20_Above_SMA50,
        BB_Upper,
        BB_Lower,
        CASE WHEN [Close] > BB_Upper THEN 1 ELSE 0 END as BB_Breakout_Upper,
        CASE WHEN [Close] < BB_Lower THEN 1 ELSE 0 END as BB_Breakout_Lower,
        CASE WHEN (BB_Upper - BB_Lower) = 0 THEN 0.5 ELSE ([Close] - BB_Lower) / (BB_Upper - BB_Lower) END as BB_PercentB,
        CASE WHEN Price_SMA20 = 0 THEN 0 ELSE (BB_Upper - BB_Lower) / Price_SMA20 END as BB_Bandwidth,
        MACD_Line,
        CASE WHEN (Price_SMA12 - Price_SMA26) > 0 THEN 1 ELSE 0 END as MACD_Positive,

        -- =============================================
        -- 12. COMBINED SIGNALS (Merged from Script & SP)
        -- =============================================

        -- [FROM SCRIPT]: "Best 1-2d signal"
        CASE WHEN PotentialSwingIndicator = 'Potential swing up' AND ISNULL(CAST(GEXChange AS FLOAT), 0) < 0 THEN 1 ELSE 0 END as Pot_Swing_Up_AND_Neg_GEXChange,

        -- [FROM SCRIPT]: "Best 5d signal"
        CASE WHEN GEX_ZScore < -1.5 AND PotentialSwingIndicator = 'Potential swing up' THEN 1 ELSE 0 END as Low_GEX_Z_AND_Pot_Swing_Up,

        -- [FROM SCRIPT]: "Golden Setup" (User requested specific script logic)
        CASE WHEN VIX > 20 AND RSI < 35 THEN 1 ELSE 0 END as Golden_Setup,
        CASE WHEN VIX > 20 THEN 1 ELSE 0 END as VIX_Very_High,

        -- [FROM SCRIPT]: "Negative GEX + High VIX"
        CASE WHEN GEX < 0 AND VIX > 20 THEN 1 ELSE 0 END as Negative_GEX_AND_High_VIX,

        -- [FROM SP]: Existing signals that differ or complement the above
        CASE WHEN [Close] > Price_SMA50 AND [Close] < BB_Lower THEN 1 ELSE 0 END as Setup_Trend_Dip,
        CASE WHEN GEX_Vol_Percentile < 0.2 AND ((BB_Upper - BB_Lower) / NULLIF(Price_SMA20,0)) < 0.05 THEN 1 ELSE 0 END as Setup_Dual_Squeeze,
        CASE WHEN VIX > 25 AND GEX > 0 THEN 1 ELSE 0 END as Setup_Volatility_Crush

    into #Temp_GEX_Features
	--into Analysis.GEX_Features
    FROM DerivedFeatures
    WHERE ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo
	
    -- De-duplicate / Cleanup
    delete a
	from Analysis.GEX_Features as a
    inner join #Temp_GEX_Features as b
    on a.ASXCode = b.ASXCode
    and a.ObservationDate = b.ObservationDate
	and a.ASXCode = @ASXCode

    -- Final Insert
    insert into Analysis.GEX_Features
    select *
    from #Temp_GEX_Features
	where ASXCode = @ASXCode

END
