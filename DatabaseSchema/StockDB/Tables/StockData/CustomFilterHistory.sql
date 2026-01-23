-- Table: [StockData].[CustomFilterHistory]

CREATE TABLE [StockData].[CustomFilterHistory] (
    [CustomFilterHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CustomFilter] [varchar](500) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
