-- Table: [StockData].[PriceHistorySecondary]

CREATE TABLE [StockData].[PriceHistorySecondary] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [Open] [decimal](20,4) NOT NULL,
    [Low] [decimal](20,4) NOT NULL,
    [High] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](20,4) NULL,
    [Trades] [int] NULL,
    [Exchange] [varchar](20) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ModifyDate] [smalldatetime] NULL,
    [VWAP] [decimal](20,4) NULL,
    [AdditionalElements] [varchar](MAX) NULL
,
    CONSTRAINT [pk_stockdatapricehistorysecondary_asxcodeobservationdateexchange] PRIMARY KEY (ASXCode, ObservationDate, Exchange)
);
