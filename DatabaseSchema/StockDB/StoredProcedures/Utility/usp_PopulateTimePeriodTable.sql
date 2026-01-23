-- Stored procedure: [Utility].[usp_PopulateTimePeriodTable]





create PROCEDURE [Utility].[usp_PopulateTimePeriodTable]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_PopulateTimePeriodTable.sql
Stored Procedure Name: usp_PopulateTimePeriodTable
Overview
-----------------
usp_PopulateTimePeriodTable

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
Date:		2017-04-26
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_PopulateTimePeriodTable'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Utility'
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
		declare @intNumMin as int = 30;

		WITH Numbers AS
		(
			SELECT TOP (10000) n = CONVERT(INT, ROW_NUMBER() OVER (ORDER BY s1.[object_id]))
			FROM sys.all_objects AS s1 CROSS JOIN sys.all_objects AS s2
		)

		insert into [LookupRef].[TimePeriod30Min]
		SELECT 
			'2000-01-01' + DATEADD(MINUTE, n, '00:00:00') as TimeStart,
			'2000-01-01' + DATEADD(MINUTE, n + @intNumMin, '00:00:00') as TimeEnd,
			left(cast(cast('2000-01-01' + DATEADD(MINUTE, n, '00:00:00') as time) as varchar(50)), 8) as TimeLabel,
			getdate() as CreateDate
		FROM Numbers
		WHERE n % @intNumMin = 0
		and '2000-01-01' + DATEADD(MINUTE, n, '00:00:00') >= '2000-01-01 09:59:30'
		and '2000-01-01' + DATEADD(MINUTE, n, '00:00:00') <= '2000-01-01 16:10:30'



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
