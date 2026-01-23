-- Stored procedure: [StockData].[usp_AddMonitorStock]






CREATE PROCEDURE [StockData].[usp_AddMonitorStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10),
@pvchMessage as varchar(200) output
AS
/******************************************************************************
File: usp_AddMonitorStock.sql
Stored Procedure Name: usp_AddMonitorStock
Overview
-----------------
usp_AddMonitorStock

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
Date:		2016-05-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddMonitorStock'
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
		select @pvchMessage = ''

		if exists
		(
			select 1
			from StockData.MonitorStock
			where ASXCode = @pvchStockCode
			and MonitorTypeID = 'C'
		)		
			select @pvchMessage = 'ASXCode ' + @pvchStockCode + ' is already monitored.'

		if @pvchMessage= ''
		begin
			insert into [StockData].[MonitorStock]
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,MonitorTypeID
			  ,PriorityLevel
			)
			select
			   upper(@pvchStockCode) as [ASXCode]
			  ,getdate() as [CreateDate]
			  ,null as [LastUpdateDate]
			  ,0 as [UpdateStatus]
			  ,'C' as MonitorTypeID
			  ,99 as PriorityLevel

			insert into [StockData].[MonitorStock]
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,MonitorTypeID
			  ,PriorityLevel
			)
			select
			   upper(@pvchStockCode) as [ASXCode]
			  ,getdate() as [CreateDate]
			  ,null as [LastUpdateDate]
			  ,0 as [UpdateStatus]
			  ,'M' as MonitorTypeID
			  ,99 as PriorityLevel

			--exec [StockData].[usp_RefreshWatchList_CoreStock]
			exec [StockData].[usp_RefeshStockCustomFilter]
			@pbitMonitorStockUpdateOnly = 1

			select @pvchMessage = 'ASXCode ' + @pvchStockCode + ' successfully added.'

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
