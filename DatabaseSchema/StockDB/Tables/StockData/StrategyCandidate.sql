-- Table: [StockData].[StrategyCandidate]

CREATE TABLE [StockData].[StrategyCandidate] (
    [StrategyCandidateID] [int] IDENTITY(1,1) NOT NULL,
    [StrategyID] [smallint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [RankNumber] [int] NULL,
    [CreateDate] [smalldatetime] NULL,
    [BuyValue] [int] NULL
);
