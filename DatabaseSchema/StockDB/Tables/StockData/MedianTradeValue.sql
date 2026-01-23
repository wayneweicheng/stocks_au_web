-- Table: [StockData].[MedianTradeValue]

CREATE TABLE [StockData].[MedianTradeValue] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MedianTradeValue] [float] NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [MedianTradeValueDaily] [float] NULL,
    [MedianPriceChangePerc] [decimal](10,2) NULL
,
    CONSTRAINT [pk_stockdata_mediantradevalue_uniquekey] PRIMARY KEY (UniqueKey)
);
