-- Stored procedure: [StockData].[usp_RefreshWatchList_HighVolume]


CREATE PROCEDURE [StockData].[usp_RefreshWatchList_HighVolume]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshWatchList_HighVolume.sql
Stored Procedure Name: usp_RefreshWatchList_HighVolume
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
		if object_id(N'Tempdb.dbo.#TempHighVolume') is not null
			drop table #TempHighVolume

		create table #TempHighVolume
		(
			ASXCode varchar(10),
			RankOrder int
		)

		insert into #TempHighVolume
		(
			ASXCode,
			RankOrder
		)
		select
			ASXCode,
			0 as RankOrder
		from StockData.WatchListStock
		where WatchListName = 'WL260'
		union
		select 
			ASXCode,
			0 as RankOrder
		from (
			select ASXCode
			from StockData.MarketScan
			where ObservationDate = cast(getdate() as date)
			and ScanCode in ('HOT_BY_PRICE_RANGE', 'HOT_BY_PRICE', 'HOT_BY_VOLUME')
			and len(ASXCode) = 6
			group by ASXCode
		) as a

		--delete a
		--from #TempHighVolume as a
		--inner join
		--(
		--	select *
		--	from StockData.v_PriceSummary_Latest
		--	where ObservationDate = cast(getdate() as date)
		--	and PriceChangeVsPrevClose < 0
		--) as b
		--on a.ASXCode = b.ASXCode
		
		update a
		set a.WatchListName = 'WL260'
		from StockData.PriceSummaryToday as a
		inner join #TempHighVolume as b
		on a.ASXCode = b.ASXCode
		where a.WatchListName != 'WL260'

		update a
		set a.WatchListName = 'WL260'
		from StockData.WatchListStock as a
		inner join #TempHighVolume as b
		on a.ASXCode = b.ASXCode
		where a.WatchListName != 'WL260'

		insert into StockData.WatchListStock
		(
		   [WatchListName]
		  ,[ASXCode]
		  ,[StdASXCode]
		  ,[CreateDate]
		)
		select
		   'WL260' as [WatchListName]
		  ,a.ASXCode as [ASXCode]
		  ,replace(replace(a.ASXCode, '.AX', ''), '.US', ':US') as [StdASXCode]
		  ,getdate() as [CreateDate]
		from #TempHighVolume as a
		where not exists
		(
			select 1
			from StockData.WatchListStock
			where ASXCode = a.ASXCode
		)
		and a.ASXCode like '%.%'

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
