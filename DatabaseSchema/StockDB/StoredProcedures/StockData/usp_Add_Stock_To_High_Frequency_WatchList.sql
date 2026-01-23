-- Stored procedure: [StockData].[usp_Add_Stock_To_High_Frequency_WatchList]


--exec [StockData].[usp_Add_Stock_To_High_Frequency_WatchList]
--@pvchASXCode = 'LLL.AX'

CREATE PROCEDURE [StockData].[usp_Add_Stock_To_High_Frequency_WatchList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10)
AS
/******************************************************************************
File: usp_RefreshWatchList_HighVolume.sql
Stored Procedure Name: [StockData].[usp_Add_Stock_To_High_Frequency_WatchList]
Overview
-----------------
usp_RefreshWatchList_HighVolume

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
Date:		2021-09-21
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
		update a
		set a.WatchListName = 'WL260'
		from StockData.PriceSummaryToday as a
		where a.WatchListName != 'WL260'
		and a.ASXCode = @pvchASXCode

		update a
		set a.WatchListName = 'WL260'
		from StockData.WatchListStock as a
		where a.WatchListName != 'WL260'
		and a.ASXCode = @pvchASXCode

		insert into StockData.WatchListStock
		(
		   [WatchListName]
		  ,[ASXCode]
		  ,[StdASXCode]
		  ,[CreateDate]
		)
		select
		   'WL260' as [WatchListName]
		  ,@pvchASXCode as [ASXCode]
		  ,replace(replace(@pvchASXCode, '.AX', ''), '.US', ':US') as [StdASXCode]
		  ,getdate() as [CreateDate]
		where not exists
		(
			select 1
			from StockData.WatchListStock
			where ASXCode = @pvchASXCode
		)

		insert into StockData.WatchList
		(
			WatchListName,
			AccountName,
			CreateDate,
			LastUpdateDate
		)
		select distinct
			WatchListName,
			null as AccountName,
			getdate() as CreateDate,
			null as LastUpdateDate
		from StockData.WatchListStock as a
		where WatchListName = 'WL260'
		and not exists
		(
			select 1
			from StockData.WatchList
			where WatchListName = a.WatchListName
		)

		update a
		set AccountName = '306932'
		from [StockData].[WatchList] as a
		where WatchListName = 'WL260'

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
