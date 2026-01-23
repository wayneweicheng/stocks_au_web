-- Table: [StockData].[StockKeyToken]

CREATE TABLE [StockData].[StockKeyToken] (
    [StockKeyTokenID] [int] IDENTITY(1,1) NOT NULL,
    [Token] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TokenCount] [int] NULL,
    [AnnCount] [int] NULL,
    [TokenPerAnn] [decimal](10,2) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [AnnWithTokenPerc] [decimal](10,2) NULL
,
    CONSTRAINT [pk_stockdatastockkeytoken_stockkeytokenid] PRIMARY KEY (StockKeyTokenID)
);

ALTER TABLE [StockData].[StockKeyToken] ADD CONSTRAINT [fk_stockdata_stockkeytoken] FOREIGN KEY (Token) REFERENCES [LookupRef].[KeyToken] (Token);