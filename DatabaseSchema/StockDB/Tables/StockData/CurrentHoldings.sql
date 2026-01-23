-- Table: [StockData].[CurrentHoldings]

CREATE TABLE [StockData].[CurrentHoldings] (
    [CurrentHoldingsId] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](50) NULL,
    [HeldPrice] [decimal](20,2) NULL,
    [HeldVolume] [int] NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [SourceSystem] [varchar](50) NULL,
    [AccountName] [varchar](100) NULL
);
