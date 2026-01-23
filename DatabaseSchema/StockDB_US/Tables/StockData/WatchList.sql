-- Table: [StockData].[WatchList]

CREATE TABLE [StockData].[WatchList] (
    [WatchListID] [int] IDENTITY(1,1) NOT NULL,
    [WatchListName] [varchar](100) NOT NULL,
    [AccountName] [varchar](20) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [LastUpdateDate] [datetime] NULL
);
