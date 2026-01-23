-- Table: [StockData].[PreviousIPO]

CREATE TABLE [StockData].[PreviousIPO] (
    [PreviousIPOId] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CompanyName] [varchar](200) NULL,
    [IssuePrice] [decimal](20,4) NULL,
    [CurrentPrice] [decimal](20,4) NULL,
    [ReturnPerc] [decimal](10,2) NULL,
    [Day1ReturnPerc] [decimal](10,2) NULL,
    [MarketCap] [decimal](10,2) NULL,
    [ListedDate] [date] NULL,
    [CreateDate] [smalldatetime] NULL,
    [Day1OpenReturnPerc] [decimal](10,2) NULL,
    [Day5ReturnPerc] [decimal](10,2) NULL,
    [Day10ReturnPerc] [decimal](10,2) NULL,
    [Day20ReturnPerc] [decimal](10,2) NULL,
    [Day60ReturnPerc] [decimal](10,2) NULL,
    [Day2ReturnPerc] [decimal](10,2) NULL,
    [Day3ReturnPerc] [decimal](10,2) NULL,
    [Day4ReturnPerc] [decimal](10,2) NULL
);
