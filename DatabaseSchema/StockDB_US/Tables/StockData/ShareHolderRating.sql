-- Table: [StockData].[ShareHolderRating]

CREATE TABLE [StockData].[ShareHolderRating] (
    [ShareHolderRatingID] [int] IDENTITY(1,1) NOT NULL,
    [ShareHolder] [varchar](500) NOT NULL,
    [Rating] [smallint] NULL,
    [RecentPerformance] [decimal](10,2) NOT NULL,
    [NoStocks] [smallint] NULL,
    [WorstStockPerformance] [decimal](10,2) NOT NULL,
    [BestStockPerformance] [decimal](10,2) NOT NULL,
    [StdRecentPerformance] [decimal](10,2) NULL,
    [ReportPeriod] [date] NOT NULL,
    [StockType] [varchar](50) NOT NULL,
    [DaysGoBack] [int] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
