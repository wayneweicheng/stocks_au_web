-- Table: [Working].[PriceHistoryWeekly]

CREATE TABLE [Working].[PriceHistoryWeekly] (
    [ASXCode] [varchar](10) NOT NULL,
    [Year] [int] NOT NULL,
    [WeekOfYear] [tinyint] NOT NULL,
    [Open] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Volume] [bigint] NULL,
    [WeekOpenDate] [date] NULL,
    [WeekCloseDate] [date] NULL,
    [NumTradeDay] [int] NULL
);
