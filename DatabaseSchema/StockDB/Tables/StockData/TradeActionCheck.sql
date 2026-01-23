-- Table: [StockData].[TradeActionCheck]

CREATE TABLE [StockData].[TradeActionCheck] (
    [TradeActionCheck] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [NumDetailRecord] [int] NULL,
    [TradeAction] [varchar](1) NOT NULL,
    [TradeValue] [decimal](20,4) NULL,
    [ActionRule] [varchar](100) NULL,
    [CreateDate] [datetime] NULL
);
