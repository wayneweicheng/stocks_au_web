-- Table: [Transform].[BrokerInsightSummary]

CREATE TABLE [Transform].[BrokerInsightSummary] (
    [BrokerCode] [varchar](50) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [StartDate] [date] NULL,
    [EndDate] [date] NULL,
    [NetValue] [bigint] NULL,
    [NetVolume] [bigint] NULL,
    [HoldPrice] [decimal](20,4) NULL,
    [CurrentPrice] [decimal](20,4) NULL,
    [CurrentValue] [bigint] NULL,
    [CumulativePerf] [decimal](10,2) NULL,
    [LongShort] [varchar](5) NOT NULL,
    [AggPercReturn] [decimal](10,2) NULL,
    [AggPercOfWin] [decimal](10,2) NULL,
    [NumPrevDay] [int] NULL
);
