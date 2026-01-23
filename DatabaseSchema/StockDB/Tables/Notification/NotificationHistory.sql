-- Table: [Notification].[NotificationHistory]

CREATE TABLE [Notification].[NotificationHistory] (
    [HistoryID] [int] IDENTITY(1,1) NOT NULL,
    [UserID] [int] NOT NULL,
    [SubscriptionID] [int] NOT NULL,
    [AnnouncementID] [int] NOT NULL,
    [QueueID] [int] NULL,
    [NotificationChannel] [varchar](20) NOT NULL,
    [MessageTitle] [nvarchar](255) NULL,
    [MessageBody] [nvarchar](MAX) NULL,
    [WebPageURL] [nvarchar](500) NULL,
    [SentDate] [datetime] NOT NULL DEFAULT (getdate()),
    [DeliveryStatus] [varchar](20) NOT NULL,
    [ExternalMessageID] [nvarchar](100) NULL,
    [ReadDate] [datetime] NULL,
    [ClickedDate] [datetime] NULL,
    [AnalysisRequested] [bit] NOT NULL DEFAULT ((0)),
    [AnalysisRequestedDate] [datetime] NULL,
    [ErrorMessage] [nvarchar](MAX) NULL,
    [RetryCount] [int] NOT NULL DEFAULT ((0))
,
    CONSTRAINT [PK_Notification_NotificationHistory] PRIMARY KEY (HistoryID)
);

ALTER TABLE [Notification].[NotificationHistory] ADD CONSTRAINT [FK_Notification_NotificationHistory_Users] FOREIGN KEY (UserID) REFERENCES [Notification].[Users] (UserID);
CREATE INDEX [IX_Notification_NotificationHistory_AnnouncementID] ON [Notification].[NotificationHistory] (AnnouncementID);
CREATE INDEX [IX_Notification_NotificationHistory_DeliveryStatus] ON [Notification].[NotificationHistory] (DeliveryStatus);
CREATE INDEX [IX_Notification_NotificationHistory_SentDate] ON [Notification].[NotificationHistory] (SentDate);
CREATE INDEX [IX_Notification_NotificationHistory_UserID] ON [Notification].[NotificationHistory] (UserID);