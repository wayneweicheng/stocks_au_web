-- Stored procedure: [Report].[usp_Get_StrategySuggestion]



--exec [Report].[usp_Get_StrategySuggestion]
--@pintNumPrevDay = 0,
--@pvchSelectItem = 'Top 20 Holder Stocks'

CREATE PROCEDURE [Report].[usp_Get_StrategySuggestion]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSelectItem as varchar(500),
@pintNumPrevDay AS INT = 0
AS
/******************************************************************************
File: usp_Get_StrategySuggestion.sql
Stored Procedure Name: usp_Get_StrategySuggestion
Overview
-----------------
usp_Get_StrategySuggestion

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
Date:		2018-08-20
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_StrategySuggestion'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--begin transaction
		if @pvchSelectItem = 'Norm MF Rank Long'
		begin
			exec [Report].[usp_Get_Strategy_NormMFRankLong]
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Norm MF Rank Short'
		begin
			exec [Report].[usp_Get_Strategy_NormMFRankShort]
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Weekly Top 1to50'
		begin
			exec [Report].[usp_Get_Strategy_WeeklyTop1To50]
			@pintNumPrevDay = @pintNumPrevDay
		end
		
		if @pvchSelectItem = 'Weekly Top 51to100'
		begin
			exec [Report].[usp_Get_Strategy_Stage2Stocks]
			@pintNumPrevDay = @pintNumPrevDay
		end		

		if @pvchSelectItem = 'New High Minor Retrace'
		begin
			exec [Report].[usp_Get_Strategy_NewHighMinorRetrace]
			@pintNumPrevDay = @pintNumPrevDay
		end 

		
	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
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
