-- Table: [StockData].[StockOverviewCurrent]

CREATE TABLE [StockData].[StockOverviewCurrent] (
    [StockOverviewID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MarketCap] [varchar](50) NULL,
    [ShareOnIssue] [varchar](50) NULL,
    [DateFrom] [smalldatetime] NOT NULL,
    [DateTo] [smalldatetime] NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [CleansedShareOnIssue] [decimal](20,4) NULL
,
    CONSTRAINT [pk_stockdata_stockoverviewcurrent_stockoverviewid] PRIMARY KEY (StockOverviewID)
);
