-- Table: [Transform].[MoneyflowInfoPlus]

CREATE TABLE [Transform].[MoneyflowInfoPlus] (
    [MoneyFlowInfoID] [bigint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MoneyFlowType] [varchar](200) NULL,
    [ObservationDate] [date] NULL,
    [LongShort] [varchar](50) NULL,
    [Sentiment] [varchar](10) NULL,
    [MFRank] [int] NULL,
    [MovingAverage20dMFRank] [int] NULL,
    [MFRankPercMovingAverage10d] [decimal](10,2) NULL,
    [MFTotal] [int] NULL,
    [NearScore] [decimal](20,4) NULL,
    [TotalScore] [decimal](20,4) NULL,
    [FormatLongTermScore] [nvarchar](4000) NULL,
    [FormatShortTermScore] [nvarchar](4000) NULL,
    [FormatTotalScore] [nvarchar](4000) NULL,
    [MFRankPerc] [decimal](11,2) NULL,
    [LastValidateDate] [smalldatetime] NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [Close] [decimal](20,4) NULL,
    [AvgMFRankPerc] [decimal](38,6) NULL,
    [NormMFRankPerc] [decimal](20,4) NULL,
    [ZScoreMFRankPerc] [decimal](20,4) NULL
);
