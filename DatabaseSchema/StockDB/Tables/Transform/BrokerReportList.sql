-- Table: [Transform].[BrokerReportList]

CREATE TABLE [Transform].[BrokerReportList] (
    [BrokerReportListID] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [CurrBRDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [BrokerCode] [varchar](1000) NULL,
    [NetBuySell] [char](1) NOT NULL,
    [LookBackNoDays] [tinyint] NULL,
    [CreateDate] [smalldatetime] NULL,
    [StartBRDate] [date] NULL
);
