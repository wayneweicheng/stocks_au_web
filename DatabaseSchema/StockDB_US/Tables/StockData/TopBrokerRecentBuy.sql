-- Table: [StockData].[TopBrokerRecentBuy]

CREATE TABLE [StockData].[TopBrokerRecentBuy] (
    [ASXCode] [varchar](10) NOT NULL,
    [BrokerCode] [varchar](50) NOT NULL,
    [NetValue] [bigint] NULL,
    [AvgBuyPrice] [decimal](20,3) NULL,
    [RowNumber] [bigint] NULL,
    [MC] [numeric](23,5) NULL,
    [NumPrevDay] [int] NULL,
    [ObservationStartDate] [date] NULL,
    [ObservationEndDate] [date] NULL
);
