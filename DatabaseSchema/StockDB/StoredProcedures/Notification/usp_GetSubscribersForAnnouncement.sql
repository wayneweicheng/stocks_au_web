-- Stored procedure: [Notification].[usp_GetSubscribersForAnnouncement]


-- ============================================================================
-- Create new version using generic subscription system
-- ============================================================================
CREATE PROCEDURE [Notification].[usp_GetSubscribersForAnnouncement]
    @pvchASXCode NVARCHAR(20),
    @pintIsPriceSensitive INT,  -- 1 = price sensitive, 0 = not
    @pbitDebug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @pbitDebug = 1
    BEGIN
        PRINT 'Debug: Getting subscribers for ASXCode=' + @pvchASXCode + ', IsPriceSensitive=' + CAST(@pintIsPriceSensitive AS VARCHAR);
    END

    -- Determine which subscription types to match
    DECLARE @SubscriptionTypes TABLE (SubscriptionTypeCode VARCHAR(100));

    IF @pintIsPriceSensitive = 1
    BEGIN
        -- Price-sensitive announcement: match "price_sensitive_only" and "all"
        INSERT INTO @SubscriptionTypes VALUES ('announcement_price_sensitive_only');
        INSERT INTO @SubscriptionTypes VALUES ('announcement_all');
    END
    ELSE
    BEGIN
        -- Non-price-sensitive announcement: match "non_price_sensitive_only" and "all"
        INSERT INTO @SubscriptionTypes VALUES ('announcement_non_price_sensitive_only');
        INSERT INTO @SubscriptionTypes VALUES ('announcement_all');
    END

    -- Get subscribers using new UserSubscriptions table
    SELECT
        u.UserID,
        u.Email,
        u.DisplayName,
        u.PushoverUserKey,
        u.PushoverEnabled,
        u.NotificationFrequency,
        u.QuietHoursStart,
        u.QuietHoursEnd,
        u.Timezone,
        s.SubscriptionID,
        s.EntityCode,
        st.SubscriptionTypeCode,
        s.IncludeKeywords,
        s.ExcludeKeywords,
        s.Priority,
        s.NotificationChannel
    FROM [Notification].[UserSubscriptions] s
    INNER JOIN [Notification].[Users] u ON s.UserID = u.UserID
    INNER JOIN [Notification].[SubscriptionTypes] st ON s.SubscriptionTypeID = st.SubscriptionTypeID
    WHERE
        u.IsActive = 1
        AND s.IsActive = 1
        AND s.EntityCode = @pvchASXCode
        AND st.SubscriptionTypeCode IN (SELECT SubscriptionTypeCode FROM @SubscriptionTypes)
        AND u.PushoverEnabled = 1  -- Only get users with Pushover enabled (for now)
        AND u.PushoverUserKey IS NOT NULL;

    IF @pbitDebug = 1
    BEGIN
        PRINT 'Debug: Found ' + CAST(@@ROWCOUNT AS VARCHAR) + ' subscribers';
    END
END
