-- Table: [StockData].[UnknownBrokerCode]

CREATE TABLE [StockData].[UnknownBrokerCode] (
    [UnknownBrokerCodeID] [int] IDENTITY(1,1) NOT NULL,
    [BrokerName] [varchar](200) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [CreateDate] [smalldatetime] NULL
);
