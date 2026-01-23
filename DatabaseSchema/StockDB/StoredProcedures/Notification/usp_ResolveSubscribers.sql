-- Stored procedure: [Notification].[usp_ResolveSubscribers]


CREATE PROCEDURE [Notification].[usp_ResolveSubscribers]
    @pbigMessageID BIGINT,
    @pbitDebug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetUserID INT, @SubscriptionContext NVARCHAR(MAX), @EventType VARCHAR(50);

    -- Get message details
    SELECT
        @TargetUserID = TargetUserID,
        @SubscriptionContext = SubscriptionContext,
        @EventType = EventType
    FROM [Notification].[MessageQueue]
    WHERE MessageID = @pbigMessageID;

    -- If TargetUserID is specified, return that user
    IF @TargetUserID IS NOT NULL
    BEGIN
        SELECT
            u.UserID,
            u.Email,
            u.DisplayName,
            u.PushoverUserKey,
            u.PushoverEnabled,
            u.SMSPhoneNumber,
            u.SMSEnabled,
            u.DiscordWebhook,
            u.DiscordEnabled,
            u.Timezone,
            u.QuietHoursStart,
            u.QuietHoursEnd
        FROM [Notification].[Users] u
        WHERE u.UserID = @TargetUserID
            AND u.IsActive = 1;

        RETURN;
    END

    -- Otherwise, resolve based on SubscriptionContext
    -- This is event-type specific logic

    IF @EventType = 'announcement' AND @SubscriptionContext IS NOT NULL
    BEGIN
        -- Parse JSON context (example: {"asx_code":"KAL.AX","is_price_sensitive":true})
        DECLARE @ASXCode NVARCHAR(20), @IsPriceSensitive BIT;

        SELECT
            @ASXCode = JSON_VALUE(@SubscriptionContext, '$.asx_code'),
            @IsPriceSensitive = CAST(JSON_VALUE(@SubscriptionContext, '$.is_price_sensitive') AS BIT);

        -- Use existing stored procedure
        EXEC [Notification].[usp_GetSubscribersForAnnouncement]
            @pvchASXCode = @ASXCode,
            @pintIsPriceSensitive = @IsPriceSensitive,
            @pbitDebug = @pbitDebug;
    END
    ELSE IF @EventType = 'price_alert'
    BEGIN
        -- Future: implement price alert subscription matching
        SELECT u.* FROM [Notification].[Users] u WHERE 1=0;  -- Placeholder
    END
    ELSE
    BEGIN
        -- Default: no subscribers (or could be all admins, etc.)
        SELECT u.* FROM [Notification].[Users] u WHERE 1=0;
    END
END
