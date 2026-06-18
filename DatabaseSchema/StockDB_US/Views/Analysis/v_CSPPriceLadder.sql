-- View: [Analysis].[v_CSPPriceLadder]



CREATE VIEW [Analysis].[v_CSPPriceLadder] AS
WITH PredictionData AS (
    SELECT
        RecommendationID,
        ObservationDate,
        TradingDate,
        Rank,
        Ticker,
        OptionSymbol,
        Strike,
        Expiry,
        DTE,
        CurrentPrice,
        PremiumMid,
		PutWallLevel,
		PutWallConfidence,
        EffectiveEntry,
		BufferPct*100.0 as BufferPct,
        AnnualizedYield,
        CompositeScore,
        PricePredictions
    FROM [Analysis].[CSPRecommendations]
),
BestOptionPerTicker AS (
    SELECT
        ObservationDate,
        Ticker,
        OptionSymbol,
        DENSE_RANK() OVER (PARTITION BY ObservationDate ORDER BY Rank) as NormalizedRank
    FROM (
        SELECT
            ObservationDate,
            Ticker,
            OptionSymbol,
            Rank,
            ROW_NUMBER() OVER (PARTITION BY ObservationDate, Ticker ORDER BY Rank) as rn
        FROM (SELECT DISTINCT ObservationDate, Ticker, OptionSymbol, Rank FROM PredictionData) pd
    ) ranked
    WHERE rn = 1
),
UnpivotedData AS (
    SELECT
        RecommendationID,
        ObservationDate,
        TradingDate,
        Rank,
        Ticker,
        OptionSymbol,
        Strike,
        Expiry,
        DTE,
        CurrentPrice,
        PremiumMid,
		PutWallLevel,
		PutWallConfidence,
        EffectiveEntry,
		BufferPct,
        AnnualizedYield,
        CompositeScore,
        1 as Priority,
        CAST(JSON_VALUE(PricePredictions, '$[0].target_underlying') AS DECIMAL(18,2)) as TargetPrice,
        CAST(JSON_VALUE(PricePredictions, '$[0].conservative') AS DECIMAL(18,2)) as STOLimitPrice,
        CAST(JSON_VALUE(PricePredictions, '$[0].base_case') AS DECIMAL(18,2)) as BaseCase,
        CAST(JSON_VALUE(PricePredictions, '$[0].optimistic') AS DECIMAL(18,2)) as Optimistic,
        CAST(JSON_VALUE(PricePredictions, '$[0].adjusted_iv') AS DECIMAL(18,6)) as IV_Decimal,
        CAST(JSON_VALUE(PricePredictions, '$[0].adjusted_iv') AS DECIMAL(18,4)) * 100 as IV_Pct,
        JSON_VALUE(PricePredictions, '$[0].confidence') as Confidence,
        CASE WHEN 1 = 1 THEN 0.40 END as Allocation
    FROM PredictionData
    WHERE JSON_VALUE(PricePredictions, '$[0].target_underlying') IS NOT NULL

    UNION ALL

    SELECT
        RecommendationID,
        ObservationDate,
        TradingDate,
        Rank,
        Ticker,
        OptionSymbol,
        Strike,
        Expiry,
        DTE,
        CurrentPrice,
        PremiumMid,
		PutWallLevel,
		PutWallConfidence,
        EffectiveEntry,
		BufferPct,
        AnnualizedYield,
        CompositeScore,
        2 as Priority,
        CAST(JSON_VALUE(PricePredictions, '$[1].target_underlying') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[1].conservative') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[1].base_case') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[1].optimistic') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[1].adjusted_iv') AS DECIMAL(18,6)),
        CAST(JSON_VALUE(PricePredictions, '$[1].adjusted_iv') AS DECIMAL(18,4)) * 100,
        JSON_VALUE(PricePredictions, '$[1].confidence'),
        CASE WHEN 1 = 1 THEN 0.35 END
    FROM PredictionData
    WHERE JSON_VALUE(PricePredictions, '$[1].target_underlying') IS NOT NULL

    UNION ALL

    SELECT
        RecommendationID,
        ObservationDate,
        TradingDate,
        Rank,
        Ticker,
        OptionSymbol,
        Strike,
        Expiry,
        DTE,
        CurrentPrice,
        PremiumMid,
		PutWallLevel,
		PutWallConfidence,
        EffectiveEntry,
		BufferPct,
        AnnualizedYield,
        CompositeScore,
        3 as Priority,
        CAST(JSON_VALUE(PricePredictions, '$[2].target_underlying') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[2].conservative') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[2].base_case') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[2].optimistic') AS DECIMAL(18,2)),
        CAST(JSON_VALUE(PricePredictions, '$[2].adjusted_iv') AS DECIMAL(18,6)),
        CAST(JSON_VALUE(PricePredictions, '$[2].adjusted_iv') AS DECIMAL(18,4)) * 100,
        JSON_VALUE(PricePredictions, '$[2].confidence'),
        CASE WHEN 1 = 1 THEN 0.25 END
    FROM PredictionData
    WHERE JSON_VALUE(PricePredictions, '$[2].target_underlying') IS NOT NULL
)
SELECT
    u.RecommendationID,
    u.ObservationDate,
    u.TradingDate,
    u.Rank,
    u.Ticker,
    u.OptionSymbol,
    u.Strike,
    u.Expiry,
    u.DTE,
    u.CurrentPrice,
    u.PremiumMid,
	u.PutWallLevel,
	u.PutWallConfidence,
    u.EffectiveEntry,
	u.BufferPct,
    u.AnnualizedYield,
    u.CompositeScore,
    u.Priority,
    u.TargetPrice,
    u.STOLimitPrice,
    u.BaseCase,
    u.Optimistic,
    u.IV_Decimal,
    u.IV_Pct,
    u.Confidence,
    u.Allocation,
    b.NormalizedRank
FROM UnpivotedData u
LEFT JOIN BestOptionPerTicker b
    ON u.ObservationDate = b.ObservationDate
    AND u.Ticker = b.Ticker
    AND u.OptionSymbol = b.OptionSymbol;
