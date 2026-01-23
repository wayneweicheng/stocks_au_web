-- Table: [StockData].[CashPosition]

CREATE TABLE [StockData].[CashPosition] (
    [CashPositionID] [int] IDENTITY(1,1) NOT NULL,
    [AnnouncementID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [ValueInAUDK] [int] NOT NULL,
    [ValueInUSDK] [int] NOT NULL,
    [CashPosition] [bigint] NULL
,
    CONSTRAINT [pk_stockdatacashposition_cashpositionid] PRIMARY KEY (CashPositionID)
);
