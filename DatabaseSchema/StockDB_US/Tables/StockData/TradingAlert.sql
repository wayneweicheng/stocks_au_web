-- Table: [StockData].[TradingAlert]

CREATE TABLE [StockData].[TradingAlert] (
    [TradingAlertID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [UserID] [int] NOT NULL,
    [TradingAlertTypeID] [tinyint] NOT NULL,
    [MaxBid] [decimal](20,4) NULL,
    [MinBidVolume] [int] NULL,
    [MinAsk] [decimal](20,4) NULL,
    [MinAskVolume] [int] NULL,
    [SaleAbove] [decimal](20,4) NULL,
    [SaleBelow] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NULL,
    [AlertTriggerDate] [smalldatetime] NULL,
    [NotificationSentDate] [smalldatetime] NULL
);
