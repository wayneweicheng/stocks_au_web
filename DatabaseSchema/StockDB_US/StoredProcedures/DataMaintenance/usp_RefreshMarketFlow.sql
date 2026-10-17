-- Stored procedure: [DataMaintenance].[usp_RefreshMarketFlow]

ALTER PROCEDURE [DataMaintenance].[usp_RefreshMarketFlow]
    @pbitDebug AS BIT = 0,
    @pNumberOfBackDays AS INT = 1,
    @pintErrorNumber AS INT = 0 OUTPUT
AS
/****************************************************************************
File: usp_RefreshMarketFlow.sql
Stored Procedure Name: usp_RefreshMarketFlow
Overview
-----------------
Refreshes GEX features for every stock configured in LookupRef.v_StockToCheck.
A failure for one stock is recorded and does not prevent later stocks from being
processed. Cursor/setup-level failures are raised to the caller.

Input Parameters
-----------------
@pbitDebug             -- Set to 1 to display processing information
@pNumberOfBackDays     -- Number of business days back to refresh

Output Parameters
-----------------
@pintErrorNumber       -- 0 if all stocks succeeded; otherwise the first
                           per-stock error number, or the procedure-level error
****************************************************************************/
SET NOCOUNT ON;

BEGIN
    IF @pintErrorNumber <> 0
    BEGIN
        -- Preserve the existing chained-error behavior.
        RETURN @pintErrorNumber;
    END;

    DECLARE @StockErrors TABLE
    (
        ErrorId         INT IDENTITY(1,1) NOT NULL,
        ASXCode         VARCHAR(50) NOT NULL,
        ErrorNumber     INT NOT NULL,
        ErrorSeverity   INT NOT NULL,
        ErrorState      INT NOT NULL,
        ErrorProcedure  NVARCHAR(128) NULL,
        ErrorLine       INT NOT NULL,
        ErrorMessage    NVARCHAR(4000) NOT NULL
    );

    DECLARE @vchProcedureName VARCHAR(100) = 'usp_RefreshMarketFlow';
    DECLARE @vchSchema NVARCHAR(50) = 'DataMaintenance';
    DECLARE @intErrorNumber INT = 0;
    DECLARE @intErrorSeverity INT = 0;
    DECLARE @intErrorState INT = 0;
    DECLARE @vchErrorProcedure NVARCHAR(126) = N'';
    DECLARE @intErrorLine INT = 0;
    DECLARE @vchErrorMessage NVARCHAR(4000) = N'';
    DECLARE @CurrentCode VARCHAR(50);

    BEGIN TRY
        DECLARE stock_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ASXCode
            FROM
            (
                SELECT DISTINCT
                    CASE
                        WHEN ASXCode = '_SPX.US' THEN 'SPXW.US'
                        ELSE ASXCode
                    END AS ASXCode
                FROM LookupRef.v_StockToCheck
            ) AS Stocks
            ORDER BY ASXCode;

        OPEN stock_cursor;
        FETCH NEXT FROM stock_cursor INTO @CurrentCode;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @pbitDebug = 1
                PRINT 'Processing: ' + @CurrentCode;

            -- Isolate each stock's failure so the cursor continues.
            BEGIN TRY
                EXEC Analysis.usp_RefreshGEXFeaturesForTraining
                    @ASXCode = @CurrentCode,
                    @NumberOfBackDays = @pNumberOfBackDays;
            END TRY
            BEGIN CATCH
                INSERT INTO @StockErrors
                (
                    ASXCode,
                    ErrorNumber,
                    ErrorSeverity,
                    ErrorState,
                    ErrorProcedure,
                    ErrorLine,
                    ErrorMessage
                )
                VALUES
                (
                    @CurrentCode,
                    ERROR_NUMBER(),
                    ERROR_SEVERITY(),
                    ERROR_STATE(),
                    ERROR_PROCEDURE(),
                    ERROR_LINE(),
                    ERROR_MESSAGE()
                );

                IF @pbitDebug = 1
                    PRINT 'Failed: ' + @CurrentCode + ' - ' + ERROR_MESSAGE();
            END CATCH;

            -- Always advance, including after a per-stock failure.
            FETCH NEXT FROM stock_cursor INTO @CurrentCode;
        END;

        CLOSE stock_cursor;
        DEALLOCATE stock_cursor;
    END TRY
    BEGIN CATCH
        -- Capture cursor/setup-level errors. Per-stock errors are handled above.
        IF CURSOR_STATUS('local', 'stock_cursor') >= 0
            CLOSE stock_cursor;

        IF CURSOR_STATUS('local', 'stock_cursor') > -3
            DEALLOCATE stock_cursor;

        SELECT
            @intErrorNumber = ERROR_NUMBER(),
            @intErrorSeverity = ERROR_SEVERITY(),
            @intErrorState = ERROR_STATE(),
            @vchErrorProcedure = ERROR_PROCEDURE(),
            @intErrorLine = ERROR_LINE(),
            @vchErrorMessage = ERROR_MESSAGE();

        -- Do not let a stopped Database Mail service mask the original error.
        BEGIN TRY
            DECLARE @vchEmailRecipient VARCHAR(100) = 'wayneweicheng@gmail.com';
            DECLARE @vchEmailSubject VARCHAR(200) =
                'DataMaintenance.usp_RefreshMarketFlow failed';
            DECLARE @vchEmailBody VARCHAR(2000) =
                @vchEmailSubject + ':' + CHAR(13) + CHAR(10) + @vchErrorMessage;

            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'Wayne StockTrading',
                @recipients = @vchEmailRecipient,
                @subject = @vchEmailSubject,
                @body = @vchEmailBody;
        END TRY
        BEGIN CATCH
            PRINT 'Could not send Database Mail notification: ' + ERROR_MESSAGE();
        END CATCH;
    END CATCH;

    -- Return per-stock failures to the caller without stopping the refresh run.
    IF EXISTS (SELECT 1 FROM @StockErrors)
    BEGIN
        SELECT TOP (1) @pintErrorNumber = ErrorNumber
        FROM @StockErrors
        ORDER BY ErrorId;

        SELECT
            ASXCode,
            ErrorNumber,
            ErrorSeverity,
            ErrorState,
            ErrorProcedure,
            ErrorLine,
            ErrorMessage
        FROM @StockErrors
        ORDER BY ErrorId;

        IF @pbitDebug = 1
        BEGIN
            DECLARE @StockErrorCount INT;
            SELECT @StockErrorCount = COUNT(*) FROM @StockErrors;
            PRINT 'Refresh finished with ' + CONVERT(VARCHAR(12), @StockErrorCount) +
                  ' stock-level failure(s).';
        END;
    END
    ELSE IF @intErrorNumber = 0
    BEGIN
        SET @pintErrorNumber = 0;

        IF @pbitDebug = 1
            PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName +
                  ' finished executing successfully at ' +
                  CONVERT(VARCHAR(20), GETDATE(), 120);
    END;

    IF @intErrorNumber <> 0
    BEGIN
        SET @pintErrorNumber = @intErrorNumber;

        -- Preserve the existing behavior for procedure-level errors.
        RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState);
    END;
END;
GO
