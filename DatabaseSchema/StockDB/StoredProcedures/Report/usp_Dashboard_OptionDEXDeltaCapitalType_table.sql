-- Stored procedure: [Report].[usp_Dashboard_OptionDEXDeltaCapitalType_table]



CREATE PROCEDURE [Report].[usp_Dashboard_OptionDEXDeltaCapitalType_table]
@pbitDebug AS BIT = 0,
@pvchASXCode as varchar(20)
AS
/******************************************************************************
File: usp_Dashboard_OptionDEXDeltaCapitalType_table.sql
Stored Procedure Name: usp_Dashboard_OptionDEXDeltaCapitalType_table
Overview
-----------------
exec [Report].[usp_Dashboard_OptionDEXDeltaCapitalType_table]
@pvchASXCode = 'QQQ.US'

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
Date:		2023-09-05
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	declare @pintErrorNumber as int = 0

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Dashboard_OptionDEXDeltaCapitalType_table'
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
		--declare @pvchASXCode as varchar(20) = 'QQQ.US'
		declare @nvchGenericQuery as nvarchar(max)

		select @nvchGenericQuery =
'
		select 
			a.ObservationDate,
			a.DEXDeltaPerc as BC_DEXDeltaPerc,
			b.DEXDeltaPerc as BP_DEXDeltaPerc,
			a.[Close],
			a.VWAP,
			a.AvgDEXDelta,
			a.NumObs,
			a.ASXCode
		from StockDB_US.Transform.v_OptionDEXChangeCapitalType as a
		left join StockDB_US.Transform.v_OptionDEXChangeCapitalType as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		where a.CapitalType = ''BC''
		and b.CapitalType = ''BP''
		and a.ASXCode = ''' + @pvchASXCode + '''
		and a.ObservationDate > dateadd(day, -180, getdate())
		order by case when a.ASXCode = ''SPXW.US'' then 1 else 0 end desc, a.ASXCode, a.ObservationDate desc, a.CapitalType
'

		--print(@nvchGenericQuery)
		exec sp_executesql @nvchGenericQuery

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
