-- Table: [StockData].[OptionPriceHistory]

CREATE TABLE [StockData].[OptionPriceHistory] (
    [ASXCode] [varchar](10) NOT NULL,
    [Underlying] [varchar](10) NOT NULL,
    [OptionSymbol] [varchar](100) NOT NULL,
    [ObservationDateTime] [smalldatetime] NOT NULL,
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
    CONSTRAINT [pk_stockdataoptionpricehistory_optionsymbolobservationdatetime] PRIMARY KEY (OptionSymbol, ObservationDateTime)
);
