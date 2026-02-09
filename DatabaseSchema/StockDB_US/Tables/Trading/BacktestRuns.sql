-- Table: [Trading].[BacktestRuns]

CREATE TABLE [Trading].[BacktestRuns] (
    [BacktestRunId] [uniqueidentifier] NOT NULL,
    [StartedAt] [datetime] NOT NULL,
    [EndedAt] [datetime] NULL,
    [StrategyCode] [varchar](50) NULL,
    [StockCode] [varchar](15) NULL,
    [TimeFrame] [varchar](10) NULL,
    [OrderSourceMode] [varchar](10) NULL,
    [Notes] [varchar](500) NULL
,
    CONSTRAINT [PK__Backtest__B90610CDB9BE1719] PRIMARY KEY (BacktestRunId)
);
