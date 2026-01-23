-- Stored procedure: [StockData].[usp_RefreshMonitorStockListMarketDepth]






create PROCEDURE [StockData].[usp_RefreshMonitorStockListMarketDepth]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshMonitorStockListMarketDepth.sql
Stored Procedure Name: usp_RefreshMonitorStockListMarketDepth
Overview
-----------------
usp_RefreshMonitorStockListMarketDepth

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
Date:		2016-08-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshMonitorStockListMarketDepth'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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
		if object_id(N'Tempdb.dbo.#TempASXCode') is not null
			drop table #TempASXCode
		
		select 
		   StockCode + '.AX' as [ASXCode]
		into #TempASXCode
		from 
		(
			select 'KDR' as StockCode
			union
			select 'CRB'
			union
			select 'TV2'
			union
			select 'EDE'
			union
			select 'ALC'
			union
			select 'MOD'
			union
			select 'TYX'
			union
			select 'VML'
			union
			select 'GMD'
			union
			select 'IVR'
		) as x

		delete a
		from [StockData].[MonitorStock] as a
		where not exists
		(
			select 1
			from #TempASXCode
			where ASXCode = a.ASXCode
		)
		and MonitorTypeID = 'M'

		insert into [StockData].[MonitorStock]
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,MonitorTypeID
		)
		select
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,0 as [UpdateStatus]
		  ,'M' as MonitorTypeID
		from #TempASXCode as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where ASXCode = a.ASXCode
			and MonitorTypeID = 'M'
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
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
