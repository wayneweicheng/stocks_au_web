-- Table: [StockData].[IBMetalsFuturesOptionsCurrent]

CREATE TABLE [StockData].[IBMetalsFuturesOptionsCurrent] (
    [ID] [bigint] IDENTITY(1,1) NOT NULL,
    [RefreshDateTime] [datetime] NOT NULL,
    [Metal] [varchar](20) NOT NULL,
    [Symbol] [varchar](50) NOT NULL,
    [UnderlyingSymbol] [varchar](10) NOT NULL,
    [UnderlyingExpiry] [varchar](10) NULL,
    [StrikePrice] [decimal](18,4) NOT NULL,
    [OptionType] [char](1) NOT NULL,
    [OptionExpiry] [varchar](20) NULL,
    [OpenInterest] [bigint] NULL,
    [Volume] [bigint] NULL,
    [LastPrice] [decimal](18,6) NULL,
    [BidPrice] [decimal](18,6) NULL,
    [AskPrice] [decimal](18,6) NULL,
    [ClosePrice] [decimal](18,6) NULL,
    [Exchange] [varchar](20) NULL,
    [TradingClass] [varchar](10) NULL,
    [ContractID] [bigint] NULL,
    [UnderlyingPrice] [decimal](18,6) NULL,
    [CreateDate] [datetime] NULL DEFAULT (getdate()),
    [UpdateDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__IBMetals__3214EC279098A331] PRIMARY KEY (ID)
);

CREATE INDEX [IX_IBMetalsFuturesOptionsCurrent_Metal] ON [StockData].[IBMetalsFuturesOptionsCurrent] (RefreshDateTime, Symbol, StrikePrice, OptionType, OpenInterest, Volume, Metal);
CREATE INDEX [IX_IBMetalsFuturesOptionsCurrent_RefreshDateTime] ON [StockData].[IBMetalsFuturesOptionsCurrent] (Metal, Symbol, OpenInterest, Volume, RefreshDateTime);
CREATE UNIQUE INDEX [UQ_IBMetalsFuturesOptionsCurrent] ON [StockData].[IBMetalsFuturesOptionsCurrent] (Metal, Symbol, StrikePrice, OptionType, OptionExpiry);