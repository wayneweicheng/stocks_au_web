IF OBJECT_ID(N'[Notification].[BetOddsMonitors]', N'U') IS NULL
BEGIN
    CREATE TABLE [Notification].[BetOddsMonitors] (
        [MonitorID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [Name] [nvarchar](200) NOT NULL,
        [SourceURL] [nvarchar](1000) NOT NULL,
        [SportName] [nvarchar](100) NOT NULL,
        [CompetitionName] [nvarchar](200) NOT NULL,
        [TournamentName] [nvarchar](200) NULL,
        [MatchName] [nvarchar](200) NOT NULL,
        [TargetUserID] [int] NOT NULL,
        [ScanIntervalMinutes] [int] NOT NULL DEFAULT ((10)),
        [ExpiresAtUtc] [datetime2](0) NOT NULL,
        [AlertOnce] [bit] NOT NULL DEFAULT ((1)),
        [IsActive] [bit] NOT NULL DEFAULT ((1)),
        [LastScanAtUtc] [datetime2](0) NULL,
        [NextScanAtUtc] [datetime2](0) NULL,
        [LastSuccessAtUtc] [datetime2](0) NULL,
        [LastError] [nvarchar](2000) NULL,
        [CreatedDateUtc] [datetime2](0) NOT NULL DEFAULT (sysutcdatetime()),
        [UpdatedDateUtc] [datetime2](0) NOT NULL DEFAULT (sysutcdatetime()),
        CONSTRAINT [CK_BetOddsMonitors_ScanInterval] CHECK ([ScanIntervalMinutes] BETWEEN 1 AND 1440),
        CONSTRAINT [FK_BetOddsMonitors_TargetUser] FOREIGN KEY ([TargetUserID])
            REFERENCES [Notification].[Users] ([UserID])
    );
    CREATE INDEX [IX_BetOddsMonitors_Due]
        ON [Notification].[BetOddsMonitors] ([IsActive], [ExpiresAtUtc], [NextScanAtUtc]);
END;

IF OBJECT_ID(N'[Notification].[BetOddsCriteria]', N'U') IS NULL
BEGIN
    CREATE TABLE [Notification].[BetOddsCriteria] (
        [CriterionID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [MonitorID] [int] NOT NULL,
        [MarketName] [nvarchar](250) NOT NULL,
        [SelectionName] [nvarchar](250) NOT NULL,
        [PropositionID] [nvarchar](100) NULL,
        [ComparisonOperator] [varchar](4) NOT NULL,
        [TargetOdds] [decimal](10,4) NOT NULL,
        [LatestOdds] [decimal](10,4) NULL,
        [PreviousOdds] [decimal](10,4) NULL,
        [LastCheckedAtUtc] [datetime2](0) NULL,
        [LastMatchedAtUtc] [datetime2](0) NULL,
        [LastAlertAtUtc] [datetime2](0) NULL,
        [AlertCount] [int] NOT NULL DEFAULT ((0)),
        [IsCurrentlyMatched] [bit] NOT NULL DEFAULT ((0)),
        [CreatedDateUtc] [datetime2](0) NOT NULL DEFAULT (sysutcdatetime()),
        [UpdatedDateUtc] [datetime2](0) NOT NULL DEFAULT (sysutcdatetime()),
        CONSTRAINT [FK_BetOddsCriteria_Monitor] FOREIGN KEY ([MonitorID])
            REFERENCES [Notification].[BetOddsMonitors] ([MonitorID]) ON DELETE CASCADE,
        CONSTRAINT [CK_BetOddsCriteria_Operator]
            CHECK ([ComparisonOperator] IN ('>=', '>', '<=', '<', '=')),
        CONSTRAINT [CK_BetOddsCriteria_TargetOdds] CHECK ([TargetOdds] > 0)
    );
    CREATE INDEX [IX_BetOddsCriteria_MonitorID]
        ON [Notification].[BetOddsCriteria] ([MonitorID]);
END;

IF OBJECT_ID(N'[Notification].[BetOddsScanHistory]', N'U') IS NULL
BEGIN
    CREATE TABLE [Notification].[BetOddsScanHistory] (
        [ScanHistoryID] [bigint] IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [MonitorID] [int] NOT NULL,
        [CriterionID] [int] NULL,
        [ScannedAtUtc] [datetime2](0) NOT NULL DEFAULT (sysutcdatetime()),
        [Status] [varchar](20) NOT NULL,
        [ObservedOdds] [decimal](10,4) NULL,
        [WasMatched] [bit] NULL,
        [AlertQueued] [bit] NOT NULL DEFAULT ((0)),
        [Message] [nvarchar](2000) NULL,
        CONSTRAINT [FK_BetOddsScanHistory_Monitor] FOREIGN KEY ([MonitorID])
            REFERENCES [Notification].[BetOddsMonitors] ([MonitorID]) ON DELETE CASCADE
    );
    CREATE INDEX [IX_BetOddsScanHistory_MonitorScanned]
        ON [Notification].[BetOddsScanHistory] ([MonitorID], [ScannedAtUtc] DESC);
END;

