-- Table: [Notification].[BetOddsMonitors]

CREATE TABLE [Notification].[BetOddsMonitors] (
    [MonitorID] [int] IDENTITY(1,1) NOT NULL,
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
    CONSTRAINT [PK_Notification_BetOddsMonitors] PRIMARY KEY ([MonitorID]),
    CONSTRAINT [CK_BetOddsMonitors_ScanInterval] CHECK ([ScanIntervalMinutes] BETWEEN 1 AND 1440),
    CONSTRAINT [FK_BetOddsMonitors_TargetUser] FOREIGN KEY ([TargetUserID])
        REFERENCES [Notification].[Users] ([UserID])
);

CREATE INDEX [IX_BetOddsMonitors_Due]
    ON [Notification].[BetOddsMonitors] ([IsActive], [ExpiresAtUtc], [NextScanAtUtc]);

