-- Table: [Analysis].[OptionFlowFeatures]
-- Grain: one row per underlying, observation date, and option expiry.
-- StockCode is the canonical code used by the analysis (for example QQQ).
-- ASXCode is the source/database code (for example QQQ.US).

CREATE TABLE [Analysis].[OptionFlowFeatures] (
    [StockCode] [varchar](20) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ExpiryDate] [date] NOT NULL,
    [DaysToExpiry] [smallint] NOT NULL,

    -- Underlying context
    [UnderlyingClose] [decimal](20,4) NULL,
    [UnderlyingVWAP] [decimal](20,4) NULL,
    [UnderlyingChangePct] [decimal](12,6) NULL,
    [UnderlyingRangePct] [decimal](12,6) NULL,
    [RealizedVol20] [float] NULL,

    -- Option-chain coverage and open interest
    [OptionCount] [bigint] NULL,
    [CallOptionCount] [bigint] NULL,
    [PutOptionCount] [bigint] NULL,
    [TotalOpenInterest] [float] NULL,
    [CallOpenInterest] [float] NULL,
    [PutOpenInterest] [float] NULL,
    [TotalVolume] [float] NULL,
    [CallVolume] [float] NULL,
    [PutVolume] [float] NULL,

    -- Implied-volatility and market-implied movement
    [AverageIV] [float] NULL,
    [NearATMIV] [float] NULL,
    [NearATMCallMid] [decimal](20,6) NULL,
    [NearATMPutMid] [decimal](20,6) NULL,
    [NearATMStraddleMid] [decimal](20,6) NULL,
    [ImpliedMovePct] [float] NULL,

    -- Gamma and vega exposure. PutGammaExposure follows the existing
    -- convention in Transform.GammaWall and is negative before netting.
    [CallGammaExposure] [float] NULL,
    [PutGammaExposure] [float] NULL,
    [NetGammaExposure] [float] NULL,
    [AbsoluteGammaExposure] [float] NULL,
    [GammaConcentrationPct] [float] NULL,
    [MaxAbsGammaStrike] [decimal](20,4) NULL,
    [MaxPositiveGammaStrike] [decimal](20,4) NULL,
    [MaxNegativeGammaStrike] [decimal](20,4) NULL,
    [CallVegaExposure] [float] NULL,
    [PutVegaExposure] [float] NULL,
    [TotalVegaExposure] [float] NULL,

    -- Daily total GEX context from StockData.v_CalculatedGEXPlus_V2.
    -- These values repeat for each expiry on the same underlying/date.
    [DailyTotalGEX] [float] NULL,
    [DailyGEXChangePct] [float] NULL,

    -- Trade-flow aggregates
    [TradeCount] [bigint] NULL,
    [CallTradeCount] [bigint] NULL,
    [PutTradeCount] [bigint] NULL,
    [ContractsTraded] [float] NULL,
    [CallContractsTraded] [float] NULL,
    [PutContractsTraded] [float] NULL,
    [TradePremium] [float] NULL,
    [CallTradePremium] [float] NULL,
    [PutTradePremium] [float] NULL,
    [KnownBuyPremium] [float] NULL,
    [KnownSellPremium] [float] NULL,
    [BuyCallPremium] [float] NULL,
    [SellCallPremium] [float] NULL,
    [BuyPutPremium] [float] NULL,
    [SellPutPremium] [float] NULL,
    [KnownBuyContracts] [float] NULL,
    [KnownSellContracts] [float] NULL,
    [TradeSideKnownPct] [float] NULL,

    -- Quote-based trade-side inference. These are populated by
    -- Analysis.OptionTradeSideInference when that process has been run.
    [InferredBuyPremium] [float] NULL,
    [InferredSellPremium] [float] NULL,
    [InferredBuyCallPremium] [float] NULL,
    [InferredSellCallPremium] [float] NULL,
    [InferredBuyPutPremium] [float] NULL,
    [InferredSellPutPremium] [float] NULL,
    [InferredBuyContracts] [float] NULL,
    [InferredSellContracts] [float] NULL,
    [TradeSideInferenceCoveragePct] [float] NULL,
    [TradeSideClassificationMethod] [varchar](40) NULL,

    -- Derived scores. These deliberately remain separate rather than being
    -- collapsed into one bullish/bearish label.
    [DirectionalFlowScore] [float] NULL,
    [BullishFlowScore] [float] NULL,
    [BearishFlowScore] [float] NULL,
    [LongVolatilityScore] [float] NULL,
    [ShortVolatilityScore] [float] NULL,
    [PinScore] [float] NULL,
    [RangeScore] [float] NULL,
    [FlowQualityScore] [float] NULL,

    -- Coverage and lineage
    [QuoteCoveragePct] [float] NULL,
    [GreeksCoveragePct] [float] NULL,
    [OptionChainAvailable] [bit] NOT NULL,
    [FeatureStatus] [varchar](20) NOT NULL,
    [SourceDelayedQuoteDate] [date] NULL,
    [FeatureVersion] [varchar](30) NOT NULL,
    [CalculatedDateTime] [datetime2](0) NOT NULL
        CONSTRAINT [df_analysis_optionflowfeatures_calculateddatetime] DEFAULT (sysdatetime()),

    CONSTRAINT [pk_analysis_optionflowfeatures]
        PRIMARY KEY ([StockCode], [ObservationDate], [ExpiryDate])
);

CREATE INDEX [ix_analysis_optionflowfeatures_asxcode_observationdate]
    ON [Analysis].[OptionFlowFeatures] ([ASXCode], [ObservationDate], [ExpiryDate]);

CREATE INDEX [ix_analysis_optionflowfeatures_stockcode_expirydate]
    ON [Analysis].[OptionFlowFeatures] ([StockCode], [ExpiryDate], [ObservationDate]);
