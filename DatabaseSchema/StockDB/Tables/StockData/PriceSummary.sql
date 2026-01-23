-- Table: [StockData].[PriceSummary]

CREATE TABLE [StockData].[PriceSummary] (
    [PriceSummaryID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Bid] [decimal](20,4) NULL,
    [Offer] [decimal](20,4) NULL,
    [Open] [decimal](20,4) NULL,
    [High] [decimal](20,4) NULL,
    [Low] [decimal](20,4) NULL,
    [Close] [decimal](20,4) NULL,
    [Volume] [bigint] NULL,
    [Value] [decimal](20,4) NULL,
    [Trades] [int] NULL,
    [VWAP] [decimal](20,4) NULL,
    [DateFrom] [datetime] NOT NULL,
    [DateTo] [datetime] NULL,
    [LastVerifiedDate] [smalldatetime] NULL,
    [bids] [decimal](20,4) NULL,
    [bidsTotalVolume] [bigint] NULL,
    [offers] [decimal](20,4) NULL,
    [offersTotalVolume] [bigint] NULL,
    [IndicativePrice] [decimal](20,4) NULL,
    [SurplusVolume] [bigint] NULL,
    [PrevClose] [decimal](20,4) NULL,
    [SysLastSaleDate] [datetime] NULL,
    [SysCreateDate] [datetime] NULL,
    [Prev1PriceSummaryID] [int] NULL,
    [Prev1Bid] [decimal](20,4) NULL,
    [Prev1Offer] [decimal](20,4) NULL,
    [Prev1Volume] [bigint] NULL,
    [Prev1Value] [decimal](20,4) NULL,
    [VolumeDelta] [int] NULL,
    [ValueDelta] [decimal](20,4) NULL,
    [TimeIntervalInSec] [int] NULL,
    [BuySellInd] [char](1) NULL,
    [Prev1Close] [decimal](20,4) NULL,
    [LatestForTheDay] [bit] NULL,
    [ObservationDate] [date] NULL,
    [MatchVolume] [int] NULL,
    [SeqNumber] [int] NULL
,
    CONSTRAINT [pk_stockdatapricesummary_pricesummaryid] PRIMARY KEY (ASXCode, PriceSummaryID)
);

CREATE INDEX [idx_stockdatapricesummary_asxcodeobdatevolume] ON [StockData].[PriceSummary] (Open, Close, Value, VWAP, DateFrom, ASXCode, ObservationDate, Volume);
CREATE INDEX [idx_stockdatapricesummary_datefromvolumnobdateasxcode] ON [StockData].[PriceSummary] (Volume, DateFrom, ObservationDate, ASXCode);
CREATE INDEX [idx_stockdatapricesummary_latestobdateasxcode] ON [StockData].[PriceSummary] (LatestForTheDay, ObservationDate, ASXCode);
CREATE INDEX [idx_stockdatapricesummary_observationdate] ON [StockData].[PriceSummary] (ASXCode, Open, Close, PrevClose, Value, VWAP, DateFrom, VolumeDelta, ValueDelta, BuySellInd, ObservationDate, LatestForTheDay, DateTo);
CREATE INDEX [idx_stockdatapricesummary_vwapasxcode] ON [StockData].[PriceSummary] (DateFrom, ValueDelta, BuySellInd, VWAP, ASXCode);