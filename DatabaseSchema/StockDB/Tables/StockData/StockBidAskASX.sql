-- Table: [StockData].[StockBidAskASX]

CREATE TABLE [StockData].[StockBidAskASX] (
    [StockBidAskASXID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationTime] [datetime] NULL,
    [PriceBid] [decimal](20,4) NULL,
    [SizeBid] [bigint] NULL,
    [PriceAsk] [decimal](20,4) NULL,
    [SizeAsk] [bigint] NULL,
    [ObservationDate] [date] NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [UpdateDateTime] [smalldatetime] NULL
);
