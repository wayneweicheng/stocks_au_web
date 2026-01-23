-- Table: [Stock].[StockStats]

CREATE TABLE [Stock].[StockStats] (
    [ASXCode] [varchar](10) NOT NULL,
    [IsTrendFlatOrUp] [bit] NULL,
    [LatestPrice] [decimal](20,4) NULL,
    [LastUpdateDate] [smalldatetime] NULL
);
