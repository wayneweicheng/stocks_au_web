-- Table: [Transform].[BrokerProfitLossRank]

CREATE TABLE [Transform].[BrokerProfitLossRank] (
    [ASXCode] [varchar](10) NOT NULL,
    [BrokerCode] [varchar](50) NOT NULL,
    [TrueVolume] [nvarchar](4000) NULL,
    [SellPerShare] [numeric](38,17) NULL,
    [BuyPerShare] [numeric](38,17) NULL,
    [ProfiltPerShare] [nvarchar](4000) NULL,
    [MarketProfit] [nvarchar](4000) NULL,
    [HoldingStockProfit] [nvarchar](4000) NULL,
    [TotalProfit] [nvarchar](4000) NULL,
    [RemainVolume] [nvarchar](4000) NULL,
    [ProfitRank] [bigint] NULL,
    [LossRank] [bigint] NULL,
    [ObservationDate] [date] NULL
);
