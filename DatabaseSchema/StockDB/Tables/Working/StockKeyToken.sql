-- Table: [Working].[StockKeyToken]

CREATE TABLE [Working].[StockKeyToken] (
    [StockKeyTokenID] [int] IDENTITY(1,1) NOT NULL,
    [Token] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TokenCount] [int] NULL,
    [AnnCount] [int] NULL,
    [TokenPerAnn] [decimal](10,2) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [AnnWithTokenPerc] [decimal](10,2) NULL
);
