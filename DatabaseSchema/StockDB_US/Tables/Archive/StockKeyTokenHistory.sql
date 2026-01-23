-- Table: [Archive].[StockKeyTokenHistory]

CREATE TABLE [Archive].[StockKeyTokenHistory] (
    [StockKeyTokenHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [StockKeyTokenID] [int] NOT NULL,
    [Token] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ArchiveDate] [date] NOT NULL
,
    CONSTRAINT [pk_lookuprefstockkeytoken_StockKeyTokenHistoryID] PRIMARY KEY (StockKeyTokenHistoryID)
);
