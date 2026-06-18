-- Table: [Analysis].[CSPRecommendations]

CREATE TABLE [Analysis].[CSPRecommendations] (
    [RecommendationID] [bigint] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [TradingDate] [date] NOT NULL,
    [GeneratedDate] [datetime] NOT NULL,
    [Rank] [int] NOT NULL,
    [Ticker] [varchar](20) NOT NULL,
    [OptionSymbol] [varchar](50) NOT NULL,
    [Strike] [decimal](18,4) NOT NULL,
    [Expiry] [date] NOT NULL,
    [DTE] [int] NOT NULL,
    [CurrentPrice] [decimal](18,4) NOT NULL,
    [PremiumBid] [decimal](18,4) NOT NULL,
    [PremiumAsk] [decimal](18,4) NOT NULL,
    [PremiumMid] [decimal](18,4) NOT NULL,
    [Delta] [decimal](18,6) NOT NULL,
    [Gamma] [decimal](18,6) NOT NULL,
    [Theta] [decimal](18,6) NOT NULL,
    [Vega] [decimal](18,6) NOT NULL,
    [IV] [decimal](18,6) NOT NULL,
    [OpenInterest] [int] NOT NULL,
    [Volume] [int] NOT NULL,
    [SpreadPct] [decimal](18,6) NOT NULL,
    [EffectiveEntry] [decimal](18,4) NOT NULL,
    [BufferPct] [decimal](18,6) NOT NULL,
    [AnnualizedYield] [decimal](18,6) NOT NULL,
    [AssignedValue] [decimal](18,2) NOT NULL,
    [PutWallLevel] [decimal](18,4) NOT NULL,
    [PutWallConfidence] [varchar](10) NOT NULL,
    [TotalGamma] [decimal](18,2) NOT NULL,
    [BuyRangeMin] [decimal](18,4) NULL,
    [BuyRangeMax] [decimal](18,4) NULL,
    [SellRangeMin] [decimal](18,4) NULL,
    [SellRangeMax] [decimal](18,4) NULL,
    [EarningsDate] [date] NULL,
    [DaysToEarnings] [int] NULL,
    [CompositeScore] [decimal](18,2) NULL,
    [ScoreBreakdown] [nvarchar](MAX) NULL,
    [PricePredictions] [nvarchar](MAX) NULL
,
    CONSTRAINT [PK__CSPRecom__AA15BEC4067AC8F7] PRIMARY KEY (RecommendationID)
);

CREATE INDEX [IX_CSPRecommendations_ObservationDate] ON [Analysis].[CSPRecommendations] (TradingDate, Ticker, Rank, CompositeScore, ObservationDate);
CREATE INDEX [IX_CSPRecommendations_OptionSymbol] ON [Analysis].[CSPRecommendations] (OptionSymbol, ObservationDate);
CREATE INDEX [IX_CSPRecommendations_Ticker] ON [Analysis].[CSPRecommendations] (Rank, CompositeScore, Strike, Expiry, Ticker, ObservationDate);
CREATE INDEX [IX_CSPRecommendations_TradingDate] ON [Analysis].[CSPRecommendations] (Ticker, Rank, Strike, Expiry, TradingDate);