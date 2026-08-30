-- Stored procedure: [Analysis].[usp_InferOptionTradeSide]
--
-- Classifies significant trades using the existing source indicator when it
-- exists, otherwise the nearest bid/ask quote around the trade timestamp.
-- This does not infer customer opening/closing status; it infers aggressor
-- side only (buying at the ask / selling at the bid).
--
-- Example:
--   EXEC Analysis.usp_InferOptionTradeSide
--        @StockCode = 'QQQ',
--        @ObservationDateFrom = '2026-07-01',
--        @ObservationDateTo = '2026-08-28';

CREATE OR ALTER PROCEDURE [Analysis].[usp_InferOptionTradeSide]
    @StockCode varchar(20),
    @ObservationDateFrom date,
    @ObservationDateTo date,
    @ASXCode varchar(10) = NULL,
    @MinimumTradeValue float = 20000.0,
    @MaxQuoteAgeSeconds int = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CanonicalStockCode varchar(20) = UPPER(LTRIM(RTRIM(@StockCode)));
    DECLARE @ResolvedASXCode varchar(10);

    IF RIGHT(@CanonicalStockCode, 3) = '.US'
        SET @CanonicalStockCode = LEFT(@CanonicalStockCode, LEN(@CanonicalStockCode) - 3);

    IF NULLIF(@CanonicalStockCode, '') IS NULL
        THROW 50011, 'StockCode is required.', 1;
    IF @ObservationDateFrom IS NULL OR @ObservationDateTo IS NULL
        THROW 50012, 'Observation date range is required.', 1;
    IF @ObservationDateFrom > @ObservationDateTo
        THROW 50013, 'ObservationDateFrom must not be after ObservationDateTo.', 1;
    IF @MaxQuoteAgeSeconds < 0
        THROW 50014, 'MaxQuoteAgeSeconds must not be negative.', 1;

    SET @ResolvedASXCode = UPPER(NULLIF(LTRIM(RTRIM(@ASXCode)), ''));
    IF @ResolvedASXCode IS NULL
        SET @ResolvedASXCode = @CanonicalStockCode + '.US';

    DELETE FROM Analysis.OptionTradeSideInference
    WHERE StockCode = @CanonicalStockCode
      AND ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo;

    ;WITH EligibleTrades AS
    (
        SELECT
            t.OptionTradeID,
            t.ASXCode,
            t.ObservationDateLocal AS ObservationDate,
            t.ExpiryDate,
            t.OptionSymbol,
            t.SaleTime,
            t.Strike,
            t.PorC,
            t.Price AS TradePrice,
            t.Size AS TradeSize,
            t.BuySellIndicator AS SourceBuySellIndicator
        FROM StockData.OptionTrade AS t
        WHERE t.ASXCode = @ResolvedASXCode
          AND t.ObservationDateLocal BETWEEN @ObservationDateFrom AND @ObservationDateTo
          AND t.ExpiryDate >= t.ObservationDateLocal
          AND t.ExpiryDate <= DATEADD(day, 180, t.ObservationDateLocal)
          AND CONVERT(float, ISNULL(t.Price, 0)) * CONVERT(float, ISNULL(t.Size, 0)) * 100.0 >= @MinimumTradeValue
    ),
    QuoteMatched AS
    (
        SELECT
            t.*,
            q.ObservationTime AS QuoteTime,
            q.PriceBid AS QuoteBid,
            q.PriceAsk AS QuoteAsk,
            CASE WHEN q.ObservationTime IS NULL THEN NULL
                 ELSE ABS(DATEDIFF(second, q.ObservationTime, t.SaleTime)) END AS QuoteAgeSeconds
        FROM EligibleTrades AS t
        OUTER APPLY
        (
            SELECT TOP (1)
                b.OptionBidAskID,
                b.ObservationTime,
                b.PriceBid,
                b.PriceAsk
            FROM StockData.OptionBidAsk AS b
            WHERE b.ASXCode = t.ASXCode
              AND b.OptionSymbol = t.OptionSymbol
              AND b.ObservationTime BETWEEN DATEADD(second, -@MaxQuoteAgeSeconds, t.SaleTime)
                                         AND DATEADD(second, @MaxQuoteAgeSeconds, t.SaleTime)
              AND b.PriceBid IS NOT NULL
              AND b.PriceAsk IS NOT NULL
            ORDER BY ABS(DATEDIFF(second, b.ObservationTime, t.SaleTime)),
                     b.OptionBidAskID DESC
        ) AS q
    ),
    Positioned AS
    (
        SELECT
            q.*,
            CASE
                WHEN q.QuoteBid IS NULL OR q.QuoteAsk IS NULL OR q.QuoteAsk <= q.QuoteBid THEN NULL
                ELSE (CONVERT(float, q.TradePrice) - CONVERT(float, q.QuoteBid))
                     * 100.0 / (CONVERT(float, q.QuoteAsk) - CONVERT(float, q.QuoteBid))
            END AS QuotePositionPct
        FROM QuoteMatched AS q
    ),
    Classified AS
    (
        SELECT
            p.*,
            CASE
                WHEN p.SourceBuySellIndicator IN ('B', 'S') THEN p.SourceBuySellIndicator
                WHEN p.QuoteBid IS NULL OR p.QuoteAsk IS NULL THEN NULL
                WHEN p.TradePrice >= p.QuoteAsk THEN 'B'
                WHEN p.TradePrice <= p.QuoteBid THEN 'S'
                WHEN p.QuotePositionPct >= 75.0 THEN 'B'
                WHEN p.QuotePositionPct <= 25.0 THEN 'S'
                ELSE NULL
            END AS InferredBuySellIndicator,
            CASE
                WHEN p.SourceBuySellIndicator IN ('B', 'S') THEN 'source_indicator'
                WHEN p.QuoteBid IS NULL OR p.QuoteAsk IS NULL THEN 'no_quote'
                WHEN p.TradePrice >= p.QuoteAsk OR p.TradePrice <= p.QuoteBid THEN 'quote_touch'
                WHEN p.QuotePositionPct >= 75.0 OR p.QuotePositionPct <= 25.0 THEN 'quote_edge'
                ELSE 'quote_mid_unknown'
            END AS ClassificationMethod,
            CASE
                WHEN p.SourceBuySellIndicator IN ('B', 'S') THEN CONVERT(decimal(8,6), 0.900000)
                WHEN p.QuoteBid IS NULL OR p.QuoteAsk IS NULL THEN CONVERT(decimal(8,6), 0.000000)
                WHEN p.TradePrice >= p.QuoteAsk OR p.TradePrice <= p.QuoteBid THEN CONVERT(decimal(8,6), 0.950000)
                WHEN p.QuotePositionPct >= 75.0 OR p.QuotePositionPct <= 25.0 THEN CONVERT(decimal(8,6), 0.750000)
                ELSE CONVERT(decimal(8,6), 0.250000)
            END AS InferenceConfidence,
            CASE
                WHEN p.QuoteBid IS NULL OR p.QuoteAsk IS NULL THEN 'missing'
                WHEN p.TradePrice >= p.QuoteAsk OR p.TradePrice <= p.QuoteBid THEN 'touch'
                WHEN p.QuotePositionPct >= 75.0 OR p.QuotePositionPct <= 25.0 THEN 'edge'
                ELSE 'mid'
            END AS QuoteQuality
        FROM Positioned AS p
    )
    INSERT INTO Analysis.OptionTradeSideInference
    (
        OptionTradeID, StockCode, ASXCode, ObservationDate, ExpiryDate,
        OptionSymbol, SaleTime, Strike, PorC, TradePrice, TradeSize, TradeValue,
        SourceBuySellIndicator, InferredBuySellIndicator, ClassificationMethod,
        InferenceConfidence, QuoteTime, QuoteBid, QuoteAsk, QuoteAgeSeconds,
        QuotePositionPct, QuoteQuality, MinimumTradeValue
    )
    SELECT
        OptionTradeID,
        @CanonicalStockCode,
        ASXCode,
        ObservationDate,
        ExpiryDate,
        OptionSymbol,
        SaleTime,
        Strike,
        PorC,
        TradePrice,
        TradeSize,
        CONVERT(float, ISNULL(TradePrice, 0)) * CONVERT(float, ISNULL(TradeSize, 0)) * 100.0,
        SourceBuySellIndicator,
        InferredBuySellIndicator,
        ClassificationMethod,
        InferenceConfidence,
        QuoteTime,
        QuoteBid,
        QuoteAsk,
        QuoteAgeSeconds,
        CONVERT(decimal(10,6), QuotePositionPct),
        QuoteQuality,
        @MinimumTradeValue
    FROM Classified;
END;
