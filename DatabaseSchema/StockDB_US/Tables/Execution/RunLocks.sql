-- Table: [Execution].[RunLocks]

CREATE TABLE [Execution].[RunLocks] (
    [LockId] [int] IDENTITY(1,1) NOT NULL,
    [StrategyName] [nvarchar](100) NOT NULL,
    [TradingDate] [date] NOT NULL,
    [RunId] [nvarchar](100) NOT NULL,
    [Status] [nvarchar](20) NOT NULL,
    [AcquiredAt] [datetime2] NOT NULL DEFAULT (getutcdate()),
    [ReleasedAt] [datetime2] NULL,
    [RunMetadata] [nvarchar](MAX) NULL
,
    CONSTRAINT [PK__RunLocks__E7C1E2328A2AD0C0] PRIMARY KEY (LockId)
);

CREATE INDEX [IX_RunLocks_RunId] ON [Execution].[RunLocks] (RunId);
CREATE INDEX [IX_RunLocks_Status] ON [Execution].[RunLocks] (Status);
CREATE INDEX [IX_RunLocks_StrategyDate] ON [Execution].[RunLocks] (StrategyName, TradingDate);
CREATE UNIQUE INDEX [UQ_RunLocks_ActiveRun] ON [Execution].[RunLocks] (StrategyName, TradingDate, Status);