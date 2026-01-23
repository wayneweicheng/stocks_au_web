-- Table: [StockData].[StockAuctionDetail]

CREATE TABLE [StockData].[StockAuctionDetail] (
    [StockAuctionDetailID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CurrentTime] [datetime] NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Bid] [decimal](20,4) NULL,
    [BidVolume] [int] NULL,
    [Ask] [decimal](20,4) NULL,
    [AskVolume] [int] NULL,
    [Last] [decimal](20,4) NULL,
    [LastVolume] [int] NULL,
    [Open] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Volume] [int] NULL,
    [AuctionPrice] [decimal](20,4) NULL,
    [AuctionVolume] [int] NULL,
    [AuctionImbalance] [int] NULL,
    [CreateDate] [datetime] NULL
);
