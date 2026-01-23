-- Table: [StockData].[PriceHistoryWeekly]

CREATE TABLE [StockData].[PriceHistoryWeekly] (
    [ASXCode] [varchar](10) NOT NULL,
    [Year] [int] NOT NULL,
    [WeekOfYear] [tinyint] NOT NULL,
    [Open] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Volume] [bigint] NULL,
    [VolumeRaw] [bigint] NULL,
    [WeekOpenDate] [date] NOT NULL,
    [WeekCloseDate] [date] NOT NULL,
    [NumTradeDay] [int] NOT NULL
,
    CONSTRAINT [pk_stockdatapricehistoryweekly_asxcodeweekopendate] PRIMARY KEY (ASXCode, WeekOpenDate)
);
