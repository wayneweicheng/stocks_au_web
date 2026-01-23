-- Table: [Stock].[ASXAlertSetting]

CREATE TABLE [Stock].[ASXAlertSetting] (
    [ASXAlertSetting] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [AlertTypeID] [tinyint] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [StockUserID] [int] NULL
,
    CONSTRAINT [pk_stockasxalertsetting_ASXAlertSetting] PRIMARY KEY (ASXAlertSetting)
);

ALTER TABLE [Stock].[ASXAlertSetting] ADD CONSTRAINT [fk_stockasxalertsetting_stockuserid] FOREIGN KEY (StockUserID) REFERENCES [Stock].[StockUser] (UserID);
ALTER TABLE [Stock].[ASXAlertSetting] ADD CONSTRAINT [fk_stockasxalertsetting_alerttypeid] FOREIGN KEY (AlertTypeID) REFERENCES [LookupRef].[AlertType] (AlertTypeID);