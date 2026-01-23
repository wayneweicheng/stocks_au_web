-- Table: [StockData].[PriceHistoryMonthly]

CREATE TABLE [StockData].[PriceHistoryMonthly] (
    [ASXCode] [varchar](10) NOT NULL,
    [Year] [int] NOT NULL,
    [MonthOfYear] [tinyint] NOT NULL,
    [Open] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Volume] [bigint] NULL,
    [VolumeRaw] [bigint] NULL,
    [MonthOpenDate] [date] NOT NULL,
    [MonthCloseDate] [date] NOT NULL,
    [NumTradeDay] [int] NOT NULL
,
    CONSTRAINT [pk_stockdatapricehistorymonthly_asxcodemonthopendate] PRIMARY KEY (ASXCode, MonthOpenDate)
);
