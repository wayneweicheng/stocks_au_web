-- Table: [Notification].[UserSubscriptions]

CREATE TABLE [Notification].[UserSubscriptions] (
    [SubscriptionID] [int] IDENTITY(1,1) NOT NULL,
    [UserID] [int] NOT NULL,
    [SubscriptionTypeID] [int] NOT NULL,
    [EntityCode] [nvarchar](50) NOT NULL,
    [TriggerValue] [decimal](18,6) NULL,
    [TriggerValue2] [decimal](18,6) NULL,
    [TriggerOperator] [varchar](20) NULL,
    [IncludeKeywords] [nvarchar](MAX) NULL,
    [ExcludeKeywords] [nvarchar](MAX) NULL,
    [ConfigurationJSON] [nvarchar](MAX) NULL,
    [Priority] [int] NOT NULL DEFAULT ((0)),
    [NotificationChannel] [varchar](20) NULL,
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [CreatedDate] [datetime] NOT NULL DEFAULT (getdate()),
    [UpdatedDate] [datetime] NOT NULL DEFAULT (getdate()),
    [LastTriggeredDate] [datetime] NULL,
    [TriggerCount] [int] NOT NULL DEFAULT ((0))
,
    CONSTRAINT [PK_Notification_UserSubscriptions] PRIMARY KEY (SubscriptionID)
);

ALTER TABLE [Notification].[UserSubscriptions] ADD CONSTRAINT [FK_UserSubscriptions_SubscriptionTypes] FOREIGN KEY (SubscriptionTypeID) REFERENCES [Notification].[SubscriptionTypes] (SubscriptionTypeID);
ALTER TABLE [Notification].[UserSubscriptions] ADD CONSTRAINT [FK_UserSubscriptions_Users] FOREIGN KEY (UserID) REFERENCES [Notification].[Users] (UserID);
CREATE INDEX [IX_UserSubscriptions_EntityCode] ON [Notification].[UserSubscriptions] (EntityCode, IsActive);
CREATE INDEX [IX_UserSubscriptions_LastTriggered] ON [Notification].[UserSubscriptions] (LastTriggeredDate);
CREATE INDEX [IX_UserSubscriptions_SubscriptionType] ON [Notification].[UserSubscriptions] (SubscriptionTypeID, IsActive);
CREATE INDEX [IX_UserSubscriptions_UserID] ON [Notification].[UserSubscriptions] (UserID, IsActive);
CREATE UNIQUE INDEX [UK_UserSubscriptions_UserTypeEntity] ON [Notification].[UserSubscriptions] (UserID, SubscriptionTypeID, EntityCode);