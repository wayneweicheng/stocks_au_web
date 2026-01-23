-- Table: [StockData].[SignificantOptionTrade]

CREATE TABLE [StockData].[SignificantOptionTrade] (
    [SignificantOptionTradeID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Underlying] [varchar](10) NOT NULL,
    [OptionSymbol] [varchar](100) NOT NULL,
    [SaleTime] [datetime] NULL,
    [Price] [decimal](20,4) NULL,
    [Size] [bigint] NULL,
    [Exchange] [varchar](100) NULL,
    [SpecialConditions] [varchar](200) NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [UpdateDateTime] [smalldatetime] NULL,
    [BuySellIndicator] [char](1) NULL,
    [LongShortIndicator] [varchar](10) NULL
);
