-- Table: [StockData].[BrokerReport]

CREATE TABLE [StockData].[BrokerReport] (
    [BrokerReportID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [BrokerCode] [varchar](50) NOT NULL,
    [Symbol] [varchar](200) NULL,
    [BuyValue] [bigint] NULL,
    [SellValue] [bigint] NULL,
    [NetValue] [bigint] NULL,
    [TotalValue] [bigint] NULL,
    [BuyVolume] [bigint] NULL,
    [SellVolume] [bigint] NULL,
    [NetVolume] [bigint] NULL,
    [TotalVolume] [bigint] NULL,
    [NoBuys] [bigint] NULL,
    [NoSells] [bigint] NULL,
    [Trades] [bigint] NULL,
    [BuyPrice] [decimal](20,4) NULL,
    [SellPrice] [decimal](20,4) NULL,
    [PercRank] [decimal](6,2) NULL,
    [CreateDate] [smalldatetime] NULL
);

CREATE INDEX [idx_stockdatabrokerreport_brokercode] ON [StockData].[BrokerReport] (BrokerCode);
CREATE INDEX [idx_stockdatabrokerreport_observationdatebrokercodeIncasxcodevaluevol] ON [StockData].[BrokerReport] (ASXCode, NetValue, NetVolume, BuyValue, TotalVolume, ObservationDate, BrokerCode);