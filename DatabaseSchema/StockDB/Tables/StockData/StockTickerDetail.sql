-- Table: [StockData].[StockTickerDetail]

CREATE TABLE [StockData].[StockTickerDetail] (
    [StockTickerDetailID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CurrentTime] [datetime] NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [TickerJson] [varchar](MAX) NULL,
    [CreateDate] [datetime] NULL
);

CREATE INDEX [idx_stockdatastocktickerdetail_stocktickerdetailid] ON [StockData].[StockTickerDetail] (StockTickerDetailID);