-- Table: [StockData].[BrokerTradeTransaction]

CREATE TABLE [StockData].[BrokerTradeTransaction] (
    [TransactionID] [bigint] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TransactionDateTime] [datetime2] NOT NULL,
    [Buyer] [nvarchar](100) NOT NULL,
    [Seller] [nvarchar](100) NOT NULL,
    [Price] [decimal](10,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](15,2) NOT NULL,
    [Condition] [nvarchar](50) NULL,
    [Market] [nvarchar](10) NOT NULL,
    [CreateDate] [smalldatetime] NULL
,
    CONSTRAINT [PK__BrokerTr__55433A4B9D045C77] PRIMARY KEY (TransactionID)
);
