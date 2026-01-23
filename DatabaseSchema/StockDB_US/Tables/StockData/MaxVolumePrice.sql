-- Table: [StockData].[MaxVolumePrice]

CREATE TABLE [StockData].[MaxVolumePrice] (
    [AdjVolumeRank] [bigint] NULL,
    [AdjVolume] [numeric](23,2) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Open] [decimal](20,4) NOT NULL,
    [Low] [decimal](20,4) NOT NULL,
    [High] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](20,4) NULL,
    [Trades] [int] NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ModifyDate] [smalldatetime] NULL,
    [VWAP] [decimal](20,4) NULL
);
