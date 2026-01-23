-- Table: [StockData].[QUOptionTrades]

CREATE TABLE [StockData].[QUOptionTrades] (
    [QUOptionTradesID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [ObservationDate] [date] NULL,
    [Response] [varchar](MAX) NULL,
    [CreateDate] [smalldatetime] NULL
);
