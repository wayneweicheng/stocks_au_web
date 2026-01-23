-- Table: [BackTest].[BackTestTrade]

CREATE TABLE [BackTest].[BackTestTrade] (
    [BackTestTradeID] [int] IDENTITY(1,1) NOT NULL,
    [TradeTypeId] [varchar](50) NULL,
    [ExecutionId] [varchar](50) NULL,
    [TradeUUId] [varchar](50) NULL,
    [BuySell] [char](1) NULL,
    [StockCode] [varchar](10) NULL,
    [OrderTime] [datetime] NULL,
    [OrderPrice] [decimal](20,4) NULL,
    [OrderVolume] [int] NULL,
    [CreateDate] [datetime] NULL,
    [OrderID] [int] NULL,
    [TradeStatus] [varchar](2) NULL,
    [ConditionCode] [varchar](10) NULL,
    [RSI] [decimal](10,3) NULL
);
