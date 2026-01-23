-- Table: [StockData].[StockNature]

CREATE TABLE [StockData].[StockNature] (
    [StockKeyTokenID] [int] NULL,
    [Token] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TokenCount] [int] NULL,
    [AnnCount] [int] NULL,
    [TokenPerAnn] [decimal](10,2) NULL,
    [CreateDate] [smalldatetime] NULL,
    [AnnWithTokenPerc] [decimal](10,2) NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_stockdata_stocknature_uniquekey] PRIMARY KEY (UniqueKey)
);
