-- Table: [StockData].[IBMetalsFuturesOptionsHistory]

CREATE TABLE [StockData].[IBMetalsFuturesOptionsHistory] (
    [ID] [bigint] IDENTITY(1,1) NOT NULL,
    [RefreshDateTime] [datetime] NOT NULL,
    [RefreshDate] [date] NOT NULL,
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
    [CreateDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__IBMetals__3214EC275DD28225] PRIMARY KEY (ID)
);

CREATE INDEX [IX_IBMetalsFuturesOptionsHistory_Metal_RefreshDate] ON [StockData].[IBMetalsFuturesOptionsHistory] (Symbol, StrikePrice, OptionType, OpenInterest, Volume, Metal, RefreshDate, RefreshDateTime);
CREATE INDEX [IX_IBMetalsFuturesOptionsHistory_RefreshDateTime] ON [StockData].[IBMetalsFuturesOptionsHistory] (Metal, Symbol, StrikePrice, OptionType, OpenInterest, Volume, RefreshDateTime);
CREATE INDEX [IX_IBMetalsFuturesOptionsHistory_Symbol_Strike] ON [StockData].[IBMetalsFuturesOptionsHistory] (OpenInterest, Volume, LastPrice, Symbol, StrikePrice, OptionType, RefreshDateTime);