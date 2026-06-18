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
    [LastCheckedAtUtc] [datetime2] NULL,
    [LastMatchedAtUtc] [datetime2] NULL,
    [LastAlertAtUtc] [datetime2] NULL,
    [AlertCount] [int] NOT NULL DEFAULT ((0)),
    [IsCurrentlyMatched] [bit] NOT NULL DEFAULT ((0)),
    [CreatedDateUtc] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [UpdatedDateUtc] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK__BetOddsC__647C3BD109529F61] PRIMARY KEY (CriterionID)
);

ALTER TABLE [Notification].[BetOddsCriteria] ADD CONSTRAINT [FK_BetOddsCriteria_Monitor] FOREIGN KEY (MonitorID) REFERENCES [Notification].[BetOddsMonitors] (MonitorID);
CREATE INDEX [IX_BetOddsCriteria_MonitorID] ON [Notification].[BetOddsCriteria] (MonitorID);