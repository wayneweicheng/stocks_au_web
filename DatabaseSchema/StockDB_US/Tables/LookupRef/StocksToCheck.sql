-- Table: [LookupRef].[StocksToCheck]

CREATE TABLE [LookupRef].[StocksToCheck] (
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [datetime] NULL DEFAULT (getdate())
);
