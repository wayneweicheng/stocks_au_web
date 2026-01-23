-- Table: [StockData].[ComponentStock]

CREATE TABLE [StockData].[ComponentStock] (
    [ComponentStockId] [int] IDENTITY(1,1) NOT NULL,
    [IndexType] [varchar](20) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Company] [varchar](200) NOT NULL,
    [Symbol] [varchar](10) NOT NULL,
    [Weight] [decimal](20,10) NULL,
    [Price] [decimal](20,10) NULL,
    [CreateDate] [smalldatetime] NULL
);
