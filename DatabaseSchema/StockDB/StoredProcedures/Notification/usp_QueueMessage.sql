-- Stored procedure: [Notification].[usp_QueueMessage]


CREATE PROCEDURE [Notification].[usp_QueueMessage]
    -- Event details
    @pvchEventType VARCHAR(50),
    @pvchEventSourceID NVARCHAR(100) = NULL,
    @pvchEventSourceTable NVARCHAR(200) = NULL,
    @pvchEventData NVARCHAR(MAX) = NULL,

    -- Message content (pre-formatted)
    @pvchMessageTitle NVARCHAR(255),
    @pvchMessageBody NVARCHAR(MAX),
    @pvchMessageURL NVARCHAR(500) = NULL,
    @pvchMessageMetadata NVARCHAR(MAX) = NULL,

    -- Target audience
    @pintTargetUserID INT = NULL,
    @pvchTargetRole VARCHAR(50) = NULL,
    @pvchSubscriptionContext NVARCHAR(MAX) = NULL,

    -- Delivery config
    @pvchNotificationChannel VARCHAR(20) = 'pushover',
    @pintPriority INT = 0,
    @pdtScheduledSendDate DATETIME = NULL,
    @pintMaxRetries INT = 3,

    -- Audit
    @pvchQueuedBy NVARCHAR(100) = NULL,

    -- Output
    @pbigMessageID BIGINT OUTPUT,
    @pbitDebug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Default scheduled send to now if not specified
    IF @pdtScheduledSendDate IS NULL
        SET @pdtScheduledSendDate = GETDATE();

    -- Validate required fields
    IF @pvchEventType IS NULL OR @pvchMessageTitle IS NULL OR @pvchMessageBody IS NULL
    BEGIN
        RAISERROR('EventType, MessageTitle, and MessageBody are required', 16, 1);
        RETURN -1;
    END

    -- Optional: Check for duplicate messages (based on EventSourceID + TargetUserID)
    -- Uncomment if you want to prevent duplicate queuing within a time window
    /*
    IF @pvchEventSourceID IS NOT NULL AND @pintTargetUserID IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1 FROM [Notification].[MessageQueue]
            WHERE EventSourceID = @pvchEventSourceID
                AND TargetUserID = @pintTargetUserID
                AND NotificationChannel = @pvchNotificationChannel
                AND QueuedDate > DATEADD(MINUTE, -5, GETDATE())  -- Within last 5 minutes
                AND Status IN ('pending', 'processing', 'sent')
        )
        BEGIN
            IF @pbitDebug = 1
                PRINT 'Debug: Duplicate message detected, skipping queue';
            SET @pbigMessageID = NULL;
            RETURN 0;
        END
    END
    */

    -- Insert into queue
    INSERT INTO [Notification].[MessageQueue] (
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
        MaxRetries,
        QueuedBy,
        Status
    )
    VALUES (
        @pvchEventType,
        @pvchEventSourceID,
        @pvchEventSourceTable,
        @pvchEventData,
        @pvchMessageTitle,
        @pvchMessageBody,
        @pvchMessageURL,
        @pvchMessageMetadata,
        @pintTargetUserID,
        @pvchTargetRole,
        @pvchSubscriptionContext,
        @pvchNotificationChannel,
        @pintPriority,
        @pdtScheduledSendDate,
        @pintMaxRetries,
        @pvchQueuedBy,
        'pending'
    );

    SET @pbigMessageID = SCOPE_IDENTITY();

    IF @pbitDebug = 1
    BEGIN
        PRINT 'Debug: Queued message with MessageID=' + CAST(@pbigMessageID AS VARCHAR);
        PRINT 'Debug: EventType=' + @pvchEventType + ', Channel=' + @pvchNotificationChannel;
    END

    RETURN 1;
END
