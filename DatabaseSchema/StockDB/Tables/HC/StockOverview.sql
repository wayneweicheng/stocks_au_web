-- Table: [HC].[StockOverview]

CREATE TABLE [HC].[StockOverview] (
    [StockOverviewID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MonthlyVisit] [varchar](100) NULL,
    [NoOfPost] [varchar](100) NULL,
    [MarketCap] [varchar](100) NULL,
    [CleansedMonthlyVisit] [int] NULL,
    [CleansedNoOfPost] [int] NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [DateFrom] [smalldatetime] NOT NULL,
    [DateTo] [smalldatetime] NULL,
    [SeqNum] [int] NULL,
    [CleansedMonthlyVisitDelta] [int] NULL,
    [CleansedNoOfPostDelta] [int] NULL,
    [DerivedTodayVist] [int] NULL,
    [MA30Visit] [decimal](10,2) NULL
,
    CONSTRAINT [pk_hcstockoverview_stockoverviewid] PRIMARY KEY (StockOverviewID)
);

CREATE INDEX [idx_hcstockoverview_asxcode] ON [HC].[StockOverview] (ASXCode);