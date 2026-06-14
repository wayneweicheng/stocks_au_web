-- Table: [Notification].[BetOddsScanHistory]

CREATE TABLE [Notification].[BetOddsScanHistory] (
    [ScanHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
    [MonitorID] [int] NOT NULL,
    [CriterionID] [int] NULL,
    [ScannedAtUtc] [datetime2](0) NOT NULL DEFAULT (sysutcdatetime()),
    [Status] [varchar](20) NOT NULL,
    [ObservedOdds] [decimal](10,4) NULL,
    [WasMatched] [bit] NULL,
    [AlertQueued] [bit] NOT NULL DEFAULT ((0)),
    [Message] [nvarchar](2000) NULL,
    CONSTRAINT [PK_Notification_BetOddsScanHistory] PRIMARY KEY ([ScanHistoryID]),
    CONSTRAINT [FK_BetOddsScanHistory_Monitor] FOREIGN KEY ([MonitorID])
        REFERENCES [Notification].[BetOddsMonitors] ([MonitorID]) ON DELETE CASCADE
);

CREATE INDEX [IX_BetOddsScanHistory_MonitorScanned]
    ON [Notification].[BetOddsScanHistory] ([MonitorID], [ScannedAtUtc] DESC);

