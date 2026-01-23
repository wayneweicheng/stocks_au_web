-- Table: [Transform].[TokenPriceVolumeHistory]

CREATE TABLE [Transform].[TokenPriceVolumeHistory] (
    [TokenPriceVolumeHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [Token] [varchar](200) NULL,
    [ObservationDate] [varchar](50) NULL,
    [TradeValue] [decimal](38,4) NULL,
    [ASXCode] [int] NULL,
    [SMA0] [decimal](38,5) NULL,
    [SMA3] [decimal](38,5) NULL,
    [SMA5] [decimal](38,5) NULL,
    [SMA10] [decimal](38,5) NULL,
    [SMA20] [decimal](38,5) NULL,
    [SMA30] [decimal](38,5) NULL,
    [DateSeq] [int] NULL,
    [AvgTradeValue] [decimal](38,4) NULL,
    [AvgTradeValueSMA5] [decimal](38,4) NULL,
    [AvgTradeValueSMA120] [decimal](38,4) NULL,
    [ATVvsATVSMA5] [decimal](10,2) NULL,
    [ATVvsATVSMA120] [decimal](10,2) NULL,
    [TradeValueProfit] [decimal](38,4) NULL,
    [TradeValueProfitPercentage] [decimal](38,4) NULL,
    [TokenType] [varchar](20) NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
