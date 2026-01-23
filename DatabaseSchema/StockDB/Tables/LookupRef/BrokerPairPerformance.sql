-- Table: [LookupRef].[BrokerPairPerformance]

CREATE TABLE [LookupRef].[BrokerPairPerformance] (
    [BrokerCode1] [varchar](50) NULL,
    [BrokerCode2] [varchar](50) NULL,
    [T2DaysNumObservations] [int] NULL,
    [T5DaysNumObservations] [int] NULL,
    [T10DaysNumObservations] [int] NULL,
    [T20DaysNumObservations] [int] NULL,
    [T2DaysNumWin] [int] NULL,
    [T2DaysWinRate] [numeric](26,12) NULL,
    [AvgT2DaysPerformance] [decimal](38,6) NULL,
    [T5DaysNumWin] [int] NULL,
    [T5DaysWinRate] [numeric](26,12) NULL,
    [AvgT5DaysPerformance] [decimal](38,6) NULL,
    [T10DaysNumWin] [int] NULL,
    [T10DaysWinRate] [numeric](26,12) NULL,
    [AvgT10DaysPerformance] [decimal](38,6) NULL,
    [T20DaysNumWin] [int] NULL,
    [T20DaysWinRate] [numeric](26,12) NULL,
    [AvgT20DaysPerformance] [decimal](38,6) NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_lookupref_brokerpairperformance_uniquekey] PRIMARY KEY (UniqueKey)
);
