-- Table: [Transform].[BrokerTxCaptureRun]

CREATE TABLE [Transform].[BrokerTxCaptureRun] (
    [BrokerTxCaptureRunID] [bigint] IDENTITY(1,1) NOT NULL,
    [RunDate] [date] NOT NULL,
    [WindowStartDate] [date] NOT NULL,
    [WindowEndDate] [date] NOT NULL,
    [TriggerMode] [varchar](20) NOT NULL,
    [CandidateCount] [int] NULL,
    [ArchivedRowCount] [bigint] NULL,
    [CoverageRowCount] [int] NULL,
    [SourceMaxObservationDate] [date] NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerTxCaptureRun] PRIMARY KEY (BrokerTxCaptureRunID)
);

CREATE INDEX [IX_Transform_BrokerTxCaptureRun_RunDate] ON [Transform].[BrokerTxCaptureRun] (RunDate, TriggerMode);