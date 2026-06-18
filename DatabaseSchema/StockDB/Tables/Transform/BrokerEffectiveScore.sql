-- Table: [Transform].[BrokerEffectiveScore]

CREATE TABLE [Transform].[BrokerEffectiveScore] (
    [ScoreAsOfDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [BrokerCode] [varchar](50) NULL,
    [EventCount] [int] NOT NULL,
    [WeightedEventCount] [decimal](18,8) NOT NULL,
    [AvgEventScore] [decimal](18,8) NOT NULL,
    [BrokerEffectiveScore] [decimal](18,8) NOT NULL,
    [WinRate5d] [decimal](18,8) NULL,
    [WinRate10d] [decimal](18,8) NULL,
    [WinRate20d] [decimal](18,8) NULL,
    [AvgReturn1d] [decimal](18,8) NULL,
    [AvgReturn3d] [decimal](18,8) NULL,
    [AvgReturn5d] [decimal](18,8) NULL,
    [AvgReturn10d] [decimal](18,8) NULL,
    [AvgReturn20d] [decimal](18,8) NULL,
    [FirstEventDate] [date] NULL,
    [LastEventDate] [date] NULL,
    [TopRank] [int] NULL,
    [BottomRank] [int] NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [ModifiedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerEffectiveScore] PRIMARY KEY (ScoreAsOfDate, ASXCode, BrokerName)
);

CREATE INDEX [IX_Transform_BrokerEffectiveScore_Lookup] ON [Transform].[BrokerEffectiveScore] (BrokerName, BrokerCode, BrokerEffectiveScore, EventCount, WeightedEventCount, ASXCode, ScoreAsOfDate, TopRank, BottomRank);