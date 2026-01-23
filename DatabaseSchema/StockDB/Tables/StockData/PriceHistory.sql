-- Table: [StockData].[PriceHistory]

CREATE TABLE [StockData].[PriceHistory] (
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
    [ModifyDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_stockdatapricehistory_asxcodeobservationdate] PRIMARY KEY (ASXCode, ObservationDate)
);

CREATE INDEX [idx_stockdatapricehistory_observationdateasxcodeIncvolume] ON [StockData].[PriceHistory] (Volume, ObservationDate, ASXCode);