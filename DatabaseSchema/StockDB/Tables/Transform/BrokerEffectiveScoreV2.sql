-- Table: [Transform].[BrokerEffectiveScoreV2]

CREATE TABLE [Transform].[BrokerEffectiveScoreV2] (
    [ScoreAsOfDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [BrokerCode] [varchar](50) NULL,
    [CampaignCount] [int] NOT NULL,
    [WeightedCampaignCount] [decimal](18,8) NOT NULL,
    [AvgRawEventScore] [decimal](18,8) NOT NULL,
    [AvgAdjustedEventScore] [decimal](18,8) NOT NULL,
    [BrokerEffectiveScore] [decimal](18,8) NOT NULL,
    [WinRate5d] [decimal](18,8) NULL,
    [WinRate10d] [decimal](18,8) NULL,
    [WinRate20d] [decimal](18,8) NULL,
    [AvgReturn1d] [decimal](18,8) NULL,
    [AvgReturn3d] [decimal](18,8) NULL,
    [AvgReturn5d] [decimal](18,8) NULL,
    [AvgReturn10d] [decimal](18,8) NULL,
    [AvgReturn20d] [decimal](18,8) NULL,
    [FirstCampaignDate] [date] NULL,
    [LastCampaignDate] [date] NULL,
    [TopRank] [int] NULL,
    [BottomRank] [int] NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [ModifiedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerEffectiveScoreV2] PRIMARY KEY (ScoreAsOfDate, ASXCode, BrokerName)
);

CREATE INDEX [IX_Transform_BrokerEffectiveScoreV2_Lookup] ON [Transform].[BrokerEffectiveScoreV2] (BrokerName, BrokerCode, BrokerEffectiveScore, CampaignCount, WeightedCampaignCount, ASXCode, ScoreAsOfDate, TopRank, BottomRank);