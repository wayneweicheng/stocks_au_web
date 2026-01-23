-- Table: [StockData].[CacheMarketDepth]

CREATE TABLE [StockData].[CacheMarketDepth] (
    [ASXCode] [varchar](6) NOT NULL,
    [DepthTypeID] [int] NULL,
    [NumTraders] [int] NULL,
    [volume] [int] NULL,
    [price] [decimal](20,4) NULL,
    [pU] [nvarchar](4000) NULL,
    [pM] [nvarchar](4000) NULL,
    [CreateDate] [datetime] NOT NULL
);
