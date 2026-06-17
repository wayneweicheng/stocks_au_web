-- Table: [Notification].[BetOddsCriteria]

CREATE TABLE [Notification].[BetOddsCriteria] (
    [CriterionID] [int] IDENTITY(1,1) NOT NULL,
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
    CONSTRAINT [PK_Notification_BetOddsCriteria] PRIMARY KEY ([CriterionID]),
    CONSTRAINT [FK_BetOddsCriteria_Monitor] FOREIGN KEY ([MonitorID])
        REFERENCES [Notification].[BetOddsMonitors] ([MonitorID]) ON DELETE CASCADE,
    CONSTRAINT [CK_BetOddsCriteria_Operator]
        CHECK ([ComparisonOperator] IN ('>=', '>', '<=', '<', '=')),
    CONSTRAINT [CK_BetOddsCriteria_TargetOdds] CHECK ([TargetOdds] > 0)
);

CREATE INDEX [IX_BetOddsCriteria_MonitorID]
    ON [Notification].[BetOddsCriteria] ([MonitorID]);

