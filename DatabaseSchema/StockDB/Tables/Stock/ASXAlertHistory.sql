-- Table: [Stock].[ASXAlertHistory]

CREATE TABLE [Stock].[ASXAlertHistory] (
    [ASXAlertHistory] [int] IDENTITY(1,1) NOT NULL,
    [AlertTypeID] [tinyint] NOT NULL,
    [StockUserID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [AlertMessage] [varchar](MAX) NOT NULL,
    [AlertStatus] [tinyint] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_stock_asxalerthistory_asxalerthistory] PRIMARY KEY (ASXAlertHistory)
);

ALTER TABLE [Stock].[ASXAlertHistory] ADD CONSTRAINT [fk_stockasxalerthistory_alerttypeid] FOREIGN KEY (AlertTypeID) REFERENCES [LookupRef].[AlertType] (AlertTypeID);
ALTER TABLE [Stock].[ASXAlertHistory] ADD CONSTRAINT [fk_stockasxalerthistory_userid] FOREIGN KEY (StockUserID) REFERENCES [Stock].[StockUser] (UserID);