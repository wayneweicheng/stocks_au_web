-- Table: [Order].[Order]

CREATE TABLE [Order].[Order] (
    [OrderID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [UserID] [int] NOT NULL,
    [OrderTypeID] [tinyint] NOT NULL,
    [OrderPrice] [decimal](20,4) NULL,
    [VolumeGt] [bigint] NULL,
    [OrderVolume] [bigint] NULL,
    [ValidUntil] [smalldatetime] NULL,
    [CreateDate] [smalldatetime] NULL,
    [OrderTriggerDate] [datetime] NULL,
    [OrderProcessDate] [datetime] NULL,
    [OrderPlaceDate] [datetime] NULL,
    [TradeAccountName] [varchar](100) NULL,
    [OrderPriceType] [varchar](100) NULL,
    [OrderPriceBufferNumberOfTick] [int] NULL,
    [OrderValue] [decimal](20,4) NULL,
    [ActualOrderPrice] [decimal](20,4) NULL
);

ALTER TABLE [Order].[Order] ADD CONSTRAINT [fk_orderorder_ordertypeid] FOREIGN KEY (OrderTypeID) REFERENCES [LookupRef].[OrderType] (OrderTypeID);