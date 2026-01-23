-- Table: [Notification].[MessageQueue]

CREATE TABLE [Notification].[MessageQueue] (
    [MessageID] [bigint] IDENTITY(1,1) NOT NULL,
    [EventType] [varchar](50) NOT NULL,
    [EventSourceID] [nvarchar](100) NULL,
    [EventSourceTable] [nvarchar](200) NULL,
    [EventData] [nvarchar](MAX) NULL,
    [MessageTitle] [nvarchar](255) NOT NULL,
    [MessageBody] [nvarchar](MAX) NOT NULL,
    [MessageURL] [nvarchar](500) NULL,
    [MessageMetadata] [nvarchar](MAX) NULL,
    [TargetUserID] [int] NULL,
    [TargetRole] [varchar](50) NULL,
    [SubscriptionContext] [nvarchar](MAX) NULL,
    [NotificationChannel] [varchar](20) NOT NULL DEFAULT ('pushover'),
    [Priority] [int] NOT NULL DEFAULT ((0)),
    [ScheduledSendDate] [datetime] NOT NULL DEFAULT (getdate()),
    [Status] [varchar](20) NOT NULL DEFAULT ('pending'),
    [ProcessingStarted] [datetime] NULL,
    [ProcessedDate] [datetime] NULL,
    [SentDate] [datetime] NULL,
    [RetryCount] [int] NOT NULL DEFAULT ((0)),
    [MaxRetries] [int] NOT NULL DEFAULT ((3)),
    [LastRetryDate] [datetime] NULL,
    [ErrorMessage] [nvarchar](MAX) NULL,
    [ErrorStackTrace] [nvarchar](MAX) NULL,
    [QueuedDate] [datetime] NOT NULL DEFAULT (getdate()),
    [QueuedBy] [nvarchar](100) NULL,
    [ExternalMessageID] [nvarchar](100) NULL
,
    CONSTRAINT [PK_Notification_MessageQueue] PRIMARY KEY (MessageID)
);

ALTER TABLE [Notification].[MessageQueue] ADD CONSTRAINT [FK_MessageQueue_TargetUser] FOREIGN KEY (TargetUserID) REFERENCES [Notification].[Users] (UserID);
CREATE INDEX [IX_MessageQueue_Channel_Status] ON [Notification].[MessageQueue] (NotificationChannel, Status);
CREATE INDEX [IX_MessageQueue_EventType] ON [Notification].[MessageQueue] (EventType);
CREATE INDEX [IX_MessageQueue_QueuedDate] ON [Notification].[MessageQueue] (QueuedDate);
CREATE INDEX [IX_MessageQueue_Status_Scheduled] ON [Notification].[MessageQueue] (NotificationChannel, Priority, Status, ScheduledSendDate);
CREATE INDEX [IX_MessageQueue_TargetUser] ON [Notification].[MessageQueue] (TargetUserID);