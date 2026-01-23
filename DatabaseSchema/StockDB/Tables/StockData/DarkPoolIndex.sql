-- Table: [StockData].[DarkPoolIndex]

CREATE TABLE [StockData].[DarkPoolIndex] (
    [IndexCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [Price] [decimal](20,4) NULL,
    [Dix] [decimal](20,4) NULL,
    [Gex] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
