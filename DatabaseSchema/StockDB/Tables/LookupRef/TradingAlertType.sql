-- Table: [LookupRef].[TradingAlertType]

CREATE TABLE [LookupRef].[TradingAlertType] (
    [TradingAlertTypeID] [tinyint] NOT NULL,
    [TradingAlertType] [varchar](200) NOT NULL,
    [TradingAlertTypeDescr] [varchar](4000) NULL,
    [IsDisabled] [bit] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftradingalerttype_tradingalerttypeid] PRIMARY KEY (TradingAlertTypeID)
);
