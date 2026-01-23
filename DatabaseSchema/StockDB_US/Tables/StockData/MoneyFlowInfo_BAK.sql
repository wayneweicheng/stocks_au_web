-- Table: [StockData].[MoneyFlowInfo_BAK]

CREATE TABLE [StockData].[MoneyFlowInfo_BAK] (
    [MoneyFlowInfoID] [bigint] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [StockCode] [varchar](10) NULL,
    [MoneyFlowType] [varchar](200) NULL,
    [ObservationDate] [date] NULL,
    [MoneyFlowDirection] [varchar](10) NULL,
    [Ranking] [int] NULL,
    [TotalStocks] [int] NULL,
    [LastValidateDate] [smalldatetime] NULL
);
