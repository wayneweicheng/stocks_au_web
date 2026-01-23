-- Table: [BrokerData].[BrokerDayReport]

CREATE TABLE [BrokerData].[BrokerDayReport] (
    [BrokerDayReportID] [int] IDENTITY(1,1) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [MarketCap] [varchar](20) NULL,
    [NetValue] [decimal](20,4) NULL,
    [BuyValue] [decimal](20,4) NOT NULL,
    [SellValue] [decimal](20,4) NOT NULL,
    [TotalValue] [decimal](20,4) NULL,
    [BuyRatio] [int] NULL,
    [SellRatio] [int] NULL,
    [NetVolumeShares] [decimal](20,4) NULL,
    [CreateDate] [datetime] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK_BrokerDayReport] PRIMARY KEY (BrokerDayReportID)
);

CREATE INDEX [IX_BrokerDayReport_ASXCode] ON [BrokerData].[BrokerDayReport] (ASXCode, ObservationDate);
CREATE INDEX [IX_BrokerDayReport_BrokerName] ON [BrokerData].[BrokerDayReport] (BrokerName, ObservationDate);
CREATE INDEX [IX_BrokerDayReport_ObservationDate] ON [BrokerData].[BrokerDayReport] (BrokerName, ASXCode, BuyValue, SellValue, ObservationDate);
CREATE UNIQUE INDEX [UQ_BrokerDayReport_Broker_ASX_Date] ON [BrokerData].[BrokerDayReport] (BrokerName, ASXCode, ObservationDate);