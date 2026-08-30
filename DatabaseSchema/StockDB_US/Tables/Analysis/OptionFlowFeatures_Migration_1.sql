-- Migration: extend Analysis.OptionFlowFeatures after the initial v1.0-sql
-- table has been created.

IF COL_LENGTH('Analysis.OptionFlowFeatures', 'InferredBuyPremium') IS NULL
    ALTER TABLE [Analysis].[OptionFlowFeatures] ADD
        [InferredBuyPremium] [float] NULL,
        [InferredSellPremium] [float] NULL,
        [InferredBuyCallPremium] [float] NULL,
        [InferredSellCallPremium] [float] NULL,
        [InferredBuyPutPremium] [float] NULL,
        [InferredSellPutPremium] [float] NULL,
        [InferredBuyContracts] [float] NULL,
        [InferredSellContracts] [float] NULL,
        [TradeSideInferenceCoveragePct] [float] NULL,
        [TradeSideClassificationMethod] [varchar](40) NULL;

IF COL_LENGTH('Analysis.OptionFlowFeatures', 'OptionChainAvailable') IS NULL
    ALTER TABLE [Analysis].[OptionFlowFeatures] ADD
        [OptionChainAvailable] [bit] NOT NULL
            CONSTRAINT [df_analysis_optionflowfeatures_optionchainavailable] DEFAULT (0),
        [FeatureStatus] [varchar](20) NOT NULL
            CONSTRAINT [df_analysis_optionflowfeatures_featurestatus] DEFAULT ('UNKNOWN'),
        [SourceDelayedQuoteDate] [date] NULL;

EXEC sys.sp_executesql N'
UPDATE f
SET
    OptionChainAvailable = CASE WHEN ISNULL(OptionCount, 0) > 0 THEN 1 ELSE 0 END,
    FeatureStatus = CASE WHEN ISNULL(OptionCount, 0) > 0 THEN ''FULL_CHAIN'' ELSE ''TRADE_ONLY'' END,
    SourceDelayedQuoteDate = CASE WHEN ISNULL(OptionCount, 0) > 0 THEN ObservationDate ELSE NULL END
FROM [Analysis].[OptionFlowFeatures] AS f;';
