-- Table: [StockData].[MoneyFlowInfo]

CREATE TABLE [StockData].[MoneyFlowInfo] (
    [MoneyFlowInfoID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MoneyFlowType] [varchar](200) NULL,
    [ObservationDate] [date] NULL,
    [LongShort] [varchar](50) NULL,
    [Sentiment] [varchar](10) NULL,
    [MFRank] [int] NULL,
    [MFTotal] [int] NULL,
    [NearScore] [decimal](20,4) NULL,
    [TotalScore] [decimal](20,4) NULL,
    [LastValidateDate] [smalldatetime] NULL,
    [CreateDateTime] [smalldatetime] NULL DEFAULT (getdate()),
    [MaxObservationDate] [date] NULL
);
