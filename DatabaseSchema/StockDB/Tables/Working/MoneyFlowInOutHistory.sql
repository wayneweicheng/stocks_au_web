-- Table: [Working].[MoneyFlowInOutHistory]

CREATE TABLE [Working].[MoneyFlowInOutHistory] (
    [ASXCode] [varchar](10) NOT NULL,
    [MarketDate] [varchar](100) NULL,
    [MoneyFlowAmount] [decimal](20,3) NULL,
    [MoneyFlowAmountIn] [decimal](20,3) NULL,
    [MoneyFlowAmountOut] [decimal](20,3) NULL,
    [CumulativeMoneyFlowAmount] [decimal](20,3) NULL,
    [PriceChangePerc] [nvarchar](4000) NULL,
    [InPerc] [nvarchar](4000) NULL,
    [OutPerc] [nvarchar](4000) NULL,
    [InNumTrades] [int] NULL,
    [OutNumTrades] [int] NULL,
    [InAvgSize] [nvarchar](4000) NULL,
    [OutAvgSize] [nvarchar](4000) NULL,
    [Open] [nvarchar](4000) NULL,
    [High] [nvarchar](4000) NULL,
    [Low] [nvarchar](4000) NULL,
    [Close] [nvarchar](4000) NULL,
    [VWAP] [nvarchar](4000) NULL,
    [Volume] [nvarchar](4000) NULL,
    [Value] [nvarchar](4000) NULL,
    [RowNumber] [bigint] NULL
);
