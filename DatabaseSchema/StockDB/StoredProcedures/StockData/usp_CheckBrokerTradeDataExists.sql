-- Stored procedure: [StockData].[usp_CheckBrokerTradeDataExists]


CREATE PROCEDURE [StockData].[usp_CheckBrokerTradeDataExists]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode AS VARCHAR(10),
@pdtObservationDate AS DATE,
@pbitDataExists AS BIT OUTPUT
AS
/******************************************************************************
File: usp_CheckBrokerTradeDataExists.sql
Stored Procedure Name: usp_CheckBrokerTradeDataExists
Overview
-----------------
usp_CheckBrokerTradeDataExists - Checks if broker trade transaction data already exists 
for a given ASX code and observation date

Input Parameters
-----------------
@pbitDebug                      -- Set to 1 to force the display of debugging information
@pvchASXCode                    -- ASX stock code (e.g., 'LDR.AX')
@pdtObservationDate             -- Date of the trading session

Output Parameters
-----------------
@pintErrorNumber                -- Contains 0 if no error, or ERROR_NUMBER() on error
@pbitDataExists                 -- Returns 1 if data exists, 0 if no data found

Example of use
-----------------
DECLARE @ErrorNum INT = 0
DECLARE @DataExists BIT = 0

EXEC [StockData].[usp_CheckBrokerTradeDataExists] 
    @pbitDebug = 1,
    @pintErrorNumber = @ErrorNum OUTPUT,
    @pvchASXCode = 'LDR.AX',
    @pdtObservationDate = '2025-07-26',
    @pbitDataExists = @DataExists OUTPUT

SELECT @DataExists as DataExists, @ErrorNum as ErrorNumber

*******************************************************************************
Change History
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2025-07-26
Author:		WAYNE CHENG
Description: Initial Version - Check for existing broker trade data
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CheckBrokerTradeDataExists'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		SET NOCOUNT ON;

		-- Normal variable declarations
		DECLARE @intRecordCount AS INT = 0

		-- Initialize output parameter
		SET @pbitDataExists = 0

		-- Check if any records exist for the given ASX code and observation date
		SELECT @intRecordCount = COUNT(*)
		FROM StockData.BrokerTradeTransaction
		WHERE ASXCode = @pvchASXCode
		AND ObservationDate = @pdtObservationDate

		-- Set output parameter based on record count
		IF @intRecordCount > 0
		BEGIN
			SET @pbitDataExists = 1
			
			IF @pbitDebug = 1
			BEGIN
				PRINT 'Data exists for ASX Code: ' + @pvchASXCode + ' on ' + CAST(@pdtObservationDate AS VARCHAR(20)) + ' (' + CAST(@intRecordCount AS VARCHAR(10)) + ' records found)'
			END
		END
		ELSE
		BEGIN
			SET @pbitDataExists = 0
			
			IF @pbitDebug = 1
			BEGIN
				PRINT 'No data found for ASX Code: ' + @pvchASXCode + ' on ' + CAST(@pdtObservationDate AS VARCHAR(20))
			END
		END
		
	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occurred in this procedure
		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(GETDATE() AS VARCHAR(20))
		END
	END
	ELSE
	BEGIN
		-- Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END

	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter

END --Proc
