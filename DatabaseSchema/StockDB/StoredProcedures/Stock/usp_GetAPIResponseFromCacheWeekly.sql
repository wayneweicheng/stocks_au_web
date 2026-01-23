-- Stored procedure: [Stock].[usp_GetAPIResponseFromCacheWeekly]


--exec [Stock].[usp_GetAPIResponseFromCache]
--@pvchASXCode = 'DCC.AX'



CREATE PROCEDURE [Stock].[usp_GetAPIResponseFromCacheWeekly]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10),
@pintCacheExpiryTime int = null,
@pvchSourceID varchar(4) = null,
@pvchResponseType varchar(10) = null
AS
/******************************************************************************
File: usp_GetAPIResponseFromCacheWeekly.sql
Stored Procedure Name: usp_GetAPIResponseFromCacheWeekly
Overview
-----------------
usp_GetAPIResponseFromCacheWeekly

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
Date:		2016-06-14
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetAPIResponseFromCacheWeekly'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Stock'
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
		--declare @pvchASXCode as varchar(10) = 'DCC.AX'

		if object_id(N'Tempdb.dbo.#TempStockHistoryCombined') is not null
			drop table #TempStockHistoryCombined

		select 
		   [ASXCode]
		  ,WeekCloseDate as [ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		into #TempStockHistoryCombined
		from StockData.PriceHistoryWeekly
		where ASXCode = @pvchASXCode

		if object_id(N'Tempdb.dbo.#TempStockHistory') is not null
			drop table #TempStockHistory

		select
			@pvchASXCode as ASXCode, DisplayOrder, Content, getdate() as CreateDate
		into #TempStockHistory
		from
		(
		select
			1 as DisplayOrder, 'volume:' as Content
		union
		select 
			2 as DisplayOrder,
			cast(datepart(year, ObservationDate) as varchar(20)) + right('0' + cast(datepart(month, ObservationDate) as varchar(20)), 2) + right('0' + cast(datepart(day, ObservationDate) as varchar(20)), 2) + ',' +
			cast([close] as varchar(50)) + ',' +
			cast([high] as varchar(50)) + ',' +
			cast([low] as varchar(50)) + ',' +
			cast([open] as varchar(50)) + ',' +
			cast([volume] as varchar(50)) as Content
		from #TempStockHistoryCombined
		where ASXCode = @pvchASXCode
		and datediff(day, ObservationDate, getdate()) < 365 * 3
		) as x
		order by DisplayOrder, Content

		declare @vchResponse as varchar(max)

		select @vchResponse = coalesce(@vchResponse + + CHAR(13)+CHAR(10), '') + Content from #TempStockHistory
		order by DisplayOrder, Content

		select @pvchASXCode as ASXCode, @vchResponse as Response

		
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