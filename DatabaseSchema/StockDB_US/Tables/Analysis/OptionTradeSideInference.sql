-- Table: [Analysis].[OptionTradeSideInference]
--
-- Stores quote-based side classification for significant option trades.
-- This is intentionally a separate table because side inference is a
-- trade-level observation, while OptionFlowFeatures is an expiry aggregate.

CREATE TABLE [Analysis].[OptionTradeSideInference] (
    [OptionTradeID] [bigint] NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ExpiryDate] [date] NULL,
    [OptionSymbol] [varchar](200) NOT NULL,
    [SaleTime] [datetime] NULL,
    [Strike] [decimal](20,4) NULL,
    [PorC] [char](1) NULL,
    [TradePrice] [decimal](20,4) NULL,
    [TradeSize] [bigint] NULL,
    [TradeValue] [float] NULL,

    [SourceBuySellIndicator] [char](1) NULL,
    [InferredBuySellIndicator] [char](1) NULL,
    [ClassificationMethod] [varchar](30) NOT NULL,
    [InferenceConfidence] [decimal](8,6) NULL,

    [QuoteTime] [datetime] NULL,
    [QuoteBid] [decimal](20,4) NULL,
    [QuoteAsk] [decimal](20,4) NULL,
    [QuoteAgeSeconds] [int] NULL,
    [QuotePositionPct] [decimal](10,6) NULL,
    [QuoteQuality] [varchar](20) NULL,

    [MinimumTradeValue] [float] NOT NULL,
    [CalculatedDateTime] [datetime2](0) NOT NULL
        CONSTRAINT [df_analysis_optiontradesideinference_calculateddatetime] DEFAULT (sysdatetime()),

    CONSTRAINT [pk_analysis_optiontradesideinference]
        PRIMARY KEY ([OptionTradeID])
);

CREATE INDEX [ix_analysis_optiontradesideinference_stock_date_expiry]
    ON [Analysis].[OptionTradeSideInference] ([StockCode], [ObservationDate], [ExpiryDate]);

CREATE INDEX [ix_analysis_optiontradesideinference_symbol_saletime]
    ON [Analysis].[OptionTradeSideInference] ([OptionSymbol], [SaleTime]);
