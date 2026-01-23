-- Table: [StockData].[StockBidAsk]

CREATE TABLE [StockData].[StockBidAsk] (
    [StockBidAskID] [int] IDENTITY(1,1) NOT NULL,
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

CREATE INDEX [idx_stockdatastockbidask_asxcodeobservationtime] ON [StockData].[StockBidAsk] (ASXCode, ObservationTime);
CREATE INDEX [idx_stockdatastockbidask_asxcodeobtimeobdate] ON [StockData].[StockBidAsk] (StockBidAskID, PriceBid, SizeBid, PriceAsk, SizeAsk, ASXCode, ObservationTime, ObservationDate);
CREATE INDEX [idx_stockdatastockbidask_obdateasxcode] ON [StockData].[StockBidAsk] (StockBidAskID, ObservationTime, PriceBid, SizeBid, PriceAsk, SizeAsk, ObservationDate, ASXCode);