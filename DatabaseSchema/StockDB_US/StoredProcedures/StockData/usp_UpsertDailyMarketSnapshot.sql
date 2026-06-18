-- Stored procedure: [StockData].[usp_UpsertDailyMarketSnapshot]

-- Stored procedure: [StockData].[usp_UpsertDailyMarketSnapshot]

CREATE   PROCEDURE [StockData].[usp_UpsertDailyMarketSnapshot]
    @pvchASXCode varchar(20),
    @pdtObservationDate date,
    @pdtCaptureDateTime datetime2(0),
    @ptintMarketDataType tinyint = NULL,
    @pdecLastPrice decimal(20,6) = NULL,
    @pdecImpliedVolatility decimal(18,8) = NULL,
    @pdecHistoricalVolatility decimal(18,8) = NULL,
    @pdecLow13Week decimal(20,6) = NULL,
    @pdecHigh13Week decimal(20,6) = NULL,
    @pdecLow26Week decimal(20,6) = NULL,
    @pdecHigh26Week decimal(20,6) = NULL,
    @pdecLow52Week decimal(20,6) = NULL,
    @pdecHigh52Week decimal(20,6) = NULL,
    @pbintAverageVolume90Day bigint = NULL,
    @pbintShortableShares bigint = NULL,
    @pdecDividendPast12Months decimal(20,8) = NULL,
    @pdecDividendNext12Months decimal(20,8) = NULL,
    @pdtNextDividendDate date = NULL,
    @pdecNextDividendAmount decimal(20,8) = NULL,
    @pdecDividendYieldPercent decimal(12,6) = NULL,
    @pbintCallVolume bigint = NULL,
    @pbintPutVolume bigint = NULL,
    @pbintCallOpenInterest bigint = NULL,
    @pbintPutOpenInterest bigint = NULL,
    @pbintAverageOptionVolume bigint = NULL,
    @pdecPutCallVolumeRatio decimal(18,8) = NULL,
    @pdecPutCallOpenInterestRatio decimal(18,8) = NULL,
    @pdecTrailingPE decimal(20,8) = NULL,
    @pdecForwardEPS decimal(20,8) = NULL,
    @pdecForwardPE decimal(20,8) = NULL,
    @pdecMarketCap decimal(28,6) = NULL,
    @pdecBeta decimal(20,8) = NULL,
    @pdecPriceToBook decimal(20,8) = NULL,
    @pdecPayoutRatio decimal(20,8) = NULL,
    @pdecReturnOnEquity decimal(20,8) = NULL,
    @pdecReturnOnAssets decimal(20,8) = NULL,
    @pdecReturnOnInvestment decimal(20,8) = NULL,
    @pdecDebtToEquity decimal(20,8) = NULL,
    @pdecRevenueGrowth decimal(20,8) = NULL,
    @pdecEPSGrowth decimal(20,8) = NULL,
    @pdecFreeCashFlow decimal(28,6) = NULL,
    @pnvchFundamentalRatiosJson nvarchar(max) = NULL,
    @pnvchDividendJson nvarchar(max) = NULL,
    @pvchCollectionStatus varchar(20),
    @pnvchErrorMessage nvarchar(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IVRank252 decimal(9,4);
    DECLARE @IVPercentile252 decimal(9,4);
    DECLARE @IVHistoryCount smallint;

    ;WITH RecentIV AS
    (
        SELECT TOP (252) IVClose
        FROM StockData.UnderlyingVolatilityHistory
        WHERE ASXCode = UPPER(@pvchASXCode)
          AND ObservationDate <= @pdtObservationDate
          AND IVClose IS NOT NULL
        ORDER BY ObservationDate DESC
    )
    SELECT
        @IVHistoryCount = COUNT(*),
        @IVRank252 = CASE
            WHEN @pdecImpliedVolatility IS NULL OR MAX(IVClose) = MIN(IVClose) THEN NULL
            ELSE 100.0 * (@pdecImpliedVolatility - MIN(IVClose)) / NULLIF(MAX(IVClose) - MIN(IVClose), 0)
        END,
        @IVPercentile252 = CASE
            WHEN @pdecImpliedVolatility IS NULL OR COUNT(*) = 0 THEN NULL
            ELSE 100.0 * SUM(CASE WHEN IVClose < @pdecImpliedVolatility THEN 1.0 ELSE 0.0 END) / COUNT(*)
        END
    FROM RecentIV;

    MERGE StockData.DailyMarketSnapshot WITH (HOLDLOCK) AS target
    USING (SELECT UPPER(@pvchASXCode) AS ASXCode, @pdtObservationDate AS ObservationDate) AS source
       ON target.ASXCode = source.ASXCode
      AND target.ObservationDate = source.ObservationDate
    WHEN MATCHED THEN UPDATE SET
        CaptureDateTime = @pdtCaptureDateTime,
        MarketDataType = @ptintMarketDataType,
        LastPrice = @pdecLastPrice,
        ImpliedVolatility = @pdecImpliedVolatility,
        HistoricalVolatility = @pdecHistoricalVolatility,
        IVRank252 = @IVRank252,
        IVPercentile252 = @IVPercentile252,
        IVHistoryCount = @IVHistoryCount,
        Low13Week = @pdecLow13Week, High13Week = @pdecHigh13Week,
        Low26Week = @pdecLow26Week, High26Week = @pdecHigh26Week,
        Low52Week = @pdecLow52Week, High52Week = @pdecHigh52Week,
        AverageVolume90Day = @pbintAverageVolume90Day,
        ShortableShares = @pbintShortableShares,
        DividendPast12Months = @pdecDividendPast12Months,
        DividendNext12Months = @pdecDividendNext12Months,
        NextDividendDate = @pdtNextDividendDate,
        NextDividendAmount = @pdecNextDividendAmount,
        DividendYieldPercent = @pdecDividendYieldPercent,
        CallVolume = @pbintCallVolume, PutVolume = @pbintPutVolume,
        CallOpenInterest = @pbintCallOpenInterest, PutOpenInterest = @pbintPutOpenInterest,
        AverageOptionVolume = @pbintAverageOptionVolume,
        PutCallVolumeRatio = @pdecPutCallVolumeRatio,
        PutCallOpenInterestRatio = @pdecPutCallOpenInterestRatio,
        TrailingPE = @pdecTrailingPE, ForwardEPS = @pdecForwardEPS, ForwardPE = @pdecForwardPE,
        MarketCap = @pdecMarketCap, Beta = @pdecBeta, PriceToBook = @pdecPriceToBook,
        PayoutRatio = @pdecPayoutRatio,
        ReturnOnEquity = @pdecReturnOnEquity, ReturnOnAssets = @pdecReturnOnAssets,
        ReturnOnInvestment = @pdecReturnOnInvestment, DebtToEquity = @pdecDebtToEquity,
        RevenueGrowth = @pdecRevenueGrowth, EPSGrowth = @pdecEPSGrowth,
        FreeCashFlow = @pdecFreeCashFlow,
        FundamentalRatiosJson = @pnvchFundamentalRatiosJson,
        DividendJson = @pnvchDividendJson,
        CollectionStatus = @pvchCollectionStatus,
        ErrorMessage = @pnvchErrorMessage,
        ModifyDate = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (
        ASXCode, ObservationDate, CaptureDateTime, MarketDataType, LastPrice,
        ImpliedVolatility, HistoricalVolatility, IVRank252, IVPercentile252, IVHistoryCount,
        Low13Week, High13Week, Low26Week, High26Week, Low52Week, High52Week,
        AverageVolume90Day, ShortableShares,
        DividendPast12Months, DividendNext12Months, NextDividendDate, NextDividendAmount, DividendYieldPercent,
        CallVolume, PutVolume, CallOpenInterest, PutOpenInterest, AverageOptionVolume,
        PutCallVolumeRatio, PutCallOpenInterestRatio,
        TrailingPE, ForwardEPS, ForwardPE, MarketCap, Beta, PriceToBook, PayoutRatio,
        ReturnOnEquity, ReturnOnAssets, ReturnOnInvestment, DebtToEquity,
        RevenueGrowth, EPSGrowth, FreeCashFlow,
        FundamentalRatiosJson, DividendJson, CollectionStatus, ErrorMessage
    ) VALUES (
        UPPER(@pvchASXCode), @pdtObservationDate, @pdtCaptureDateTime, @ptintMarketDataType, @pdecLastPrice,
        @pdecImpliedVolatility, @pdecHistoricalVolatility, @IVRank252, @IVPercentile252, @IVHistoryCount,
        @pdecLow13Week, @pdecHigh13Week, @pdecLow26Week, @pdecHigh26Week, @pdecLow52Week, @pdecHigh52Week,
        @pbintAverageVolume90Day, @pbintShortableShares,
        @pdecDividendPast12Months, @pdecDividendNext12Months, @pdtNextDividendDate,
        @pdecNextDividendAmount, @pdecDividendYieldPercent,
        @pbintCallVolume, @pbintPutVolume, @pbintCallOpenInterest, @pbintPutOpenInterest,
        @pbintAverageOptionVolume, @pdecPutCallVolumeRatio, @pdecPutCallOpenInterestRatio,
        @pdecTrailingPE, @pdecForwardEPS, @pdecForwardPE, @pdecMarketCap, @pdecBeta,
        @pdecPriceToBook, @pdecPayoutRatio, @pdecReturnOnEquity, @pdecReturnOnAssets,
        @pdecReturnOnInvestment, @pdecDebtToEquity, @pdecRevenueGrowth, @pdecEPSGrowth,
        @pdecFreeCashFlow, @pnvchFundamentalRatiosJson, @pnvchDividendJson,
        @pvchCollectionStatus, @pnvchErrorMessage
    );
END;
