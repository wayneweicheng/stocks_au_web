-- Table: [LookupRef].[StockKeyToken]

CREATE TABLE [LookupRef].[StockKeyToken] (
    [StockKeyTokenID] [int] IDENTITY(1,1) NOT NULL,
    [Token] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookuprefstockkeytoken_stockkeytokenid] PRIMARY KEY (StockKeyTokenID)
);

ALTER TABLE [LookupRef].[StockKeyToken] ADD CONSTRAINT [fk_lookuprefstockkeytoken_token] FOREIGN KEY (Token) REFERENCES [LookupRef].[KeyToken] (Token);