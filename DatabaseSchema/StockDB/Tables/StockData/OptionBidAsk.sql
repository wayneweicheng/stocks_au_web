-- Table: [StockData].[OptionBidAsk]

CREATE TABLE [StockData].[OptionBidAsk] (
    [OptionBidAskID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Underlying] [varchar](10) NOT NULL,
    [OptionSymbol] [varchar](100) NOT NULL,
    [ObservationTime] [datetime] NULL,
    [PriceBid] [decimal](20,4) NULL,
    [SizeBid] [bigint] NULL,
    [PriceAsk] [decimal](20,4) NULL,
    [SizeAsk] [bigint] NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [UpdateDateTime] [smalldatetime] NULL,
    [UpDown] [char](1) NULL,
    [ObservationDateLocal] [date] NULL
);
