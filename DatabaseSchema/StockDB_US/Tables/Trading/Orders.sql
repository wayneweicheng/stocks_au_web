-- Table: [Trading].[Orders]

CREATE TABLE [Trading].[Orders] (
    [OrderId] [bigint] IDENTITY(1,1) NOT NULL,
    [StrategyId] [int] NOT NULL,
    [StockCode] [varchar](15) NOT NULL,
    [Side] [char](1) NOT NULL DEFAULT ('B'),
    [OrderSourceType] [varchar](20) NOT NULL DEFAULT ('MANUAL'),
    [SignalType] [varchar](50) NULL,
    [TimeFrame] [varchar](10) NOT NULL DEFAULT ('5M'),
    [EntryType] [varchar](10) NOT NULL DEFAULT ('LIMIT'),
    [EntryPrice] [decimal](20,4) NULL,
    [Quantity] [int] NOT NULL,
    [ProfitTargetPrice] [decimal](20,4) NULL,
    [StopLossPrice] [decimal](20,4) NULL,
    [StopLossMode] [varchar](20) NOT NULL DEFAULT ('BAR_CLOSE'),
    [Status] [varchar](20) NOT NULL DEFAULT ('PENDING'),
    [EntryPlacedAt] [datetime] NULL,
    [EntryFilledAt] [datetime] NULL,
    [ExitPlacedAt] [datetime] NULL,
    [ExitFilledAt] [datetime] NULL,
    [StoplossPlacedAt] [datetime] NULL,
    [StoplossFilledAt] [datetime] NULL,
    [BacktestRunId] [uniqueidentifier] NULL,
    [CreatedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [UpdatedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [MetaJson] [nvarchar](MAX) NULL
,
    CONSTRAINT [PK__Orders__C3905BCF09F945BB] PRIMARY KEY (OrderId)
);

ALTER TABLE [Trading].[Orders] ADD CONSTRAINT [FK_Orders_Strategy] FOREIGN KEY (StrategyId) REFERENCES [Trading].[Strategy] (StrategyId);
ALTER TABLE [Trading].[Orders] ADD CONSTRAINT [FK_Orders_SignalType] FOREIGN KEY (SignalType) REFERENCES [Trading].[SignalType] (SignalType);
ALTER TABLE [Trading].[Orders] ADD CONSTRAINT [FK_Orders_BacktestRuns] FOREIGN KEY (BacktestRunId) REFERENCES [Trading].[BacktestRuns] (BacktestRunId);
CREATE INDEX [IX_Orders_Stock_Status_TimeFrame] ON [Trading].[Orders] (StockCode, Status, TimeFrame);