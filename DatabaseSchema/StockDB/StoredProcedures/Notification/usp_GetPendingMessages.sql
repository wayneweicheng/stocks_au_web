-- Stored procedure: [Notification].[usp_GetPendingMessages]

CREATE PROCEDURE [Notification].[usp_GetPendingMessages]
    @pvchNotificationChannel VARCHAR(20) = NULL,
    @pintBatchSize INT = 100,
    @pbitDebug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@pintBatchSize)
        MessageID,
        EventType,
        EventSourceID,
        EventSourceTable,
        EventData,
        MessageTitle,
        MessageBody,
        MessageURL,
        MessageMetadata,
        TargetUserID,
        TargetRole,
        SubscriptionContext,
        NotificationChannel,
        Priority,
        ScheduledSendDate,
        RetryCount,
        MaxRetries,
        QueuedBy,
        QueuedDate
    FROM [Notification].[MessageQueue]
    WHERE Status = 'pending'
      AND ScheduledSendDate <= GETDATE()
      AND RetryCount < MaxRetries
      AND (@pvchNotificationChannel IS NULL OR NotificationChannel = @pvchNotificationChannel)
    ORDER BY Priority DESC, ScheduledSendDate ASC;

    IF @pbitDebug = 1
        PRINT 'Debug: Returned ' + CAST(@@ROWCOUNT AS VARCHAR) + ' pending messages (non-locking)';
END;
