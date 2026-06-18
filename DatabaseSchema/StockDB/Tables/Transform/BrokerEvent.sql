-- Table: [Transform].[BrokerEvent]

CREATE TABLE [Transform].[BrokerEvent] (
    [ASXCode] [varchar](10) NOT NULL,
    [PriceASXCode] [varchar](10) NOT NULL,
    [TradeDate] [date] NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [BrokerCode] [varchar](50) NULL,
    [EventType] [varchar](40) NOT NULL,
    [EventDirection] [varchar](10) NOT NULL,
    [TriggerMetric] [varchar](50) NOT NULL,
    [TriggerValue] [decimal](18,8) NOT NULL,
    [BuyValue] [decimal](20,4) NOT NULL,
    [SellValue] [decimal](20,4) NOT NULL,
    [NetValue] [decimal](20,4) NOT NULL,
    [DayTurnover] [decimal](20,4) NOT NULL,
    [DayClose] [decimal](20,8) NOT NULL,
    [DayVWAP] [decimal](20,8) NULL,
    [NetToGrossRatio] [decimal](18,8) NULL,
    [BuyDominance] [decimal](18,8) NULL,
    [SellDominance] [decimal](18,8) NULL,
    [Ret7D] [decimal](18,8) NULL,
    [Ret10D] [decimal](18,8) NULL,
    [Ret15D] [decimal](18,8) NULL,
    [Ret20D] [decimal](18,8) NULL,
    [Ret30D] [decimal](18,8) NULL,
    [Ret45D] [decimal](18,8) NULL,
    [Ret60D] [decimal](18,8) NULL,
    [MaxUp20D] [decimal](18,8) NULL,
    [MaxUp30D] [decimal](18,8) NULL,
    [MaxUp60D] [decimal](18,8) NULL,
    [MaxDD20D] [decimal](18,8) NULL,
    [MaxDD30D] [decimal](18,8) NULL,
    [MaxDD60D] [decimal](18,8) NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerEvent] PRIMARY KEY (ASXCode, TradeDate, BrokerName, EventType)
);

CREATE INDEX [IX_Transform_BrokerEvent_BrokerEventType] ON [Transform].[BrokerEvent] (BrokerName, EventType, EventDirection, TradeDate);
CREATE INDEX [IX_Transform_BrokerEvent_TradeDate_ASXCode] ON [Transform].[BrokerEvent] (TradeDate, ASXCode);