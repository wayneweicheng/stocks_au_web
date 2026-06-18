-- Table: [Transform].[BrokerEffectiveEvent]

CREATE TABLE [Transform].[BrokerEffectiveEvent] (
    [ScoreAsOfDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PriceASXCode] [varchar](10) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [BrokerCode] [varchar](50) NULL,
    [ObservationDate] [date] NOT NULL,
    [BuyValue] [decimal](20,4) NOT NULL,
    [SellValue] [decimal](20,4) NOT NULL,
    [NetValue] [decimal](20,4) NOT NULL,
    [TotalValue] [decimal](20,4) NULL,
    [DayTradedValue] [decimal](20,4) NOT NULL,
    [NetParticipationRatio] [decimal](18,8) NOT NULL,
    [BuyParticipationRatio] [decimal](18,8) NOT NULL,
    [ClosePrice] [decimal](20,8) NOT NULL,
    [Fwd1dReturn] [decimal](18,8) NULL,
    [Fwd3dReturn] [decimal](18,8) NULL,
    [Fwd5dReturn] [decimal](18,8) NULL,
    [Fwd10dReturn] [decimal](18,8) NULL,
    [Fwd20dReturn] [decimal](18,8) NULL,
    [PctRank1d] [decimal](18,8) NULL,
    [PctRank3d] [decimal](18,8) NULL,
    [PctRank5d] [decimal](18,8) NULL,
    [PctRank10d] [decimal](18,8) NULL,
    [PctRank20d] [decimal](18,8) NULL,
    [EventScore] [decimal](18,8) NOT NULL,
    [RecencyWeight] [decimal](18,8) NOT NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerEffectiveEvent] PRIMARY KEY (ScoreAsOfDate, ASXCode, BrokerName, ObservationDate)
);

CREATE INDEX [IX_Transform_BrokerEffectiveEvent_Lookup] ON [Transform].[BrokerEffectiveEvent] (ASXCode, ScoreAsOfDate, BrokerName, EventScore);