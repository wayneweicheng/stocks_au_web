-- Adds GEX Insights SPXW subscription types (Bullish, Bearish) if they do not already exist

IF NOT EXISTS (
    SELECT 1
    FROM [Notification].[SubscriptionTypes]
    WHERE SubscriptionTypeCode = 'GEX_SPXW_BULLISH'
)
BEGIN
    INSERT INTO [Notification].[SubscriptionTypes] (
        SubscriptionTypeCode,
        EventType,
        DisplayName,
        Description,
        RequiresTriggerValue,
        TriggerValueType,
        TriggerValueMin,
        TriggerValueMax,
        TriggerValueUnit,
        RequiresTriggerValue2,
        TriggerValue2Type,
        SupportsTextFilter,
        SupportsPriorityLevels,
        IsActive,
        SortOrder
    )
    VALUES (
        'GEX_SPXW_BULLISH',
        'gex_insights_spxw',
        'Bullish',
        'Notify when GEX insights indicate a bullish condition for SPXW. Use EntityCode ''*''',
        0,
        NULL,
        NULL,
        NULL,
        NULL,
        0,
        NULL,
        0,
        1,
        1,
        1
    );
END

IF NOT EXISTS (
    SELECT 1
    FROM [Notification].[SubscriptionTypes]
    WHERE SubscriptionTypeCode = 'GEX_SPXW_BEARISH'
)
BEGIN
    INSERT INTO [Notification].[SubscriptionTypes] (
        SubscriptionTypeCode,
        EventType,
        DisplayName,
        Description,
        RequiresTriggerValue,
        TriggerValueType,
        TriggerValueMin,
        TriggerValueMax,
        TriggerValueUnit,
        RequiresTriggerValue2,
        TriggerValue2Type,
        SupportsTextFilter,
        SupportsPriorityLevels,
        IsActive,
        SortOrder
    )
    VALUES (
        'GEX_SPXW_BEARISH',
        'gex_insights_spxw',
        'Bearish',
        'Notify when GEX insights indicate a bearish condition for SPXW. Use EntityCode ''*''',
        0,
        NULL,
        NULL,
        NULL,
        NULL,
        0,
        NULL,
        0,
        1,
        1,
        2
    );
END


