-- Table: [BackTest].[Order]

CREATE TABLE [BackTest].[Order] (
    [OrderID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](20) NULL,
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
    [ActualOrderPrice] [decimal](20,4) NULL,
    [IsDisabled] [bit] NULL DEFAULT ((0)),
    [AdditionalSettings] [varchar](MAX) NULL
,
    CONSTRAINT [pk_backtestorder_orderid] PRIMARY KEY (OrderID)
);

ALTER TABLE [BackTest].[Order] ADD CONSTRAINT [fk_backtestorder_ordertypeid] FOREIGN KEY (OrderTypeID) REFERENCES [LookupRef].[OrderType] (OrderTypeID);