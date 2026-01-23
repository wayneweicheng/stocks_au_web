-- Stored procedure: [Notification].[usp_UpdateMessageStatus]


CREATE PROCEDURE [Notification].[usp_UpdateMessageStatus]
    @pbigMessageID BIGINT,
    @pvchStatus VARCHAR(20),              -- 'sent', 'failed', 'skipped', etc.
    @pvchExternalMessageID NVARCHAR(100) = NULL,
    @pvchErrorMessage NVARCHAR(MAX) = NULL,
    @pvchErrorStackTrace NVARCHAR(MAX) = NULL,
    @pbitDebug BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Notification].[MessageQueue]
    SET
        Status = @pvchStatus,
        ProcessedDate = CASE WHEN @pvchStatus IN ('sent','failed','skipped') THEN GETDATE() ELSE ProcessedDate END,
        SentDate = CASE WHEN @pvchStatus = 'sent' THEN GETDATE() ELSE SentDate END,
        ExternalMessageID = @pvchExternalMessageID,
        ErrorMessage = @pvchErrorMessage,
        ErrorStackTrace = @pvchErrorStackTrace
    WHERE MessageID = @pbigMessageID;

    IF @pbitDebug = 1
        PRINT 'Debug: Updated MessageID=' + CAST(@pbigMessageID AS VARCHAR) + ' to status=' + @pvchStatus;
END;
