-- Table: [StockData].[WatchListStock]

CREATE TABLE [StockData].[WatchListStock] (
    [WatchListStockID] [int] IDENTITY(1,1) NOT NULL,
    [WatchListName] [varchar](100) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [StdASXCode] [varchar](10) NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
