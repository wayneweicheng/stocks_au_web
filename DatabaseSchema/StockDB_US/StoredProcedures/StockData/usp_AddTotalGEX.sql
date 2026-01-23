-- Stored procedure: [StockData].[usp_AddTotalGEX]


CREATE PROCEDURE [StockData].[usp_AddTotalGEX]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchResponse as varchar(max)
AS
/******************************************************************************
File: usp_AddBrokerData.sql
Stored Procedure Name: usp_AddBrokerData
Overview
-----------------
usp_AddOverview

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
Date:		2017-02-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = object_name(@@PROCID)
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = schema_name()
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempTotalGex') is not null
			drop table #TempTotalGex

		select
			@pvchASXCode as ASXCode,
			@pvchResponse as GEX
		into #TempTotalGex
		--into MAWork.dbo.TempTotalGex

		if object_id(N'Tempdb.dbo.#TempGEXHistory') is not null
			drop table #TempGEXHistory

		select 
			a.ASXCode,
			'daily' as TimeFrame,
			cast(json_value(c.value, '$.close') as decimal(20, 4)) as ClosePrice,
			cast(json_value(c.value, '$.date') as date) as ObservationDate,
			cast(json_value(c.value, '$.gex') as decimal(20, 4)) as GEX
		into #TempGEXHistory
		--into MAWork.dbo.TempGEXHistory
		from #TempTotalGex as a
		--from MAWork.dbo.TempTotalGex as a
		cross apply openjson(GEX) as b
		cross apply openjson(b.value) as c
		where 1 = 1
		and b.[key] = 'daily'

		insert into StockData.TotalGex
		(
			ASXCode,
			TimeFrame,
			ClosePrice,
			ObservationDate,
			GEX,
			CreateDate
		)
		select
			ASXCode,
			TimeFrame,
			ClosePrice,
			ObservationDate,
			GEX,
			getdate() as CreateDate
		from #TempGEXHistory as a
		--from MAWork.dbo.TempGEXHistory as a
		where not exists
		(
			select 1
			from StockData.TotalGex
			where ASXCode = a.ASXCode
			and TimeFrame = a.TimeFrame
			and ObservationDate = a.ObservationDate
		)

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
			
		EXECUTE DA_Utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
