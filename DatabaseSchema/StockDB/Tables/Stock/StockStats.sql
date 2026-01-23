-- Table: [Stock].[StockStats]

CREATE TABLE [Stock].[StockStats] (
    [ASXCode] [varchar](10) NOT NULL,
    [IsTrendFlatOrUp] [bit] NULL,
    [LatestPrice] [decimal](20,4) NULL,
    [LastUpdateDate] [smalldatetime] NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_stock_stockstats_uniquekey] PRIMARY KEY (UniqueKey)
);
