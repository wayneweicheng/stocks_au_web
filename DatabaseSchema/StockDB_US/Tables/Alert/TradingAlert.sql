-- Table: [Alert].[TradingAlert]

CREATE TABLE [Alert].[TradingAlert] (
    [TradingAlertID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [UserID] [int] NOT NULL,
    [TradingAlertTypeID] [tinyint] NOT NULL,
    [AlertPrice] [decimal](20,4) NULL,
    [AlertVolume] [bigint] NULL,
    [ActualPrice] [decimal](20,4) NULL,
    [ActualVolume] [bigint] NULL,
    [CreateDate] [smalldatetime] NULL,
    [AlertTriggerDate] [datetime] NULL,
    [NotificationSentDate] [datetime] NULL,
    [AlertPriceType] [varchar](100) NULL,
    [Boost] [int] NULL
);

ALTER TABLE [Alert].[TradingAlert] ADD CONSTRAINT [fk_alerttradingalert_tradingalerttypeid] FOREIGN KEY (TradingAlertTypeID) REFERENCES [LookupRef].[TradingAlertType] (TradingAlertTypeID);