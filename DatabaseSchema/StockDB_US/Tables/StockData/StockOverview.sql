-- Table: [StockData].[StockOverview]

CREATE TABLE [StockData].[StockOverview] (
    [StockOverviewID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MarketCap] [varchar](50) NULL,
    [ShareOnIssue] [varchar](50) NULL,
    [DateFrom] [smalldatetime] NOT NULL,
    [DateTo] [smalldatetime] NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [CleansedShareOnIssue] [decimal](20,4) NULL
,
    CONSTRAINT [pk_stockdatastockoverview_stockoverviewid] PRIMARY KEY (StockOverviewID)
);

CREATE INDEX [idx_stockdatastockoverview_datetoasxcodeIncmcsoi] ON [StockData].[StockOverview] (MarketCap, ShareOnIssue, DateTo, ASXCode);