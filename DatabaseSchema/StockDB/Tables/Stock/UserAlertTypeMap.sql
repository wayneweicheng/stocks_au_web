-- Table: [Stock].[UserAlertTypeMap]

CREATE TABLE [Stock].[UserAlertTypeMap] (
    [StockUserAlertTypeMapID] [int] IDENTITY(1,1) NOT NULL,
    [UserID] [int] NOT NULL,
    [AlertTypeID] [int] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_stock_useralerttypemap_stockusealerttypemapid] PRIMARY KEY (StockUserAlertTypeMapID)
);
