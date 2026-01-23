-- Table: [Transform].[BrokerInsight]

CREATE TABLE [Transform].[BrokerInsight] (
    [MCRange] [varchar](100) NULL,
    [NumDays] [int] NULL,
    [BrokerCode] [varchar](50) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [NetValue] [bigint] NULL,
    [NetVolume] [bigint] NULL,
    [EntryPrice] [decimal](20,4) NULL,
    [EntryValue] [bigint] NULL,
    [ExitPrice] [decimal](20,4) NULL,
    [ExitValue] [bigint] NULL,
    [CumulativePerf] [decimal](10,2) NULL,
    [LongShort] [varchar](5) NOT NULL,
    [AggPercReturn] [decimal](10,2) NULL,
    [AggPercOfWin] [decimal](10,2) NULL
);
