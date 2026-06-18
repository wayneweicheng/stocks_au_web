-- Table: [Transform].[StockDayBrokerSetup]

CREATE TABLE [Transform].[StockDayBrokerSetup] (
    [SnapshotDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PriceASXCode] [varchar](10) NOT NULL,
    [TradeDate] [date] NOT NULL,
    [DayClose] [decimal](20,8) NOT NULL,
    [DayVWAP] [decimal](20,8) NULL,
    [DayTurnover] [decimal](20,4) NOT NULL,
    [RollTurnover5D] [decimal](20,4) NULL,
    [TotalBrokerNetBuy5D] [decimal](20,4) NULL,
    [TotalBrokerNetSell5D] [decimal](20,4) NULL,
    [Top1BrokerNetBuyShare5D] [decimal](18,8) NULL,
    [Top3BrokerNetBuyShare5D] [decimal](18,8) NULL,
    [Top1BrokerNetSellShare5D] [decimal](18,8) NULL,
    [Top3BrokerNetSellShare5D] [decimal](18,8) NULL,
    [PositiveFlowHHI5D] [decimal](18,8) NULL,
    [NegativeFlowHHI5D] [decimal](18,8) NULL,
    [PositiveBrokerCount5D] [int] NULL,
    [NegativeBrokerCount5D] [int] NULL,
    [SmartBrokerNetBuy5D] [decimal](20,4) NULL,
    [SmartBrokerNetSell5D] [decimal](20,4) NULL,
    [SmartBrokerNetBuyPct5D] [decimal](18,8) NULL,
    [SmartBrokerNetSellPct5D] [decimal](18,8) NULL,
    [EstimatedCompositeCost] [decimal](20,8) NULL,
    [CloseVsCompositeCost] [decimal](18,8) NULL,
    [LeadBullBroker] [varchar](200) NULL,
    [LeadBearBroker] [varchar](200) NULL,
    [BullishSetupScore] [decimal](18,8) NOT NULL,
    [BearishSetupScore] [decimal](18,8) NOT NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_StockDayBrokerSetup] PRIMARY KEY (SnapshotDate, ASXCode, TradeDate)
);

CREATE INDEX [IX_Transform_StockDayBrokerSetup_Lookup] ON [Transform].[StockDayBrokerSetup] (ASXCode, SnapshotDate, TradeDate);