-- Stored procedure: [StockData].[usp_AddETFComFundFlow]


CREATE PROCEDURE [StockData].[usp_AddETFComFundFlow]
    @pbitDebug AS BIT = 0,
    @pvchASXCode AS VARCHAR(10),
    @pvchTicker AS VARCHAR(10),
    @pdtObservationDate AS DATE,
    @pdecFundFlow AS DECIMAL(18, 2) = NULL,
    @pdecAUM AS DECIMAL(18, 2) = NULL,
    @pbigSharesOutstanding AS BIGINT = NULL,
    @pdecNavPrice AS DECIMAL(18, 4) = NULL,
    @pdecClosePrice AS DECIMAL(18, 4) = NULL,
    @pbigVolume AS BIGINT = NULL,
    @pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddETFComFundFlow.sql
Stored Procedure Name: usp_AddETFComFundFlow
Overview: Inserts or updates ETF fund flow data from ETF.com API
          - Inserts into ETFComFundFlowHistory (always, no deduplication)
          - Upserts into ETFComFundFlow (current snapshot)
Input Parameters:
    @pbitDebug - Set to 1 to force the display of debugging information
    @pvchASXCode - Stock code with market suffix (e.g., 'SPY.US')
    @pvchTicker - Stock ticker symbol (e.g., 'SPY')
    @pdtObservationDate - Date of the fund flow observation
    @pdecFundFlow - Daily fund flow in USD
    @pdecAUM - Assets Under Management
    @pbigSharesOutstanding - Number of shares outstanding
    @pdecNavPrice - Net Asset Value price
    @pdecClosePrice - Closing price
    @pbigVolume - Trading volume
Output Parameters:
    @pintErrorNumber - Contains 0 if no error, or ERROR_NUMBER() on error
Example of use:
    EXEC [StockData].[usp_AddETFComFundFlow]
        @pvchASXCode = 'SPY.US',
        @pvchTicker = 'SPY',
        @pdtObservationDate = '2025-01-31',
        @pdecFundFlow = 1250000000.00,
        @pdecAUM = 550000000000.00,
        @pbigSharesOutstanding = 868000000,
        @pdecNavPrice = 634.25,
        @pdecClosePrice = 634.30,
        @pbigVolume = 45000000
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

    IF @pintErrorNumber <> 0
    BEGIN
        RETURN @pintErrorNumber
    END

    BEGIN TRY

        -- Error variable declarations
        DECLARE @vchProcedureName AS VARCHAR(100); SET @vchProcedureName = 'usp_AddETFComFundFlow'
        DECLARE @vchSchema AS NVARCHAR(50); SET @vchSchema = 'StockData'
        DECLARE @intErrorNumber AS INT; SET @intErrorNumber = 0
        DECLARE @intErrorSeverity AS INT; SET @intErrorSeverity = 0
        DECLARE @intErrorState AS INT; SET @intErrorState = 0
        DECLARE @vchErrorProcedure AS NVARCHAR(126); SET @vchErrorProcedure = ''
        DECLARE @intErrorLine AS INT; SET @intErrorLine  = 0
        DECLARE @vchErrorMessage AS NVARCHAR(4000); SET @vchErrorMessage = ''
        DECLARE @dtInsertDateTime DATETIME; SET @dtInsertDateTime = GETDATE()

        -- 1. ALWAYS insert into history table (never update, full audit trail)
        INSERT INTO [StockData].[ETFComFundFlowHistory] (
            [ASXCode],
            [Ticker],
            [ObservationDate],
            [FundFlow],
            [AUM],
            [SharesOutstanding],
            [NavPrice],
            [ClosePrice],
            [Volume],
            [InsertDateTime],
            [CreateDate]
        )
        VALUES (
            @pvchASXCode,
            @pvchTicker,
            @pdtObservationDate,
            @pdecFundFlow,
            @pdecAUM,
            @pbigSharesOutstanding,
            @pdecNavPrice,
            @pdecClosePrice,
            @pbigVolume,
            @dtInsertDateTime,
            @dtInsertDateTime
        )

        IF @pbitDebug = 1
        BEGIN
            PRINT 'Inserted into history table for ' + @pvchASXCode + ' on ' + CAST(@pdtObservationDate AS VARCHAR(10))
        END

        -- 2. Merge operation to insert or update current table
        MERGE INTO [StockData].[ETFComFundFlow] AS target
        USING (
            SELECT
                @pvchASXCode AS ASXCode,
                @pvchTicker AS Ticker,
                @pdtObservationDate AS ObservationDate,
                @pdecFundFlow AS FundFlow,
                @pdecAUM AS AUM,
                @pbigSharesOutstanding AS SharesOutstanding,
                @pdecNavPrice AS NavPrice,
                @pdecClosePrice AS ClosePrice,
                @pbigVolume AS Volume
        ) AS source
        ON (target.ASXCode = source.ASXCode AND target.ObservationDate = source.ObservationDate)
        WHEN MATCHED THEN
            UPDATE SET
                target.Ticker = source.Ticker,
                target.FundFlow = COALESCE(source.FundFlow, target.FundFlow),
                target.AUM = COALESCE(source.AUM, target.AUM),
                target.SharesOutstanding = COALESCE(source.SharesOutstanding, target.SharesOutstanding),
                target.NavPrice = COALESCE(source.NavPrice, target.NavPrice),
                target.ClosePrice = COALESCE(source.ClosePrice, target.ClosePrice),
                target.Volume = COALESCE(source.Volume, target.Volume),
                target.LastUpdateDate = @dtInsertDateTime
        WHEN NOT MATCHED THEN
            INSERT (ASXCode, Ticker, ObservationDate, FundFlow, AUM, SharesOutstanding, NavPrice, ClosePrice, Volume)
            VALUES (source.ASXCode, source.Ticker, source.ObservationDate, source.FundFlow, source.AUM,
                    source.SharesOutstanding, source.NavPrice, source.ClosePrice, source.Volume);

        IF @pbitDebug = 1
        BEGIN
            PRINT 'Successfully processed fund flow data for ' + @pvchASXCode + ' on ' + CAST(@pdtObservationDate AS VARCHAR(10))
        END

    END TRY

    BEGIN CATCH
        -- Store the details of the error
        SELECT    @intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
                @intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
                @intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
    END CATCH

    IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
    BEGIN
        IF @pbitDebug = 1
        BEGIN
            PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(GETDATE() AS VARCHAR(20))
        END
    END
    ELSE
    BEGIN
        RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
    END

    SET @pintErrorNumber = @intErrorNumber

END
