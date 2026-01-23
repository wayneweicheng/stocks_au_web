-- Table: [StockData].[PriceHistoryTimeFrame]

CREATE TABLE [StockData].[PriceHistoryTimeFrame] (
    [ASXCode] [varchar](10) NOT NULL,
    [TimeFrame] [varchar](10) NOT NULL,
    [TimeIntervalStart] [smalldatetime] NOT NULL,
    [Open] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Volume] [bigint] NOT NULL,
    [FirstSale] [datetime] NULL,
    [LastSale] [datetime] NULL,
    [SaleValue] [decimal](38,4) NULL,
    [NumOfSale] [int] NOT NULL,
    [AverageValuePerTransaction] [decimal](38,6) NULL,
    [VWAP] [decimal](38,6) NULL,
    [ObservationDate] [date] NULL
,
    CONSTRAINT [pk_stockdatapricehistorytimeframe_timeframetimeintervalstart] PRIMARY KEY (TimeFrame, ASXCode, TimeIntervalStart)
);
