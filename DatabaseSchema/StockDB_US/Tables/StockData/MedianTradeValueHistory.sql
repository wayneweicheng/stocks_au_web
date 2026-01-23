-- Table: [StockData].[MedianTradeValueHistory]

CREATE TABLE [StockData].[MedianTradeValueHistory] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MedianTradeValue] [float] NULL,
    [CleansedMarketCap] [decimal](20,4) NULL,
    [MedianTradeValueDaily] [float] NULL,
    [MedianPriceChangePerc] [decimal](10,2) NULL,
    [CreateDate] [smalldatetime] NULL
);
