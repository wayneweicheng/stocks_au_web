-- Table: [Stock].[Trade]

CREATE TABLE [Stock].[Trade] (
    [TradeID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TradeDateTime] [datetime] NOT NULL,
    [TradeType] [tinyint] NOT NULL,
    [Price] [decimal](20,4) NULL,
    [Volume] [bigint] NOT NULL,
    [TotalValue] [decimal](20,4) NULL,
    [BrokerageFee] [decimal](20,4) NULL,
    [SellStrategyID] [smallint] NOT NULL,
    [UserID] [int] NOT NULL,
    [Comment] [varchar](MAX) NULL,
    [CreateDate] [smalldatetime] NULL,
    [StopLossPrice] [decimal](20,4) NULL,
    [ExitPrice] [decimal](20,4) NULL
,
    CONSTRAINT [pk_stocktrade_tradeid] PRIMARY KEY (TradeID)
);
