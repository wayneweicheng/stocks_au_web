/*
    Manual additive DDL: StockDB.[Notification].[MessageQueue]

    Apply only after reviewing the existing queue consumers and taking a
    StockDB backup. This changes the existing generic notification queue but
    preserves NULL idempotency for legacy announcements.

    Do not change existing Status values or existing rows in this script.
    Stored procedure/handler changes are a separate implementation task.
*/

USE [StockDB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'[Notification].[MessageQueue]', N'IdempotencyKey') IS NULL
    ALTER TABLE [Notification].[MessageQueue] ADD [IdempotencyKey] nvarchar(200) NULL;
GO

IF COL_LENGTH(N'[Notification].[MessageQueue]', N'LeaseOwner') IS NULL
    ALTER TABLE [Notification].[MessageQueue] ADD [LeaseOwner] nvarchar(100) NULL;
GO

IF COL_LENGTH(N'[Notification].[MessageQueue]', N'LeaseExpiresDate') IS NULL
    ALTER TABLE [Notification].[MessageQueue] ADD [LeaseExpiresDate] datetime2(3) NULL;
GO

IF COL_LENGTH(N'[Notification].[MessageQueue]', N'DeliveryStateDetail') IS NULL
    ALTER TABLE [Notification].[MessageQueue] ADD [DeliveryStateDetail] nvarchar(50) NULL;
GO

IF COL_LENGTH(N'[Notification].[MessageQueue]', N'QueueRowVersion') IS NULL
    ALTER TABLE [Notification].[MessageQueue] ADD [QueueRowVersion] rowversion;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE [name] = N'UX_Notification_MessageQueue_IdempotencyKey'
      AND [object_id] = OBJECT_ID(N'[Notification].[MessageQueue]')
)
BEGIN
    CREATE UNIQUE INDEX [UX_Notification_MessageQueue_IdempotencyKey]
        ON [Notification].[MessageQueue] ([IdempotencyKey])
        WHERE [IdempotencyKey] IS NOT NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE [name] = N'IX_Notification_MessageQueue_Claimable'
      AND [object_id] = OBJECT_ID(N'[Notification].[MessageQueue]')
)
BEGIN
    CREATE INDEX [IX_Notification_MessageQueue_Claimable]
        ON [Notification].[MessageQueue]
        ([NotificationChannel], [Status], [Priority] DESC, [ScheduledSendDate], [MessageID])
        INCLUDE ([IdempotencyKey], [LeaseOwner], [LeaseExpiresDate], [EventType], [EventSourceID]);
END;
GO
