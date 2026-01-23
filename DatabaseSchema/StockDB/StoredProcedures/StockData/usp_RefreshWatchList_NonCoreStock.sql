-- Stored procedure: [StockData].[usp_RefreshWatchList_NonCoreStock]


CREATE PROCEDURE [StockData].[usp_RefreshWatchList_NonCoreStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintBatchSize as int = 200
AS
/******************************************************************************
File: usp_RefreshWatchList.sql
Stored Procedure Name: usp_RefreshWatchList
Overview
-----------------
usp_RefreshWatchList

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
Date:		2018-06-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshWatchList_NonCoreStock'
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
		if object_id(N'Tempdb.dbo.#TempStock') is not null
			drop table #TempStock

		select 
			distinct ASXCode 
		into #TempStock
		from
		(
			select ASXCode
			from StockDAta.PriceHistoryCurrent
			where ObservationDate > Common.DateAddBusinessDay(-5, getdate())
			union
			select ASXCode
			from StockDAta.Announcement
			where AnnDateTime > Common.DateAddBusinessDay(-20, getdate())
			union
			select ASXCode from StockData.CurrentHoldings
			where 1 = 1
		) as x

		delete a
		from #TempStock as a
		inner join [StockData].[WatchListStock] as b
		on a.ASXCode = b.ASXCode

		insert into [StockData].[WatchListStock]
		(
				 [WatchListName]
				,[ASXCode]
				,[StdASXCode]
				,[CreateDate]
		)
		select 
			'WL' + cast((b.CompanyID % 7 + 1 + 100) as varchar(10)) as WatchListName,
			a.ASXCode, 
			replace(replace(a.ASXCode, '.AX', ''), '.US', ':US') as [StdASXCode],
			getdate() as [CreateDate]
		from #TempStock as a
		inner join Stock.ASXCompany as b
		on a.ASXCode = b.ASXCode

		--truncate table [StockData].[WatchListStock]

		--declare @intCount as int = 1
		--declare @vchWLName as varchar(20)
		--declare @intLoopCount as int = 1
		--while @intCount > 0
		--begin
		--	select @vchWLName = 'WL' + cast(@intLoopCount as varchar(10))

		--	insert into [StockData].[WatchListStock]
		--	(
		--		   [WatchListName]
		--		  ,[ASXCode]
		--		  ,[StdASXCode]
		--		  ,[CreateDate]
		--	)
		--	select top (@pintBatchSize)
		--		   @vchWLName as [WatchListName]
		--		  ,[ASXCode]
		--		  ,replace(ASXCode, '.AX', '') as [StdASXCode]
		--		  ,getdate() as [CreateDate]
		--	from #TempStock as a
		--	where not exists
		--	(
		--		select 1
		--		from [StockData].[WatchListStock]
		--		where ASXCode = A.ASXCode
		--	)
		--	order by NEWID()

		--	delete a
		--	from #TempStock as a
		--	where exists
		--	(
		--		select 1
		--		from [StockData].[WatchListStock]
		--		where ASXCode = a.ASXCode
		--	)

		--	select @intCount = @@rowcount

		--	select @intLoopCount = @intLoopCount + 1
		--end

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
		where try_cast(replace(WatchListName, 'WL', '') as int) > 100
		and try_cast(replace(WatchListName, 'WL', '') as int) < 200

		update a
		set AccountName = '306932'
		from [StockData].[WatchList] as a
		where try_cast(replace(WatchListName, 'WL', '') as int) > 100
		and try_cast(replace(WatchListName, 'WL', '') as int) < 200

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
