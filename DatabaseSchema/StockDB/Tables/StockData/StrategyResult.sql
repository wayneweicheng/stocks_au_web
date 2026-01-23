-- Table: [StockData].[StrategyResult]

CREATE TABLE [StockData].[StrategyResult] (
    [StrategyResultID] [int] IDENTITY(1,1) NOT NULL,
    [TradeStrategyID] [int] NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [StrategyResult] [varchar](MAX) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
