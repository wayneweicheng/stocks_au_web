-- Table: [StockData].[MonitorStock]

CREATE TABLE [StockData].[MonitorStock] (
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [LastUpdateDate] [datetime] NULL,
    [UpdateStatus] [tinyint] NULL,
    [MonitorTypeID] [varchar](20) NOT NULL,
    [LastCourseOfSaleDate] [datetime] NULL,
    [StockSource] [varchar](10) NULL,
    [PriorityLevel] [smallint] NULL,
    [SMSAlertSetupDate] [smalldatetime] NULL,
    [LastMonitorDate] [datetime] NULL
,
    CONSTRAINT [pk_stockdatamonitorstock_asxcodemonitortypeid] PRIMARY KEY (ASXCode, MonitorTypeID)
);

ALTER TABLE [StockData].[MonitorStock] ADD CONSTRAINT [fk_stockdatamonitorstock_monitortypeid] FOREIGN KEY (MonitorTypeID) REFERENCES [LookupRef].[MonitorType] (MonitorTypeID);