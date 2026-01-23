-- Table: [StockData].[TotalGex]

CREATE TABLE [StockData].[TotalGex] (
    [TotalGexID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TimeFrame] [varchar](50) NOT NULL,
    [ClosePrice] [decimal](20,4) NULL,
    [ObservationDate] [date] NULL,
    [GEX] [decimal](20,4) NOT NULL,
    [CreateDate] [datetime] NULL
);
