-- Table: [Notification].[SubscriptionTypes]

CREATE TABLE [Notification].[SubscriptionTypes] (
    [SubscriptionTypeID] [int] IDENTITY(1,1) NOT NULL,
    [SubscriptionTypeCode] [varchar](100) NOT NULL,
    [EventType] [varchar](50) NOT NULL,
    [DisplayName] [nvarchar](200) NOT NULL,
    [Description] [nvarchar](500) NULL,
    [RequiresTriggerValue] [bit] NOT NULL DEFAULT ((0)),
    [TriggerValueType] [varchar](20) NULL,
    [TriggerValueMin] [decimal](18,6) NULL,
    [TriggerValueMax] [decimal](18,6) NULL,
    [TriggerValueUnit] [nvarchar](20) NULL,
    [RequiresTriggerValue2] [bit] NOT NULL DEFAULT ((0)),
    [TriggerValue2Type] [varchar](20) NULL,
    [SupportsTextFilter] [bit] NOT NULL DEFAULT ((0)),
    [SupportsPriorityLevels] [bit] NOT NULL DEFAULT ((0)),
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [SortOrder] [int] NOT NULL DEFAULT ((0)),
    [CreatedDate] [datetime] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK_Notification_SubscriptionTypes] PRIMARY KEY (SubscriptionTypeID)
);

CREATE INDEX [IX_SubscriptionTypes_EventType] ON [Notification].[SubscriptionTypes] (EventType, IsActive);
CREATE UNIQUE INDEX [UK_Notification_SubscriptionTypes_Code] ON [Notification].[SubscriptionTypes] (SubscriptionTypeCode);