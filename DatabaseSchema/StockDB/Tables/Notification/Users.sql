-- Table: [Notification].[Users]

CREATE TABLE [Notification].[Users] (
    [UserID] [int] IDENTITY(1,1) NOT NULL,
    [Email] [nvarchar](255) NOT NULL,
    [DisplayName] [nvarchar](100) NULL,
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [CreatedDate] [datetime] NOT NULL DEFAULT (getdate()),
    [UpdatedDate] [datetime] NOT NULL DEFAULT (getdate()),
    [PushoverUserKey] [nvarchar](50) NULL,
    [PushoverEnabled] [bit] NOT NULL DEFAULT ((1)),
    [SMSPhoneNumber] [nvarchar](20) NULL,
    [SMSEnabled] [bit] NOT NULL DEFAULT ((0)),
    [DiscordWebhook] [nvarchar](500) NULL,
    [DiscordEnabled] [bit] NOT NULL DEFAULT ((0)),
    [NotificationFrequency] [varchar](20) NOT NULL DEFAULT ('immediate'),
    [QuietHoursStart] [time] NULL,
    [QuietHoursEnd] [time] NULL,
    [Timezone] [nvarchar](50) NOT NULL DEFAULT ('Australia/Sydney')
,
    CONSTRAINT [PK_Notification_Users] PRIMARY KEY (UserID)
);

CREATE INDEX [IX_Notification_Users_Email] ON [Notification].[Users] (Email);
CREATE INDEX [IX_Notification_Users_IsActive] ON [Notification].[Users] (IsActive);
CREATE UNIQUE INDEX [UK_Notification_Users_Email] ON [Notification].[Users] (Email);