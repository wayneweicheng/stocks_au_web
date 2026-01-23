-- Stored procedure: [DataMaintenance].[usp_RefreshMarketFlow_dev]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshMarketFlow_dev]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshMarketFlow.sql
Stored Procedure Name: usp_RefreshMarketFlow
Overview
-----------------
usp_RefreshMarketFlow

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2017-02-07
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshMarketFlow'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here
		DECLARE @CurrentCode varchar(10);

		-- 1. Declare the cursor to select all stocks from your table
		DECLARE stock_cursor CURSOR FOR 
		SELECT ASXCode 
		FROM Analysis.MostTradedStock
		ORDER BY 
		case when ASXCode in ('SPXW.US', '_VIX.US', 'NVDA.US') then 1 else 0 end desc,
		ASXCode; -- Optional: orders them alphabetically

		-- 2. Open the cursor
		OPEN stock_cursor;

		-- 3. Fetch the first record
		FETCH NEXT FROM stock_cursor INTO @CurrentCode;

		-- 4. Loop through the list
		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				-- Print progress to the message window
				PRINT 'Processing: ' + @CurrentCode;

				-- Execute your stored procedure for the current stock
				EXEC Analysis.usp_RefreshGEXFeaturesForTraining
					@ASXCode = @CurrentCode;
            
			END TRY
			BEGIN CATCH
				-- Optional error handling so the loop continues even if one stock fails
				PRINT 'Error processing ' + @CurrentCode + ': ' + ERROR_MESSAGE();
			END CATCH

			-- Fetch the next record
			FETCH NEXT FROM stock_cursor INTO @CurrentCode;
		END

		-- 5. Cleanup
		CLOSE stock_cursor;
		DEALLOCATE stock_cursor;

		PRINT 'Batch processing complete.';


		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'SPXW.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'AVGO.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'QQQ.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'GDX.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'SLV.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'NVDA.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'TSLA.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = '_VIX.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'AMZN.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'IWM.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'XBI.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'META.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'XBI.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'ITB.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'BAC.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'C.US'

		--exec Analysis.usp_RefreshGEXFeaturesForTraining
		--@ASXCode = 'CAT.US'

		----exec Analysis.usp_RefreshGEXFeaturesForTraining
		----@ASXCode = 'AMD.US'

		----exec Analysis.usp_RefreshGEXFeaturesForTraining
		----@ASXCode = 'BA.US'

		----exec Analysis.usp_RefreshGEXFeaturesForTraining
		----@ASXCode = 'CCL.US'

		----exec Analysis.usp_RefreshGEXFeaturesForTraining
		----@ASXCode = 'COIN.US'

		----exec Analysis.usp_RefreshGEXFeaturesForTraining
		----@ASXCode = 'COST.US'

		----exec Analysis.usp_RefreshGEXFeaturesForTraining
		----@ASXCode = 'COST.US'


	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occured in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN

		--IF @@TRANCOUNT > 0
		--BEGIN
		--	ROLLBACK TRANSACTION
		--END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
