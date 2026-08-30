-- Stored procedure: [Analysis].[usp_RefreshOptionFlowFeatures]
--
-- Purpose:
--   Populate Analysis.OptionFlowFeatures directly from SQL Server option and
--   price data. The table grain is one row per StockCode, observation date,
--   and expiry date. This is deliberately a feature extraction procedure;
--   calibrated pin/range/volatility probabilities should be added only after
--   an out-of-sample backtest.
--
-- Example:
--   EXEC Analysis.usp_RefreshOptionFlowFeatures
--        @StockCode = 'QQQ',
--        @ObservationDateFrom = '2026-07-01',
--        @ObservationDateTo = '2026-08-28';

CREATE OR ALTER PROCEDURE [Analysis].[usp_RefreshOptionFlowFeatures]
    @StockCode varchar(20),
    @ObservationDateFrom date = NULL,
    @ObservationDateTo date = NULL,
    @ASXCode varchar(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CanonicalStockCode varchar(20) = UPPER(LTRIM(RTRIM(@StockCode)));
    DECLARE @ResolvedASXCode varchar(10);

    IF RIGHT(@CanonicalStockCode, 3) = '.US'
        SET @CanonicalStockCode = LEFT(@CanonicalStockCode, LEN(@CanonicalStockCode) - 3);

    IF NULLIF(@CanonicalStockCode, '') IS NULL
        THROW 50001, 'StockCode is required.', 1;

    SET @ResolvedASXCode = UPPER(NULLIF(LTRIM(RTRIM(@ASXCode)), ''));
    IF @ResolvedASXCode IS NULL
        SET @ResolvedASXCode = @CanonicalStockCode + '.US';

    IF @ObservationDateTo IS NULL
    BEGIN
        SELECT @ObservationDateTo = MAX(ObservationDate)
        FROM StockData.PriceHistory
        WHERE ASXCode = @ResolvedASXCode;
    END;

    IF @ObservationDateTo IS NULL
        THROW 50002, 'No underlying price history was found for ASXCode.', 1;

    IF @ObservationDateFrom IS NULL
        SET @ObservationDateFrom = DATEADD(day, -30, @ObservationDateTo);

    IF @ObservationDateFrom > @ObservationDateTo
        THROW 50003, 'ObservationDateFrom must not be after ObservationDateTo.', 1;

    -- Rebuild the requested slice. Source tables are not modified.
    DELETE FROM Analysis.OptionFlowFeatures
    WHERE StockCode = @CanonicalStockCode
      AND ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo;

    ;WITH PriceWithLag AS
    (
        SELECT
            p.ASXCode,
            p.ObservationDate,
            p.[Open],
            p.High,
            p.Low,
            p.[Close],
            p.VWAP,
            LAG(p.[Close]) OVER
                (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS PrevClose
        FROM StockData.PriceHistory AS p
        WHERE p.ASXCode = @ResolvedASXCode
          AND p.ObservationDate BETWEEN DATEADD(day, -60, @ObservationDateFrom)
                                     AND @ObservationDateTo
    ),
    PriceFeatures AS
    (
        SELECT
            p.*,
            CASE
                WHEN p.PrevClose IS NULL OR p.PrevClose <= 0 THEN NULL
                ELSE (p.[Close] - p.PrevClose) * 100.0 / p.PrevClose
            END AS UnderlyingChangePct,
            CASE
                WHEN p.[Close] IS NULL OR p.[Close] = 0 THEN NULL
                ELSE (p.High - p.Low) * 100.0 / p.[Close]
            END AS UnderlyingRangePct,
            CASE
                WHEN p.[Close] > 0 AND p.PrevClose > 0
                THEN STDEV(LOG(p.[Close] / p.PrevClose)) OVER
                    (PARTITION BY p.ASXCode ORDER BY p.ObservationDate
                     ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) * SQRT(252.0)
                ELSE NULL
            END AS RealizedVol20
        FROM PriceWithLag AS p
    ),
    DelayedBase AS
    (
        SELECT
            d.ASXCode,
            d.ObservationDate,
            d.OptionSymbol,
            d.ExpiryDate,
            d.Strike,
            d.PorC,
            d.Bid,
            d.Ask,
            d.IV,
            d.OpenInterest,
            d.Volume,
            d.Delta,
            d.Gamma,
            d.Vega,
            p.[Close] AS UnderlyingClose,
            p.VWAP AS UnderlyingVWAP
        FROM StockData.v_OptionDelayedQuote_V2 AS d
        INNER JOIN PriceFeatures AS p
            ON p.ASXCode = d.ASXCode
           AND p.ObservationDate = d.ObservationDate
        WHERE d.ASXCode = @ResolvedASXCode
          AND d.ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo
          AND d.ExpiryDate >= d.ObservationDate
          AND d.ExpiryDate <= DATEADD(day, 180, d.ObservationDate)
          AND d.Strike IS NOT NULL
    ),
    DelayedRanked AS
    (
        SELECT
            d.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY d.ObservationDate, d.ExpiryDate, d.PorC
                ORDER BY ABS(d.Strike - d.UnderlyingClose), d.OptionSymbol
            ) AS NearATMRank
        FROM DelayedBase AS d
    ),
    DelayedAgg AS
    (
        SELECT
            ObservationDate,
            ExpiryDate,
            COUNT_BIG(*) AS OptionCount,
            SUM(CAST(CASE WHEN PorC = 'C' THEN 1 ELSE 0 END AS bigint)) AS CallOptionCount,
            SUM(CAST(CASE WHEN PorC = 'P' THEN 1 ELSE 0 END AS bigint)) AS PutOptionCount,
            SUM(CONVERT(float, ISNULL(OpenInterest, 0))) AS TotalOpenInterest,
            SUM(CONVERT(float, CASE WHEN PorC = 'C' THEN ISNULL(OpenInterest, 0) ELSE 0 END)) AS CallOpenInterest,
            SUM(CONVERT(float, CASE WHEN PorC = 'P' THEN ISNULL(OpenInterest, 0) ELSE 0 END)) AS PutOpenInterest,
            SUM(CONVERT(float, ISNULL(Volume, 0))) AS TotalVolume,
            SUM(CONVERT(float, CASE WHEN PorC = 'C' THEN ISNULL(Volume, 0) ELSE 0 END)) AS CallVolume,
            SUM(CONVERT(float, CASE WHEN PorC = 'P' THEN ISNULL(Volume, 0) ELSE 0 END)) AS PutVolume,
            AVG(NULLIF(CONVERT(float, IV), 0)) AS AverageIV,
            AVG(CASE WHEN Bid IS NOT NULL AND Ask IS NOT NULL THEN 100.0 ELSE 0.0 END) AS QuoteCoveragePct,
            AVG(CASE WHEN IV IS NOT NULL AND Delta IS NOT NULL AND Gamma IS NOT NULL AND Vega IS NOT NULL
                     THEN 100.0 ELSE 0.0 END) AS GreeksCoveragePct
        FROM DelayedBase
        GROUP BY ObservationDate, ExpiryDate
    ),
    NearATM AS
    (
        SELECT
            ObservationDate,
            ExpiryDate,
            MAX(CASE WHEN PorC = 'C' AND NearATMRank = 1 THEN CONVERT(decimal(20,6), (Bid + Ask) / 2.0) END) AS NearATMCallMid,
            MAX(CASE WHEN PorC = 'P' AND NearATMRank = 1 THEN CONVERT(decimal(20,6), (Bid + Ask) / 2.0) END) AS NearATMPutMid,
            MAX(CASE WHEN PorC = 'C' AND NearATMRank = 1 THEN CONVERT(float, IV) END) AS NearATMCallIV,
            MAX(CASE WHEN PorC = 'P' AND NearATMRank = 1 THEN CONVERT(float, IV) END) AS NearATMPutIV
        FROM DelayedRanked
        WHERE NearATMRank = 1
          AND Bid IS NOT NULL
          AND Ask IS NOT NULL
        GROUP BY ObservationDate, ExpiryDate
    ),
    GammaByStrike AS
    (
        SELECT
            ObservationDate,
            ExpiryDate,
            Strike,
            SUM(CONVERT(float, CASE WHEN PorC = 'C' THEN ISNULL(OpenInterest, 0) * ISNULL(Gamma, 0) * 100.0 ELSE 0 END)) AS CallGammaExposure,
            SUM(CONVERT(float, CASE WHEN PorC = 'P' THEN -ISNULL(OpenInterest, 0) * ISNULL(Gamma, 0) * 100.0 ELSE 0 END)) AS PutGammaExposure
        FROM DelayedBase
        GROUP BY ObservationDate, ExpiryDate, Strike
    ),
    GammaByStrikeWithNet AS
    (
        SELECT
            g.*,
            g.CallGammaExposure + g.PutGammaExposure AS NetGammaExposure
        FROM GammaByStrike AS g
    ),
    GammaRanked AS
    (
        SELECT
            g.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY ObservationDate, ExpiryDate
                ORDER BY ABS(NetGammaExposure) DESC, Strike
            ) AS MaxAbsRank,
            ROW_NUMBER() OVER
            (
                PARTITION BY ObservationDate, ExpiryDate
                ORDER BY CASE WHEN NetGammaExposure > 0 THEN 0 ELSE 1 END,
                         NetGammaExposure DESC, Strike
            ) AS MaxPositiveRank,
            ROW_NUMBER() OVER
            (
                PARTITION BY ObservationDate, ExpiryDate
                ORDER BY CASE WHEN NetGammaExposure < 0 THEN 0 ELSE 1 END,
                         NetGammaExposure ASC, Strike
            ) AS MaxNegativeRank
        FROM GammaByStrikeWithNet AS g
    ),
    GammaAgg AS
    (
        SELECT
            ObservationDate,
            ExpiryDate,
            SUM(CallGammaExposure) AS CallGammaExposure,
            SUM(PutGammaExposure) AS PutGammaExposure,
            SUM(NetGammaExposure) AS NetGammaExposure,
            SUM(ABS(NetGammaExposure)) AS AbsoluteGammaExposure,
            MAX(ABS(NetGammaExposure)) AS MaxAbsGamma,
            SUM(CONVERT(float, CASE WHEN NetGammaExposure > 0 THEN NetGammaExposure ELSE 0 END)) AS PositiveGamma,
            SUM(CONVERT(float, CASE WHEN NetGammaExposure < 0 THEN ABS(NetGammaExposure) ELSE 0 END)) AS NegativeGamma
        FROM GammaByStrikeWithNet
        GROUP BY ObservationDate, ExpiryDate
    ),
    GammaPicks AS
    (
        SELECT
            ObservationDate,
            ExpiryDate,
            MAX(CASE WHEN MaxAbsRank = 1 THEN Strike END) AS MaxAbsGammaStrike,
            MAX(CASE WHEN MaxPositiveRank = 1 AND NetGammaExposure > 0 THEN Strike END) AS MaxPositiveGammaStrike,
            MAX(CASE WHEN MaxNegativeRank = 1 AND NetGammaExposure < 0 THEN Strike END) AS MaxNegativeGammaStrike
        FROM GammaRanked
        GROUP BY ObservationDate, ExpiryDate
    ),
    VegaAgg AS
    (
        SELECT
            ObservationDate,
            ExpiryDate,
            SUM(CONVERT(float, CASE WHEN PorC = 'C' THEN ISNULL(OpenInterest, 0) * ISNULL(Vega, 0) * 100.0 ELSE 0 END)) AS CallVegaExposure,
            SUM(CONVERT(float, CASE WHEN PorC = 'P' THEN ISNULL(OpenInterest, 0) * ISNULL(Vega, 0) * 100.0 ELSE 0 END)) AS PutVegaExposure
        FROM DelayedBase
        GROUP BY ObservationDate, ExpiryDate
    ),
    TradeAgg AS
    (
        SELECT
            t.ObservationDateLocal AS ObservationDate,
            t.ExpiryDate,
            COUNT_BIG(*) AS TradeCount,
            SUM(CAST(CASE WHEN t.PorC = 'C' THEN 1 ELSE 0 END AS bigint)) AS CallTradeCount,
            SUM(CAST(CASE WHEN t.PorC = 'P' THEN 1 ELSE 0 END AS bigint)) AS PutTradeCount,
            SUM(CONVERT(float, ISNULL(t.Size, 0))) AS ContractsTraded,
            SUM(CONVERT(float, CASE WHEN t.PorC = 'C' THEN ISNULL(t.Size, 0) ELSE 0 END)) AS CallContractsTraded,
            SUM(CONVERT(float, CASE WHEN t.PorC = 'P' THEN ISNULL(t.Size, 0) ELSE 0 END)) AS PutContractsTraded,
            SUM(CONVERT(float, ISNULL(t.Price, 0)) * CONVERT(float, ISNULL(t.Size, 0)) * 100.0) AS TradePremium,
            SUM(CONVERT(float, CASE WHEN t.PorC = 'C' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS CallTradePremium,
            SUM(CONVERT(float, CASE WHEN t.PorC = 'P' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS PutTradePremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'B' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS KnownBuyPremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'S' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS KnownSellPremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'B' AND t.PorC = 'C' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS BuyCallPremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'S' AND t.PorC = 'C' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS SellCallPremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'B' AND t.PorC = 'P' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS BuyPutPremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'S' AND t.PorC = 'P' THEN ISNULL(t.Price, 0) * ISNULL(t.Size, 0) * 100.0 ELSE 0 END)) AS SellPutPremium,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'B' THEN ISNULL(t.Size, 0) ELSE 0 END)) AS KnownBuyContracts,
            SUM(CONVERT(float, CASE WHEN t.BuySellIndicator = 'S' THEN ISNULL(t.Size, 0) ELSE 0 END)) AS KnownSellContracts
        FROM StockData.OptionTrade AS t
        WHERE t.ASXCode = @ResolvedASXCode
          AND t.ObservationDateLocal BETWEEN @ObservationDateFrom AND @ObservationDateTo
          AND t.ExpiryDate >= t.ObservationDateLocal
          AND t.ExpiryDate <= DATEADD(day, 180, t.ObservationDateLocal)
        GROUP BY t.ObservationDateLocal, t.ExpiryDate
    ),
    InferenceAgg AS
    (
        SELECT
            i.ObservationDate,
            i.ExpiryDate,
            COUNT_BIG(*) AS InferenceRowCount,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'B' THEN ISNULL(i.TradeValue, 0) ELSE 0 END)) AS InferredBuyPremium,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'S' THEN ISNULL(i.TradeValue, 0) ELSE 0 END)) AS InferredSellPremium,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'B' AND i.PorC = 'C' THEN ISNULL(i.TradeValue, 0) ELSE 0 END)) AS InferredBuyCallPremium,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'S' AND i.PorC = 'C' THEN ISNULL(i.TradeValue, 0) ELSE 0 END)) AS InferredSellCallPremium,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'B' AND i.PorC = 'P' THEN ISNULL(i.TradeValue, 0) ELSE 0 END)) AS InferredBuyPutPremium,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'S' AND i.PorC = 'P' THEN ISNULL(i.TradeValue, 0) ELSE 0 END)) AS InferredSellPutPremium,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'B' THEN ISNULL(i.TradeSize, 0) ELSE 0 END)) AS InferredBuyContracts,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator = 'S' THEN ISNULL(i.TradeSize, 0) ELSE 0 END)) AS InferredSellContracts,
            SUM(CONVERT(float, CASE WHEN i.InferredBuySellIndicator IN ('B', 'S') THEN ISNULL(i.TradeSize, 0) ELSE 0 END))
                * 100.0 / NULLIF(SUM(CONVERT(float, ISNULL(i.TradeSize, 0))), 0) AS TradeSideInferenceCoveragePct
        FROM Analysis.OptionTradeSideInference AS i
        WHERE i.StockCode = @CanonicalStockCode
          AND i.ASXCode = @ResolvedASXCode
          AND i.ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo
        GROUP BY i.ObservationDate, i.ExpiryDate
    ),
    ExpirySet AS
    (
        SELECT ObservationDate, ExpiryDate FROM DelayedAgg
        UNION
        SELECT ObservationDate, ExpiryDate FROM TradeAgg
    ),
    DailyGEX AS
    (
        SELECT
            ObservationDate,
            CONVERT(float, GEX) AS DailyTotalGEX,
            CONVERT(float, GEXChange) AS DailyGEXChangePct
        FROM StockData.v_CalculatedGEXPlus_V2
        WHERE ASXCode = @ResolvedASXCode
          AND ObservationDate BETWEEN @ObservationDateFrom AND @ObservationDateTo
    )
    INSERT INTO Analysis.OptionFlowFeatures
    (
        StockCode, ASXCode, ObservationDate, ExpiryDate, DaysToExpiry,
        UnderlyingClose, UnderlyingVWAP, UnderlyingChangePct, UnderlyingRangePct, RealizedVol20,
        OptionCount, CallOptionCount, PutOptionCount,
        TotalOpenInterest, CallOpenInterest, PutOpenInterest,
        TotalVolume, CallVolume, PutVolume,
        AverageIV, NearATMIV, NearATMCallMid, NearATMPutMid, NearATMStraddleMid, ImpliedMovePct,
        CallGammaExposure, PutGammaExposure, NetGammaExposure, AbsoluteGammaExposure,
        GammaConcentrationPct, MaxAbsGammaStrike, MaxPositiveGammaStrike, MaxNegativeGammaStrike,
        CallVegaExposure, PutVegaExposure, TotalVegaExposure,
        DailyTotalGEX, DailyGEXChangePct,
        TradeCount, CallTradeCount, PutTradeCount,
        ContractsTraded, CallContractsTraded, PutContractsTraded,
        TradePremium, CallTradePremium, PutTradePremium,
        KnownBuyPremium, KnownSellPremium, BuyCallPremium, SellCallPremium, BuyPutPremium, SellPutPremium,
        KnownBuyContracts, KnownSellContracts, TradeSideKnownPct,
        InferredBuyPremium, InferredSellPremium, InferredBuyCallPremium, InferredSellCallPremium,
        InferredBuyPutPremium, InferredSellPutPremium, InferredBuyContracts, InferredSellContracts,
        TradeSideInferenceCoveragePct, TradeSideClassificationMethod,
        DirectionalFlowScore, BullishFlowScore, BearishFlowScore,
        LongVolatilityScore, ShortVolatilityScore, PinScore, RangeScore, FlowQualityScore,
        QuoteCoveragePct, GreeksCoveragePct,
        OptionChainAvailable, FeatureStatus, SourceDelayedQuoteDate, FeatureVersion
    )
    SELECT
        @CanonicalStockCode,
        @ResolvedASXCode,
        e.ObservationDate,
        e.ExpiryDate,
        DATEDIFF(day, e.ObservationDate, e.ExpiryDate),
        p.[Close],
        p.VWAP,
        p.UnderlyingChangePct,
        p.UnderlyingRangePct,
        p.RealizedVol20,
        ISNULL(da.OptionCount, 0),
        ISNULL(da.CallOptionCount, 0),
        ISNULL(da.PutOptionCount, 0),
        ISNULL(da.TotalOpenInterest, 0),
        ISNULL(da.CallOpenInterest, 0),
        ISNULL(da.PutOpenInterest, 0),
        ISNULL(da.TotalVolume, 0),
        ISNULL(da.CallVolume, 0),
        ISNULL(da.PutVolume, 0),
        da.AverageIV,
        CASE WHEN na.NearATMCallIV IS NULL THEN na.NearATMPutIV
             WHEN na.NearATMPutIV IS NULL THEN na.NearATMCallIV
             ELSE (na.NearATMCallIV + na.NearATMPutIV) / 2.0 END,
        na.NearATMCallMid,
        na.NearATMPutMid,
        CASE WHEN na.NearATMCallMid IS NULL OR na.NearATMPutMid IS NULL THEN NULL
             ELSE na.NearATMCallMid + na.NearATMPutMid END,
        CASE WHEN p.[Close] IS NULL OR p.[Close] = 0
                  OR na.NearATMCallMid IS NULL OR na.NearATMPutMid IS NULL THEN NULL
             ELSE CONVERT(float, na.NearATMCallMid + na.NearATMPutMid) * 100.0 / p.[Close] END,
        ga.CallGammaExposure,
        ga.PutGammaExposure,
        ga.NetGammaExposure,
        ga.AbsoluteGammaExposure,
        CASE WHEN ga.AbsoluteGammaExposure = 0 THEN NULL
             ELSE ga.MaxAbsGamma * 100.0 / ga.AbsoluteGammaExposure END,
        gp.MaxAbsGammaStrike,
        gp.MaxPositiveGammaStrike,
        gp.MaxNegativeGammaStrike,
        va.CallVegaExposure,
        va.PutVegaExposure,
        CASE WHEN va.CallVegaExposure IS NULL AND va.PutVegaExposure IS NULL THEN NULL
             ELSE ISNULL(va.CallVegaExposure, 0) + ISNULL(va.PutVegaExposure, 0) END,
        dg.DailyTotalGEX,
        dg.DailyGEXChangePct,
        ISNULL(ta.TradeCount, 0),
        ISNULL(ta.CallTradeCount, 0),
        ISNULL(ta.PutTradeCount, 0),
        ISNULL(ta.ContractsTraded, 0),
        ISNULL(ta.CallContractsTraded, 0),
        ISNULL(ta.PutContractsTraded, 0),
        ISNULL(ta.TradePremium, 0),
        ISNULL(ta.CallTradePremium, 0),
        ISNULL(ta.PutTradePremium, 0),
        ISNULL(ta.KnownBuyPremium, 0),
        ISNULL(ta.KnownSellPremium, 0),
        ISNULL(ta.BuyCallPremium, 0),
        ISNULL(ta.SellCallPremium, 0),
        ISNULL(ta.BuyPutPremium, 0),
        ISNULL(ta.SellPutPremium, 0),
        ISNULL(ta.KnownBuyContracts, 0),
        ISNULL(ta.KnownSellContracts, 0),
        CASE WHEN ISNULL(ta.ContractsTraded, 0) = 0 THEN NULL
             ELSE (ISNULL(ta.KnownBuyContracts, 0) + ISNULL(ta.KnownSellContracts, 0)) * 100.0 / ta.ContractsTraded END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredBuyPremium END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredSellPremium END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredBuyCallPremium END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredSellCallPremium END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredBuyPutPremium END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredSellPutPremium END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredBuyContracts END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.InferredSellContracts END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN NULL ELSE ia.TradeSideInferenceCoveragePct END,
        CASE WHEN ia.InferenceRowCount IS NULL THEN 'source_indicator_v1' ELSE 'source_plus_quote' END,
        CASE
            WHEN COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownBuyPremium ELSE ia.InferredBuyPremium END, 0)
               + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownSellPremium ELSE ia.InferredSellPremium END, 0) = 0 THEN NULL
            ELSE (
                COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.BuyCallPremium ELSE ia.InferredBuyCallPremium END, 0)
              + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.SellPutPremium ELSE ia.InferredSellPutPremium END, 0)
              - COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.SellCallPremium ELSE ia.InferredSellCallPremium END, 0)
              - COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.BuyPutPremium ELSE ia.InferredBuyPutPremium END, 0)
            ) / (
                COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownBuyPremium ELSE ia.InferredBuyPremium END, 0)
              + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownSellPremium ELSE ia.InferredSellPremium END, 0)
            )
        END,
        CASE
            WHEN COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownBuyPremium ELSE ia.InferredBuyPremium END, 0)
               + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownSellPremium ELSE ia.InferredSellPremium END, 0) = 0 THEN NULL
            ELSE (
                COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.BuyCallPremium ELSE ia.InferredBuyCallPremium END, 0)
              + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.SellPutPremium ELSE ia.InferredSellPutPremium END, 0)
            ) / (
                COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownBuyPremium ELSE ia.InferredBuyPremium END, 0)
              + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownSellPremium ELSE ia.InferredSellPremium END, 0)
            )
        END,
        CASE
            WHEN COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownBuyPremium ELSE ia.InferredBuyPremium END, 0)
               + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownSellPremium ELSE ia.InferredSellPremium END, 0) = 0 THEN NULL
            ELSE (
                COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.SellCallPremium ELSE ia.InferredSellCallPremium END, 0)
              + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.BuyPutPremium ELSE ia.InferredBuyPutPremium END, 0)
            ) / (
                COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownBuyPremium ELSE ia.InferredBuyPremium END, 0)
              + COALESCE(CASE WHEN ia.InferenceRowCount IS NULL THEN ta.KnownSellPremium ELSE ia.InferredSellPremium END, 0)
            )
        END,
        -- These require calibrated package classification and are intentionally
        -- left NULL until the historical calibration stage is complete.
        NULL,
        NULL,
        NULL,
        NULL,
        CASE
            WHEN da.OptionCount IS NULL THEN NULL
            ELSE (ISNULL(da.QuoteCoveragePct, 0) + ISNULL(da.GreeksCoveragePct, 0)
                + ISNULL(COALESCE(ia.TradeSideInferenceCoveragePct,
                    CASE WHEN ta.ContractsTraded = 0 THEN 0
                         ELSE (ta.KnownBuyContracts + ta.KnownSellContracts) * 100.0 / ta.ContractsTraded END), 0)) / 3.0
        END,
        da.QuoteCoveragePct,
        da.GreeksCoveragePct,
        CASE WHEN da.OptionCount IS NULL THEN 0 ELSE 1 END,
        CASE WHEN da.OptionCount IS NULL THEN 'TRADE_ONLY' ELSE 'FULL_CHAIN' END,
        CASE WHEN da.OptionCount IS NULL THEN NULL ELSE e.ObservationDate END,
        'v1.1-sql'
    FROM ExpirySet AS e
    INNER JOIN PriceFeatures AS p
        ON p.ASXCode = @ResolvedASXCode
       AND p.ObservationDate = e.ObservationDate
    LEFT JOIN DelayedAgg AS da
        ON da.ObservationDate = e.ObservationDate
       AND da.ExpiryDate = e.ExpiryDate
    LEFT JOIN NearATM AS na
        ON na.ObservationDate = e.ObservationDate
       AND na.ExpiryDate = e.ExpiryDate
    LEFT JOIN GammaAgg AS ga
        ON ga.ObservationDate = e.ObservationDate
       AND ga.ExpiryDate = e.ExpiryDate
    LEFT JOIN GammaPicks AS gp
        ON gp.ObservationDate = e.ObservationDate
       AND gp.ExpiryDate = e.ExpiryDate
    LEFT JOIN VegaAgg AS va
        ON va.ObservationDate = e.ObservationDate
       AND va.ExpiryDate = e.ExpiryDate
    LEFT JOIN TradeAgg AS ta
        ON ta.ObservationDate = e.ObservationDate
       AND ta.ExpiryDate = e.ExpiryDate
    LEFT JOIN InferenceAgg AS ia
        ON ia.ObservationDate = e.ObservationDate
       AND ia.ExpiryDate = e.ExpiryDate
    LEFT JOIN DailyGEX AS dg
        ON dg.ObservationDate = e.ObservationDate;
END;
