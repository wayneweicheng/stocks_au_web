-- Table: [StockData].[PriceHistoryCurrent]

CREATE TABLE [StockData].[PriceHistoryCurrent] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Open] [decimal](20,4) NOT NULL,
    [Low] [decimal](20,4) NOT NULL,
    [High] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](20,4) NULL,
    [Trades] [int] NULL,
    [EMA7] [decimal](20,4) NULL,
    [SMA5] [decimal](20,4) NULL,
    [SMA10] [decimal](20,4) NULL,
    [SMA60] [decimal](20,4) NULL,
    [VSMA30] [decimal](20,4) NULL,
    [RSI] [decimal](10,2) NULL,
    [Last12MonthHighDate] [date] NULL,
    [Last12MonthLowDate] [date] NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ModifyDate] [smalldatetime] NULL
);
