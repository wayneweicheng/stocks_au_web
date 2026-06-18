-- Stored procedure: [Transform].[usp_RefreshBrokerEnhanceDaily]

/*
==============================================================================
Procedure:   Transform.usp_RefreshBrokerEnhanceDaily
Description: Runs Phase1 + Phase23 broker enhance refresh over a date range.
             Defaults to today's date if no parameters provided.

Usage:
    -- Run for today only (default)
    EXEC Transform.usp_RefreshBrokerEnhanceDaily;

    -- Run for a specific date
    EXEC Transform.usp_RefreshBrokerEnhanceDaily
        @pStartDate = '2026-04-10',
        @pEndDate = '2026-04-10';

    -- Run for a date range
    EXEC Transform.usp_RefreshBrokerEnhanceDaily
        @pStartDate = '2026-03-11',
        @pEndDate = '2026-04-09';

History:
    2026-04-28  Created initial version
==============================================================================
*/
CREATE   PROCEDURE Transform.usp_RefreshBrokerEnhanceDaily
    @pStartDate date = NULL,
    @pEndDate date = NULL,
    @pPhase1LookbackTradingDays int = 504,
    @pPhase23TriggerMode varchar(20) = 'HYBRID',
    @pPhase23LookbackCalendarDays int = 30,
    @pPhase23PersistArchive bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* =========================
       DEFAULT TO TODAY
       ========================= */
    IF @pStartDate IS NULL
        SET @pStartDate = CAST(GETDATE() AS date);

    IF @pEndDate IS NULL
        SET @pEndDate = CAST(GETDATE() AS date);

    /* =========================
       VALIDATION
       ========================= */
    IF @pStartDate > @pEndDate
    BEGIN
        THROW 50001, '@pStartDate must be <= @pEndDate', 1;
    END;

    /* =========================
       EXECUTION
       ========================= */
    DECLARE @d date = @pStartDate;

    DECLARE @runlog TABLE
    (
        AsOfDate date NOT NULL,
        Status varchar(20) NOT NULL,
        ErrorMessage nvarchar(4000) NULL,
        CompletedAt datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    WHILE @d <= @pEndDate
    BEGIN
        BEGIN TRY
            EXEC Transform.usp_RefreshBrokerEnhancePhase1
                @pAsOfDate = @d,
                @pLookbackTradingDays = @pPhase1LookbackTradingDays;

            EXEC Transform.usp_RefreshBrokerEnhancePhase23
                @pAsOfDate = @d,
                @pTriggerMode = @pPhase23TriggerMode,
                @pLookbackCalendarDays = @pPhase23LookbackCalendarDays,
                @pPersistArchive = @pPhase23PersistArchive;

            INSERT INTO @runlog (AsOfDate, Status)
            VALUES (@d, 'OK');

            PRINT 'Completed: ' + CONVERT(varchar(10), @d, 120);
        END TRY
        BEGIN CATCH
            DECLARE @errMsg nvarchar(4000) = ERROR_MESSAGE();

            INSERT INTO @runlog (AsOfDate, Status, ErrorMessage)
            VALUES (@d, 'FAILED', @errMsg);

            PRINT 'FAILED: ' + CONVERT(varchar(10), @d, 120) + ' - ' + @errMsg;
        END CATCH;

        SET @d = DATEADD(DAY, 1, @d);
    END;

    /* =========================
       SUMMARY REPORT
       ========================= */
    SELECT
        AsOfDate,
        Status,
        ErrorMessage,
        CompletedAt
    FROM @runlog
    ORDER BY AsOfDate;

    SELECT
        COUNT(*) AS TotalDays,
        SUM(CASE WHEN Status = 'OK' THEN 1 ELSE 0 END) AS DaysOK,
        SUM(CASE WHEN Status = 'FAILED' THEN 1 ELSE 0 END) AS DaysFailed,
        @pStartDate AS StartDate,
        @pEndDate AS EndDate
    FROM @runlog;
END;
