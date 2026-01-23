-- Stored procedure: [StockData].[usp_RefreshWatchList]



CREATE PROCEDURE [StockData].[usp_RefreshWatchList]
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshWatchList'
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
		if object_id(N'Tempdb.dbo.#TempAnn') is not null
			drop table #TempAnn

		declare @dtObservationDate as date = cast(getdate() as date)

		select distinct ASXCode, cast(AnnDateTime as date) as ObservationDate
		into #TempAnn
		from StockData.Announcement with(nolock)
		where 
		(
			AnnDescr like 'Pre-quotation Disclosure%'
			and 
			Common.DateAddBusinessDay(3, cast(AnnDateTime as date)) >= @dtObservationDate
		)
		
		if object_id(N'Tempdb.dbo.#TempAnnRanked') is not null
			drop table #TempAnnRanked
		
		select top 150 *
		into #TempAnnRanked
		from #TempAnn as a
		order by ASXCode asc

		if object_id(N'Tempdb.dbo.#TempStock') is not null
			drop table #TempStock

		select 
			distinct ASXCode 
		into #TempStock
		from
		(
			select ASXCode from StockData.CurrentHoldings
			where 1 = 1
			union
			select ASXCode from StockData.MedianTradeValue
			where MedianTradeValue > 2000
			and ASXCode like '%.AX'
			union
			select ASXCode from StockData.MedianTradeValue
			where MedianTradeValueDaily > 500
			and ASXCode like '%.AX'
			union
			select distinct a.ASXCode
			from StockData.Announcement as a
			inner join StockDAta.PriceHistoryCurrent as b
			on a.ASXCode = b.ASXCode
			where cast(AnnDateTime as date) = cast(getdate() as date)
			and b.[Close] < 2.0
			and a.MarketSensitiveIndicator = 1
			union
			select ASXCode
			from StockData.MonitorStock
			where MonitorTypeID = 'C'
			--and isnull(PriorityLevel, 999) > 999
			union
			select ASXCode
			from Alert.TradingAlert
			where AlertTriggerDate is null
			union
			select distinct ASXCode
			from StockData.TopBrokerRecentBuy
			union
			select 
				a.ASXCode
			from StockData.RelativePriceStrength as a
			left join [StockData].[MedianTradeValue] as b
			on a.ASXCode = b.ASXCode
			where DateSeq = 1
			and MedianTradeValue > 2000
			and RelativePriceStrength >  75
			union
			select distinct a.ASXCode
			from 
			(
				select AlertTypeID, ASXCode, CreateDate
				from Stock.ASXAlertHistory
				group by AlertTypeID, ASXCode, CreateDate
			) as a
			inner join LookupRef.AlertType as b
			on a.AlertTypeID = b.AlertTypeID
			where cast(a.CreateDate as date) > cast(Common.DateAddBusinessDay(-1 * 25, getdate()) as date)
			and cast(a.CreateDate as date) <=  cast(Common.DateAddBusinessDay(-1 * 1, getdate()) as date)
			and b.AlertTypeName in
			(
				'Break Through',
				'Breakaway Gap',
				'Breakthrough Trading Range', 
				'Gain Momentum'
			)
			union 
			select distinct a.ASXCode
			from 
			(
				select *
				from StockData.DirectorBuyOnMarket
			) as a
			union 
			select distinct a.ASXCode
			from 
			(
				select *
				from #TempAnnRanked
			) as a
			union
			select distinct a.ASXCode
			from StockData.CustomFilterHistory as a
			where cast(a.ObservationDate as date) > cast(Common.DateAddBusinessDay(-1 * 5, getdate()) as date)
		) as x

		--select 
		--	distinct ASXCode 
		--into #TempStock
		--from
		--(
		--	select distinct ASXCode 
		--	from HC.CommonStockPlusHistory as a
		--	where datediff(day, CreateDate, getdate()) <= 60
		--	and not exists
		--	(
		--		select 1
		--		from StockData.StockOverviewCurrent
		--		where ASXCode = a.ASXCode
		--		and CleansedMarketCap > 5000
		--	)
		--	union
		--	select [ASXCode]
		--	from LookupRef.StockKeyToken as a
		--	union
		--	select ASXCode from StockData.PriceHistory as a
		--	where datediff(day, ObservationDate, getdate()) <= 90
		--	and not exists
		--	(
		--		select 1
		--		from StockData.StockOverviewCurrent
		--		where ASXCode = a.ASXCode
		--		and CleansedMarketCap > 5000
		--	)
		--	group by ASXCode
		--	having avg([Value]) > 300000
		--	union
		--	select ASXCode
		--	from StockData.MonitorStock
		--	where MonitorTypeID = 'C'
		--	union
		--	select ASXCode
		--	from Alert.TradingAlert
		--	where AlertTriggerDate is null
		--	union
		--	select ASXCode 
		--	from [StockData].StockOverviewCurrent AS h
		--	where CleansedMarketCap between 100 and 2000
		--	and exists
		--	(
		--		select 1
		--		from 
		--		(
		--			select ASXCode, CleansedMarketCap, sum(NetValue) as NetValue
		--			from [Transform].[BrokerInsight]
		--			where datediff(day, ObservationDate, getdate()) < 10
		--			and NetValue > 400000
		--			and BrokerCode in ('ArgSec', 'PatSec', 'Macqua', 'UBSAus', 'Deusec', 'Suspac', 'Ordmin', 'Pershn')
		--			group by ASXCode, CleansedMarketCap
		--			having sum(NetValue) > 400000
		--		) as x
		--		where x.ASXCode = h.ASXCode
		--	)
		--	union
		--	select ASXCode 
		--	from [StockData].StockOverviewCurrent AS h
		--	where CleansedMarketCap between 50 and 600
		--	and exists
		--	(
		--		select 1
		--		from 
		--		(
		--			select ASXCode, CleansedMarketCap, sum(NetValue) as NetValue
		--			from [Transform].[BrokerInsight]
		--			where datediff(day, ObservationDate, getdate()) < 10
		--			and NetValue > 150000
		--			and BrokerCode in ('ArgSec', 'PatSec', 'HarLim', 'SusPac', 'BaiHol', 'PerShn', 'BelPot')
		--			group by ASXCode, CleansedMarketCap
		--			having sum(NetValue) > 150000
		--		) as x
		--		where x.ASXCode = h.ASXCode
		--	)
		--	union
		--	select distinct a.ASXCode
		--	from StockData.Announcement as a
		--	inner join StockDAta.PriceHistoryCurrent as b
		--	on a.ASXCode = b.ASXCode
		--	where cast(AnnDateTime as date) = cast(getdate() as date)
		--	and b.[Close] < 2.0
		--) as x

		delete a
		from [StockData].[WatchListStock] as a

		dbcc checkident('[StockData].[WatchListStock]', reseed, 1);

		insert into [StockData].[WatchListStock]
		(
				 [WatchListName]
				,[ASXCode]
				,[StdASXCode]
				,[CreateDate]
		)
		select 
			'WL' + cast((b.CompanyID % 9 + 1) as varchar(10)) as WatchListName,
			a.ASXCode, 
			replace(replace(a.ASXCode, '.AX', ''), '.US', ':US') as [StdASXCode],
			getdate() as [CreateDate]
		from #TempStock as a
		inner join Stock.ASXCompany as b
		on a.ASXCode = b.ASXCode
		where a.ASXCode like '%.%'

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

		delete a
		from StockData.WatchList as a

		dbcc checkident('StockData.WatchList', reseed, 1);

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
		from StockData.WatchListStock

		update a
		set AccountName = '338628'
		from [StockData].[WatchList] as a
		where WatchListName != 'WL99'
		and WatchListID % 2 = 0

		update a
		set AccountName = '305348'
		from [StockData].[WatchList] as a
		where WatchListName != 'WL99'
		and WatchListID % 2 != 0

		exec [StockData].[usp_RefreshWatchList_HighVolume]

		--exec [StockData].[usp_RefreshWatchList_NonCoreStock]

		--update a
		--set AccountName = '305348'
		--from [StockData].[WatchList] as a
		--where WatchListID % 2 = 1
		
		--exec [StockData].[usp_RefreshWatchList_CoreStock]

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
