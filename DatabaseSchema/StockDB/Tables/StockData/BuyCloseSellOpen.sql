-- Table: [StockData].[BuyCloseSellOpen]

CREATE TABLE [StockData].[BuyCloseSellOpen] (
    [ASXCode] [varchar](10) NOT NULL,
    [IncreasePerc] [int] NULL,
    [NumIncreasePrice] [int] NULL,
    [NonFlatOpenTotal] [int] NULL,
    [NumTotal] [int] NULL,
    [AvgOpenVsPrevClose] [numeric](38,13) NULL,
    [AvgCloseValue] [nvarchar](4000) NULL,
    [AvgCloseValueDec] [decimal](38,6) NULL,
    [RefreshDate] [datetime] NOT NULL
);
