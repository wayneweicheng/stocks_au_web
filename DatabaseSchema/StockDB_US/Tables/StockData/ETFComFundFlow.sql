-- Table: [StockData].[ETFComFundFlow]

CREATE TABLE [StockData].[ETFComFundFlow] (
    [ETFComFundFlowID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Ticker] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [FundFlow] [decimal](18,2) NULL,
    [AUM] [decimal](18,2) NULL,
    [SharesOutstanding] [bigint] NULL,
    [NavPrice] [decimal](18,4) NULL,
    [ClosePrice] [decimal](18,4) NULL,
    [Volume] [bigint] NULL,
    [CreateDate] [datetime] NOT NULL DEFAULT (getdate()),
    [LastUpdateDate] [datetime] NULL
,
    CONSTRAINT [PK_ETFComFundFlow] PRIMARY KEY (ASXCode, ObservationDate)
);

CREATE INDEX [IX_ETFComFundFlow_ObservationDate] ON [StockData].[ETFComFundFlow] (ObservationDate);
CREATE INDEX [IX_ETFComFundFlow_Ticker_ObservationDate] ON [StockData].[ETFComFundFlow] (Ticker, ObservationDate);