-- Table: [Notification].[BetOddsScanHistory]

CREATE TABLE [Notification].[BetOddsScanHistory] (
    [ScanHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
    [MonitorID] [int] NOT NULL,
    [CriterionID] [int] NULL,
    [ScannedAtUtc] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [Status] [varchar](20) NOT NULL,
    [ObservedOdds] [decimal](10,4) NULL,
    [WasMatched] [bit] NULL,
    [AlertQueued] [bit] NOT NULL DEFAULT ((0)),
    [Message] [nvarchar](2000) NULL
,
    CONSTRAINT [PK__BetOddsS__3AC3D45726F6BF3C] PRIMARY KEY (ScanHistoryID)
);

ALTER TABLE [Notification].[BetOddsScanHistory] ADD CONSTRAINT [FK_BetOddsScanHistory_Monitor] FOREIGN KEY (MonitorID) REFERENCES [Notification].[BetOddsMonitors] (MonitorID);
CREATE INDEX [IX_BetOddsScanHistory_MonitorScanned] ON [Notification].[BetOddsScanHistory] (MonitorID, ScannedAtUtc);