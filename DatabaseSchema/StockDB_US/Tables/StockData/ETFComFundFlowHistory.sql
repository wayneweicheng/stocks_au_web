-- Table: [StockData].[ETFComFundFlowHistory]

CREATE TABLE [StockData].[ETFComFundFlowHistory] (
    [ID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Ticker] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [FundFlow] [decimal](18,2) NULL,
    [AUM] [decimal](18,2) NULL,
    [SharesOutstanding] [bigint] NULL,
    [NavPrice] [decimal](18,4) NULL,
    [ClosePrice] [decimal](18,4) NULL,
    [Volume] [bigint] NULL,
    [InsertDateTime] [datetime] NOT NULL DEFAULT (getdate()),
    [CreateDate] [datetime] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__ETFComFu__3214EC27A18BC96B] PRIMARY KEY (ID)
);

CREATE INDEX [IX_ETFComFundFlowHistory_ASXCode_ObservationDate] ON [StockData].[ETFComFundFlowHistory] (FundFlow, AUM, NavPrice, ClosePrice, Volume, ASXCode, ObservationDate, InsertDateTime);
CREATE INDEX [IX_ETFComFundFlowHistory_InsertDateTime] ON [StockData].[ETFComFundFlowHistory] (ASXCode, Ticker, ObservationDate, FundFlow, AUM, InsertDateTime);
CREATE INDEX [IX_ETFComFundFlowHistory_Ticker] ON [StockData].[ETFComFundFlowHistory] (ASXCode, FundFlow, AUM, InsertDateTime, Ticker, ObservationDate);