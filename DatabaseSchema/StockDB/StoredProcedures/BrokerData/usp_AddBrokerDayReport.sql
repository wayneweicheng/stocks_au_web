-- Stored procedure: [BrokerData].[usp_AddBrokerDayReport]


CREATE PROCEDURE [BrokerData].[usp_AddBrokerDayReport]
    @pbitDebug BIT = 0,
    @pintErrorNumber INT = 0 OUTPUT,
    @pvchBrokerName VARCHAR(200),
    @pvchASXCode VARCHAR(10),
    @pvchObservationDate VARCHAR(50),
    @pvchMarketCap VARCHAR(20) = NULL,
    @pdecNetValue DECIMAL(20,4) = NULL,
    @pdecBuyValue DECIMAL(20,4),
    @pdecSellValue DECIMAL(20,4),
    @pdecTotalValue DECIMAL(20,4) = NULL,
    @pintBuyRatio INT = NULL,
    @pintSellRatio INT = NULL,
    @pdecNetVolumeShares DECIMAL(20,4) = NULL
AS
/******************************************************************************
Stored Procedure Name: usp_AddBrokerDayReport
Overview: Inserts or updates broker day report data from MarketLens Screener

Input Parameters:
    @pbitDebug           - Set to 1 for debugging output
    @pvchBrokerName      - Broker name (e.g., "Commonwealth Securities")
    @pvchASXCode         - ASX ticker code (e.g., "ZIP", "BHP")
    @pvchObservationDate - Date string in various formats (YYYYMMDD, DD/MM/YYYY, etc.)
    @pvchMarketCap       - Market cap string (e.g., "3.8B", "401M")
    @pdecNetValue        - Net value (Buy - Sell)
    @pdecBuyValue        - Total buy value
    @pdecSellValue       - Total sell value
    @pdecTotalValue      - Total value (Buy + Sell)
    @pintBuyRatio        - Buy ratio percentage
    @pintSellRatio       - Sell ratio percentage
    @pdecNetVolumeShares - Net volume/shares

Output Parameters:
    @pintErrorNumber     - Contains 0 if no error, or ERROR_NUMBER() on error

Example:
    EXEC [BrokerData].[usp_AddBrokerDayReport]
        @pvchBrokerName = 'Commonwealth Securities',
        @pvchASXCode = 'ZIP',
        @pvchObservationDate = '20260120',
        @pdecBuyValue = 18543749,
        @pdecSellValue = 7524992,
        @pdecNetValue = 11018757,
        @pdecTotalValue = 26068741,
        @pintBuyRatio = 71,
        @pintSellRatio = 29

Change History:
    2026-01-20 - Wayne Cheng - Initial Version
*******************************************************************************/

SET NOCOUNT ON

BEGIN
    IF @pintErrorNumber <> 0
    BEGIN
        RETURN @pintErrorNumber
    END

    BEGIN TRY
        -- Error variable declarations
        DECLARE @vchProcedureName VARCHAR(100) = OBJECT_NAME(@@PROCID)
        DECLARE @vchSchema NVARCHAR(50) = SCHEMA_NAME()
        DECLARE @intErrorNumber INT = 0
        DECLARE @intErrorSeverity INT = 0
        DECLARE @intErrorState INT = 0
        DECLARE @vchErrorProcedure NVARCHAR(126) = ''
        DECLARE @intErrorLine INT = 0
        DECLARE @vchErrorMessage NVARCHAR(4000) = ''

        -- Parse observation date
        DECLARE @dtObservationDate DATE
        SELECT @dtObservationDate = CAST(@pvchObservationDate AS DATE)

        IF @pbitDebug = 1
        BEGIN
            PRINT 'Processing: Broker=' + @pvchBrokerName + ', ASX=' + @pvchASXCode + ', Date=' + CAST(@dtObservationDate AS VARCHAR(20))
        END

        -- Check if record already exists
        IF EXISTS (
            SELECT 1
            FROM [BrokerData].[BrokerDayReport]
            WHERE BrokerName = @pvchBrokerName
              AND ASXCode = @pvchASXCode
              AND ObservationDate = @dtObservationDate
        )
        BEGIN
            -- Update existing record
            UPDATE [BrokerData].[BrokerDayReport]
            SET MarketCap = @pvchMarketCap,
                NetValue = @pdecNetValue,
                BuyValue = @pdecBuyValue,
                SellValue = @pdecSellValue,
                TotalValue = @pdecTotalValue,
                BuyRatio = @pintBuyRatio,
                SellRatio = @pintSellRatio,
                NetVolumeShares = @pdecNetVolumeShares,
                CreateDate = GETDATE()
            WHERE BrokerName = @pvchBrokerName
              AND ASXCode = @pvchASXCode
              AND ObservationDate = @dtObservationDate

            IF @pbitDebug = 1
            BEGIN
                PRINT 'Updated existing record for ' + @pvchBrokerName + ' - ' + @pvchASXCode
            END
        END
        ELSE
        BEGIN
            -- Insert new record
            INSERT INTO [BrokerData].[BrokerDayReport]
            (
                [BrokerName],
                [ASXCode],
                [ObservationDate],
                [MarketCap],
                [NetValue],
                [BuyValue],
                [SellValue],
                [TotalValue],
                [BuyRatio],
                [SellRatio],
                [NetVolumeShares],
                [CreateDate]
            )
            VALUES
            (
                @pvchBrokerName,
                @pvchASXCode,
                @dtObservationDate,
                @pvchMarketCap,
                @pdecNetValue,
                @pdecBuyValue,
                @pdecSellValue,
                @pdecTotalValue,
                @pintBuyRatio,
                @pintSellRatio,
                @pdecNetVolumeShares,
                GETDATE()
            )

            IF @pbitDebug = 1
            BEGIN
                PRINT 'Inserted new record for ' + @pvchBrokerName + ' - ' + @pvchASXCode
            END
        END

    END TRY

    BEGIN CATCH
        SELECT @intErrorNumber = ERROR_NUMBER(),
               @intErrorSeverity = ERROR_SEVERITY(),
               @intErrorState = ERROR_STATE(),
               @vchErrorProcedure = ERROR_PROCEDURE(),
               @intErrorLine = ERROR_LINE(),
               @vchErrorMessage = ERROR_MESSAGE()
    END CATCH

    IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
    BEGIN
        IF @pbitDebug = 1
        BEGIN
            PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished successfully'
        END
    END
    ELSE
    BEGIN
        RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
    END

    SET @pintErrorNumber = @intErrorNumber
END
