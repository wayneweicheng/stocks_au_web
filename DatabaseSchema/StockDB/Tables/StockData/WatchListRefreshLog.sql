-- Table: [StockData].[WatchListRefreshLog]

CREATE TABLE [StockData].[WatchListRefreshLog] (
    [WatchListRefreshLogID] [int] IDENTITY(1,1) NOT NULL,
    [WatchListName] [varchar](100) NOT NULL,
    [NumStock] [int] NULL,
    [RefreshDateTime] [datetime] NULL
,
    CONSTRAINT [pk_stockdata_watchlist_watchlistrefreshlogid] PRIMARY KEY (WatchListRefreshLogID)
);
