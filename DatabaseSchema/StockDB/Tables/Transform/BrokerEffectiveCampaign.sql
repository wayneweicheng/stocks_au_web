-- Table: [Transform].[BrokerEffectiveCampaign]

CREATE TABLE [Transform].[BrokerEffectiveCampaign] (
    [ScoreAsOfDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PriceASXCode] [varchar](10) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [BrokerCode] [varchar](50) NULL,
    [CampaignId] [int] NOT NULL,
    [CampaignStartDate] [date] NOT NULL,
    [CampaignEndDate] [date] NOT NULL,
    [CampaignTradingDays] [int] NOT NULL,
    [CampaignBuyValue] [decimal](20,4) NOT NULL,
    [CampaignSellValue] [decimal](20,4) NOT NULL,
    [CampaignNetValue] [decimal](20,4) NOT NULL,
    [CampaignTradedValue] [decimal](20,4) NOT NULL,
    [CampaignNetParticipationRatio] [decimal](18,8) NOT NULL,
    [CampaignBuyParticipationRatio] [decimal](18,8) NOT NULL,
    [PeakDailyNetParticipationRatio] [decimal](18,8) NOT NULL,
    [EntryClosePrice] [decimal](20,8) NOT NULL,
    [SignalClosePrice] [decimal](20,8) NOT NULL,
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
    [RawEventScore] [decimal](18,8) NOT NULL,
    [CampaignStrengthFactor] [decimal](18,8) NOT NULL,
    [AdjustedEventScore] [decimal](18,8) NOT NULL,
    [RecencyWeight] [decimal](18,8) NOT NULL,
    [EffectiveWeight] [decimal](18,8) NOT NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerEffectiveCampaign] PRIMARY KEY (ScoreAsOfDate, ASXCode, BrokerName, CampaignId)
);

CREATE INDEX [IX_Transform_BrokerEffectiveCampaign_Lookup] ON [Transform].[BrokerEffectiveCampaign] (ASXCode, ScoreAsOfDate, BrokerName, CampaignEndDate);