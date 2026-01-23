-- Stored procedure: [Notification].[usp_RecordNotificationDelivery]


CREATE PROCEDURE [Notification].[usp_RecordNotificationDelivery]
    @pintQueueID INT,
    @pvchDeliveryStatus VARCHAR(20),  -- 'delivered', 'failed', 'rejected'
    @pvchExternalMessageID NVARCHAR(100) = NULL,
    @pvchErrorMessage NVARCHAR(MAX) = NULL,
    @pvchMessageTitle NVARCHAR(255) = NULL,
    @pvchMessageBody NVARCHAR(MAX) = NULL,
    @pvchWebPageURL NVARCHAR(500) = NULL,
    @pbitDebug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT, @SubscriptionID INT, @AnnouncementID INT, @Channel VARCHAR(20);

    -- Get queue details
    SELECT
        @UserID = UserID,
        @SubscriptionID = SubscriptionID,
        @AnnouncementID = AnnouncementID,
        @Channel = NotificationChannel
    FROM [Notification].[NotificationQueue]
    WHERE QueueID = @pintQueueID;

    IF @UserID IS NULL
    BEGIN
        IF @pbitDebug = 1
            PRINT 'Debug: QueueID not found: ' + CAST(@pintQueueID AS VARCHAR);
        RETURN 0;
    END

    -- Update queue status
    UPDATE [Notification].[NotificationQueue]
    SET
        Status = CASE WHEN @pvchDeliveryStatus = 'delivered' THEN 'sent' ELSE 'failed' END,
        SentDate = CASE WHEN @pvchDeliveryStatus = 'delivered' THEN GETDATE() ELSE NULL END,
        ProcessedDate = GETDATE(),
        ErrorMessage = @pvchErrorMessage
    WHERE QueueID = @pintQueueID;

    -- Insert into history
    INSERT INTO [Notification].[NotificationHistory] (
        UserID,
        SubscriptionID,
        AnnouncementID,
        QueueID,
        NotificationChannel,
        MessageTitle,
        MessageBody,
        WebPageURL,
        DeliveryStatus,
        ExternalMessageID,
        ErrorMessage
    )
    VALUES (
        @UserID,
        @SubscriptionID,
        @AnnouncementID,
        @pintQueueID,
        @Channel,
        @pvchMessageTitle,
        @pvchMessageBody,
        @pvchWebPageURL,
        @pvchDeliveryStatus,
        @pvchExternalMessageID,
        @pvchErrorMessage
    );

    -- Update last notification date on subscription
    UPDATE [Notification].[UserStockSubscriptions]
    SET LastNotificationDate = GETDATE()
    WHERE SubscriptionID = @SubscriptionID;

    IF @pbitDebug = 1
        PRINT 'Debug: Recorded notification delivery for QueueID=' + CAST(@pintQueueID AS VARCHAR);

    RETURN 1;
END
