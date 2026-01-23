-- Table: [StockData].[StockTickerDetailsParsed]

CREATE TABLE [StockData].[StockTickerDetailsParsed] (
    [StockTickerDetailsParsed] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CurrentTime] [datetime] NULL,
    [ObservationDate] [date] NULL,
    [CreateDate] [datetime] NULL,
    [exchange] [varchar](50) NULL,
    [bid] [decimal](20,4) NULL,
    [bidSize] [int] NULL,
    [ask] [decimal](20,4) NULL,
    [askSize] [int] NULL,
    [last] [decimal](20,4) NULL,
    [lastSize] [int] NULL,
    [prevBid] [decimal](20,4) NULL,
    [prevBidSize] [int] NULL,
    [prevAsk] [decimal](20,4) NULL,
    [prevAskSize] [int] NULL,
    [prevLast] [decimal](20,4) NULL,
    [prevLastSize] [int] NULL,
    [volume] [int] NULL,
    [open] [decimal](20,4) NULL,
    [high] [decimal](20,4) NULL,
    [low] [decimal](20,4) NULL,
    [close] [decimal](20,4) NULL,
    [vwap] [decimal](20,4) NULL,
    [markPrice] [decimal](20,4) NULL,
    [halted] [varchar](10) NULL,
    [rtVolume] [bigint] NULL,
    [rtTradeVolume] [bigint] NULL,
    [auctionVolume] [int] NULL,
    [auctionPrice] [decimal](20,4) NULL,
    [auctionImbalance] [int] NULL
);

CREATE INDEX [idx_stockdata_stocktickerdetailsparsed_asxcodeobservationdate] ON [StockData].[StockTickerDetailsParsed] (ASXCode, ObservationDate);