-- Table: [Working].[BackTestTradePF]

CREATE TABLE [Working].[BackTestTradePF] (
    [TradeTypeId] [varchar](50) NULL,
    [ExecutionId] [varchar](50) NULL,
    [TradeUUId] [varchar](50) NULL,
    [StockCode] [varchar](10) NULL,
    [BuyOrderTime] [datetime] NULL,
    [BuyPrice] [decimal](20,4) NULL,
    [SellPrice] [decimal](20,4) NULL,
    [OrderVolume] [int] NULL,
    [SellOrderTime] [datetime] NULL,
    [PriceChange] [decimal](10,2) NULL,
    [CreateDate] [datetime] NULL,
    [TodayChange] [decimal](10,2) NULL,
    [TomorrowChange] [decimal](10,2) NULL,
    [PFChange] [numeric](14,4) NULL,
    [PF] [decimal](20,2) NULL,
    [RowNumber] [bigint] NULL
);
