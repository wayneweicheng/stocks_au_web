-- Table: [Transform].[BrokerPairPerformanceDedupe_Scenario1]

CREATE TABLE [Transform].[BrokerPairPerformanceDedupe_Scenario1] (
    [BrokerPairPerformanceID] [int] IDENTITY(1,1) NOT NULL,
    [ObservationEndDateTPlus3] [date] NULL,
    [ObservationStartDate1] [date] NULL,
    [ObservationStartDate2] [date] NULL,
    [ObservationEndDate] [date] NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MasterBrokerCode] [varchar](50) NULL,
    [ChildBrokerCode] [varchar](50) NULL,
    [MasterNetValue] [bigint] NULL,
    [ChildNetValue] [bigint] NULL,
    [MasterVolume] [bigint] NULL,
    [ChildVolume] [bigint] NULL,
    [MasterBuyPrice] [decimal](20,4) NULL,
    [MasterSellPrice] [decimal](20,4) NULL,
    [ChildBuyPrice] [decimal](20,4) NULL,
    [ChildSellPrice] [decimal](20,4) NULL,
    [MasterPositiveRank] [bigint] NULL,
    [ChildPositiveRank] [bigint] NULL,
    [T2DaysPerformance] [decimal](20,2) NULL,
    [T5DaysPerformance] [decimal](20,2) NULL,
    [T10DaysPerformance] [decimal](20,2) NULL,
    [T20DaysPerformance] [decimal](20,2) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [DedupeKey] [int] NULL,
    [RowNumber] [bigint] NULL
);
