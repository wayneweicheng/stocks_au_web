-- Table: [HC].[CommonStockHistory]

CREATE TABLE [HC].[CommonStockHistory] (
    [CommonStockHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Poster] [varchar](30) NULL,
    [LatestHoldDate] [smalldatetime] NULL,
    [CreateDate] [datetime] NOT NULL
);
