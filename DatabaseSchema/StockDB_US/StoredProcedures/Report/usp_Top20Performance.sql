-- Stored procedure: [Report].[usp_Top20Performance]


--exec [Report].[usp_Top20Performance]
--@pdtTop20CurrDate = '2020-06-30',
--@pintDaysGoBack = 20,
--@pvchStockType = 'All'

--exec [Report].[usp_Top20Performance]
--@pdtTop20CurrDate = '2020-06-30',
--@pintDaysGoBack = 120,
--@pvchStockType = 'All'

--exec [Report].[usp_Top20Performance]
--@pdtTop20CurrDate = '2020-06-30',
--@pintDaysGoBack = 20,
--@pvchStockType = 'MidLarge'

--exec [Report].[usp_Top20Performance]
--@pdtTop20CurrDate = '2020-06-30',
--@pintDaysGoBack = 120,
--@pvchStockType = 'MidLarge'


CREATE PROCEDURE [Report].[usp_Top20Performance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pdtTop20CurrDate as date,
@pintDaysGoBack as int,
@pvchStockType as varchar(50)
AS
/******************************************************************************
File: usp_SelectPriceReverse.sql
Stored Procedure Name: usp_SelectPriceReverse
Overview
-----------------
usp_SelectPriceReverse

Input Parameters
----------------
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
Date:		2018-08-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Top20Performance'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pdtTop20CurrDate as date = '2020-07-31'
		--declare @pintDaysGoBack as int = 120
		--declare @pvchStockType as varchar(50) = 'All'
		
		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition
		) as x
		where RowNumber = 1

		delete a
		from #TempCashPosition as a
		where datediff(day, AnnDateTime, getdate()) > 105

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempStockNature') is not null
			drop table #TempStockNature

		select a.ASXCode, stuff((
			select ',' + Token
			from StockData.StockNature
			where ASXCode = a.ASXCode
			order by AnnCount desc
			for xml path('')), 1, 1, ''
		) as Nature
		into #TempStockNature
		from StockData.StockNature as a
		group by a.ASXCode

		if object_id(N'Tempdb.dbo.#TempStockPriceChange') is not null
			drop table #TempStockPriceChange

		select 
			a.[ASXCode],
			b.ObservationDate as StartObservationDate,
			a.ObservationDate as EndObservationDate,
			a.[Close] as EndClose,
			b.[Close] as StartClose,
			cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) as [EndWeekTradeValue(M)],
			y.MC,
			y.CashPosition,
			d.Nature,
			i.Poster
		into #TempStockPriceChange
		from StockData.StockStatsHistoryPlus as a
		inner join StockData.StockStatsHistoryPlus as b
		on a.ASXCode = b.ASXCode
		--and a.[Close] >= 1.5 * b.[Close]
		and a.[Close] > 0
		and b.[Close] > 0
		and a.DateSeqReverse = 0 + 1
		and b.DateSeqReverse = 0 + @pintDaysGoBack + 1
		left join #TempCashVsMC as y
		on a.ASXCode = y.ASXCode
		left join #TempStockNature as d
		on a.ASXCode = d.ASXCode
		left join Transform.PosterList as i
		on a.ASXCode = i.ASXCode
		left join StockData.PriceHistoryWeekly as x
		on a.ObservationDate >= x.WeekOpenDate
		and a.ObservationDate <= x.WeekCloseDate
		and a.ASXCode = x.ASXCode
		where 1 = 1
		and a.ObservationDate > dateadd(day, -10, getdate())
		and not exists
		(
			select 1
			--a.*, b.[Close], cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%]
			from StockData.StockStatsHistoryPlus as ia
			inner join StockData.StockStatsHistoryPlus as ib
			on ia.ASXCode = ib.ASXCode
			and ia.[Close] >= 3 * ib.[Close]
			and ia.[Close] > 0
			and ib.[Close] > 0
			and ia.DateSeqReverse + 1 = ib.DateSeqReverse
			and ia.Volume * ib.[Close] < 300000
			and ia.Volume * ia.[Close] < 300000
			and ia.ObservationDate > dateadd(day, -120, getdate())
			and ia.ASXCode = a.ASXCode
		)
		--and a.[Close] > 0.03
		--and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
		and case when @pvchStockType = 'All' then 1
				 when @pvchStockType = 'MidLarge' and 
						exists
						(
							select 1
							from StockData.MedianTradeValue 
							where ASXCode = a.ASXCode
							and MedianTradeValue > 2000
						)
				  then 1
			end = 1
		order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 

		if object_id(N'Tempdb.dbo.#TempHolderPerformance') is not null
			drop table #TempHolderPerformance

		select 
			b.HolderName as ShareHolder,
			cast(null as smallint) as Rating,
			avg(case when [PriceIncrease%] > 100 then 100 else [PriceIncrease%] end) as RecentPerformance,
			count(*) as NoStocks,
			min([PriceIncrease%]) as WorstStockPerformance,
			max([PriceIncrease%]) as BestStockPerformance,
			cast(null as decimal(10, 2)) as StdRecentPerformance,
			dateadd(month, datediff(month, 0, getdate()), 0) as ReportPeriod,
			getdate() as CreateDate
		into #TempHolderPerformance
		from #TempStockPriceChange as a
		inner join StockData.Top20Holder as b
		on a.ASXCode = b.ASXCode
		where CurrDate = @pdtTop20CurrDate
		and [PriceIncrease%] < 1000
		group by b.HolderName
		having count(*) >= 1

		delete a
		from [StockData].[ShareHolderStockPriceChange] as a
		where a.CurrDate = @pdtTop20CurrDate
		and a.DaysGoBack = @pintDaysGoBack
		and a.StockType = @pvchStockType
		
		insert into [StockData].[ShareHolderStockPriceChange]
		(
			[ASXCode],
			ShareHolder,
			[StartObservationDate],
			[EndObservationDate],
			[EndClose],
			[StartClose],
			[PriceIncrease%],
			[EndWeekTradeValue(M)],
			[MC],
			[CashPosition],
			[Nature],
			[Poster],
			CurrDate,
			DaysGoBack,
			StockType
		)
		select
			a.[ASXCode],
			b.HolderName as ShareHolder,
			a.[StartObservationDate],
			a.[EndObservationDate],
			a.[EndClose],
			a.[StartClose],
			a.[PriceIncrease%],
			a.[EndWeekTradeValue(M)],
			a.[MC],
			a.[CashPosition],
			a.[Nature],
			a.[Poster],
			@pdtTop20CurrDate as CurrDate,
			@pintDaysGoBack as DaysGoBack,
			@pvchStockType as StockType
		from #TempStockPriceChange as a
		inner join StockData.Top20Holder as b
		on a.ASXCode = b.ASXCode
		where CurrDate = @pdtTop20CurrDate
		and [PriceIncrease%] < 1000

		delete a
		from StockData.ShareHolderRating as a
		inner join #TempHolderPerformance as b
		on a.ShareHolder = b.ShareHolder
		and a.ReportPeriod = b.ReportPeriod
		and a.StockType = @pvchStockType
		and a.DaysGoBack = @pintDaysGoBack

		insert into StockData.ShareHolderRating
		(
			ShareHolder,
			Rating,
			RecentPerformance,
			NoStocks,
			WorstStockPerformance,
			BestStockPerformance,
			StdRecentPerformance,
			ReportPeriod,
			StockType,
			DaysGoBack,
			CreateDate
		)
		select
			ShareHolder,
			Rating,
			RecentPerformance,
			NoStocks,
			WorstStockPerformance,
			BestStockPerformance,
			StdRecentPerformance,
			ReportPeriod,
			@pvchStockType as StockType,
			@pintDaysGoBack as DaysGoBack,
			CreateDate
		from #TempHolderPerformance
		
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
