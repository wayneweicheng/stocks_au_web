-- Table: [StockData].[GoldInterception]

CREATE TABLE [StockData].[GoldInterception] (
    [ObservationDate] [date] NULL,
    [ReportType] [varchar](13) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [MarketDate] [date] NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL,
    [MC] [numeric](23,3) NULL,
    [CashPosition] [numeric](26,6) NULL,
    [MatchText] [nvarchar](MAX) NULL
);
