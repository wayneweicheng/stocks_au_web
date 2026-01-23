-- Stored procedure: [BrokerData].[usp_AddBrokerDayReportBatch]


CREATE PROCEDURE [BrokerData].[usp_AddBrokerDayReportBatch]
    @pbitDebug BIT = 0,
    @pintErrorNumber INT = 0 OUTPUT,
    @pvchBrokerName VARCHAR(200),
    @pvchObservationDate VARCHAR(50),
    @pxmlBrokerData XML
AS
/******************************************************************************
Stored Procedure Name: usp_AddBrokerDayReportBatch
Overview: Batch inserts broker day report data from XML

Input Parameters:
    @pbitDebug           - Set to 1 for debugging output
    @pvchBrokerName      - Broker name
    @pvchObservationDate - Observation date
    @pxmlBrokerData      - XML containing ticker data

XML Format:
    <BrokerDayReport>
        <ticker>
            <asxCode>ZIP</asxCode>
            <marketCap>3.8B</marketCap>
            <netValue>11018757</netValue>
            <buyValue>18543749</buyValue>
            <sellValue>7524992</sellValue>
            <totalValue>26068741</totalValue>
            <buyRatio>71</buyRatio>
            <sellRatio>29</sellRatio>
            <netVolumeShares>0.2740</netVolumeShares>
        </ticker>
    </BrokerDayReport>

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
        DECLARE @vchProcedureName VARCHAR(100) = OBJECT_NAME(@@PROCID)
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
            PRINT 'Processing batch for Broker=' + @pvchBrokerName + ', Date=' + CAST(@dtObservationDate AS VARCHAR(20))
        END

        -- Parse XML into temp table
        DECLARE @TempData TABLE
        (
            ASXCode VARCHAR(10),
            MarketCap VARCHAR(20),
            NetValue DECIMAL(20,4),
            BuyValue DECIMAL(20,4),
            SellValue DECIMAL(20,4),
            TotalValue DECIMAL(20,4),
            BuyRatio INT,
            SellRatio INT,
            NetVolumeShares DECIMAL(20,4)
        )

        INSERT INTO @TempData
        SELECT
            T.c.value('(asxCode)[1]', 'VARCHAR(10)') AS ASXCode,
            T.c.value('(marketCap)[1]', 'VARCHAR(20)') AS MarketCap,
            T.c.value('(netValue)[1]', 'DECIMAL(20,4)') AS NetValue,
            T.c.value('(buyValue)[1]', 'DECIMAL(20,4)') AS BuyValue,
            T.c.value('(sellValue)[1]', 'DECIMAL(20,4)') AS SellValue,
            T.c.value('(totalValue)[1]', 'DECIMAL(20,4)') AS TotalValue,
            T.c.value('(buyRatio)[1]', 'INT') AS BuyRatio,
            T.c.value('(sellRatio)[1]', 'INT') AS SellRatio,
            T.c.value('(netVolumeShares)[1]', 'DECIMAL(20,4)') AS NetVolumeShares
        FROM @pxmlBrokerData.nodes('/BrokerDayReport/ticker') AS T(c)

        DECLARE @RowCount INT = (SELECT COUNT(*) FROM @TempData)

        IF @pbitDebug = 1
        BEGIN
            PRINT 'Parsed ' + CAST(@RowCount AS VARCHAR(10)) + ' records from XML'
        END

        -- Delete existing records for this broker/date combination
        DELETE FROM [BrokerData].[BrokerDayReport]
        WHERE BrokerName = @pvchBrokerName
          AND ObservationDate = @dtObservationDate
          AND ASXCode IN (SELECT ASXCode FROM @TempData)

        -- Insert new records
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
        SELECT
            @pvchBrokerName,
            ASXCode,
            @dtObservationDate,
            MarketCap,
            NetValue,
            BuyValue,
            SellValue,
            TotalValue,
            BuyRatio,
            SellRatio,
            NetVolumeShares,
            GETDATE()
        FROM @TempData

        IF @pbitDebug = 1
        BEGIN
            PRINT 'Inserted ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' records'
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
            PRINT 'Batch procedure completed successfully'
        END
    END
    ELSE
    BEGIN
        RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
    END

    SET @pintErrorNumber = @intErrorNumber
END
