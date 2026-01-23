-- Table: [Working].[PriceHistoryMonthly]

CREATE TABLE [Working].[PriceHistoryMonthly] (
    [ASXCode] [varchar](10) NOT NULL,
    [Year] [int] NOT NULL,
    [Month] [tinyint] NOT NULL,
    [Open] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Volume] [bigint] NULL,
    [MonthOpenDate] [date] NULL,
    [MonthCloseDate] [date] NULL,
    [NumTradeDay] [int] NULL
);
