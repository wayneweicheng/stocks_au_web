-- View: [Discord].[v_DiscordMessages]


  CREATE VIEW [Discord].[v_DiscordMessages] AS
SELECT 
    *,
    -- Converts the datetimeoffset to US Eastern Standard Time
    [TimeStamp] AT TIME ZONE 'Eastern Standard Time' AS TimeStamp_USEst
FROM [StockDB_US].[Discord].[DiscordMessages];