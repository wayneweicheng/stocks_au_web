-- Table: [StockData].[MarketScan_BAK]

CREATE TABLE [StockData].[MarketScan_BAK] (
    [MarketScanID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [ScanCode] [varchar](200) NOT NULL,
    [ScanResultJson] [varchar](MAX) NOT NULL,
    [CreateDate] [smalldatetime] NULL
);
