-- Table: [Execution].[OptionEdgeAudit]

CREATE TABLE [Execution].[OptionEdgeAudit] (
    [AuditId] [int] IDENTITY(1,1) NOT NULL,
    [RunId] [nvarchar](100) NOT NULL,
    [TradingDate] [date] NOT NULL,
    [EventType] [nvarchar](50) NOT NULL,
    [OrderId] [int] NULL,
    [IBOrderId] [int] NULL,
    [ExecutionId] [nvarchar](100) NULL,
    [EventData] [nvarchar](MAX) NULL,
    [FillNotional] [decimal](18,2) NULL,
    [CumulativeNotional] [decimal](18,2) NULL,
    [Timestamp] [datetime2] NOT NULL DEFAULT (getutcdate())
,
    CONSTRAINT [PK__OptionEd__A17F239871BDE05B] PRIMARY KEY (AuditId)
);

CREATE INDEX [IX_OptionEdgeAudit_EventType] ON [Execution].[OptionEdgeAudit] (EventType);
CREATE INDEX [IX_OptionEdgeAudit_ExecutionId] ON [Execution].[OptionEdgeAudit] (ExecutionId);
CREATE INDEX [IX_OptionEdgeAudit_RunId] ON [Execution].[OptionEdgeAudit] (RunId);
CREATE INDEX [IX_OptionEdgeAudit_Timestamp] ON [Execution].[OptionEdgeAudit] (Timestamp);
CREATE INDEX [IX_OptionEdgeAudit_TradingDate] ON [Execution].[OptionEdgeAudit] (TradingDate);