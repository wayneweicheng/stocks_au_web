-- Stored procedure: [Report].[usp_GetStockFromTop20Performance]


CREATE PROCEDURE [Report].[usp_GetStockFromTop20Performance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintDaysGoBack as int,
@pvchShareHolder as varchar(500) = null,
@pdtTop20CurrDate as date,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_GetStockFromTop20Performance.sql
Stored Procedure Name: usp_GetStockFromTop20Performance
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
Date:		2020-07-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStockFromTop20Performance'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
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

		if object_id(N'Tempdb.dbo.#TempMergeShare') is not null
			drop table #TempMergeShare

		select ia.*
		into #TempMergeShare
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

		if object_id(N'Tempdb.dbo.#TempStockPriceChange') is not null
			drop table #TempStockPriceChange

		select 
			a.[ASXCode],
			b.ObservationDate as StartObservationDate,
			a.ObservationDate as EndObservationDate,
			a.[Close] as EndClose,
			b.[Close] as StartClose,
			cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			cast(x.Volume * x.[Close]/1000000.0 as decimal(20,2)) as [EndWeekTradeValue(M)],
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
			from #TempMergeShare
			where ASXCode = a.ASXCode
		)
		--and a.[Close] > 0.03
		--and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
		order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 

		if object_id(N'Tempdb.dbo.#TempShareHolder') is not null
			drop table #TempShareHolder

		select top 50 ShareHolder, RecentPerformance
		into #TempShareHolder
		from StockData.ShareHolderRating
		where StockType = 'MidLarge'
		order by RecentPerformance desc;

		if @pbitASXCodeOnly = 0
		begin
			if @pvchShareHolder is not null
			begin
				select 
					'Top20 holder Stocks' as ReportType, 
					cast(c.StartObservationDate as date) as StartObservationDate, 
					c.ASXCode, 
					cast(c.EndObservationDate as date) as EndObservationDate, 
					e.*, c.EndClose, c.StartClose, c.[PriceIncrease%], c.MC, c.CashPosition, c.Nature, c.Poster, cast(d.MedianTradeValue as int) as MedianTradeValue, cast(d.MedianTradeValueDaily as int) as MedianTradeValueDaily, ttsu.FriendlyNameList
				from StockData.Top20Holder as b
				inner join #TempStockPriceChange as c
				on b.ASXCode = c.ASXCode
				inner join #TempShareHolder as e
				on b.HolderName = e.ShareHolder
				left join StockData.MedianTradeValue as d
				on b.ASXCode = d.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on b.ASXCode = ttsu.ASXCode
				where CurrDate = @pdtTop20CurrDate
				and b.HolderName = @pvchShareHolder
				order by d.MedianTradeValue desc
			end
			else
			begin
				select 
					'Top20 holder Stocks' as ReportType, 
					cast(c.StartObservationDate as date) as StartObservationDate, 
					c.ASXCode, 
					cast(c.EndObservationDate as date) as EndObservationDate, 
					e.*, c.EndClose, c.StartClose, c.[PriceIncrease%], c.MC, c.CashPosition, c.Nature, c.Poster, cast(d.MedianTradeValue as int) as MedianTradeValue, cast(d.MedianTradeValueDaily as int) as MedianTradeValueDaily, ttsu.FriendlyNameList
				from StockData.Top20Holder as b
				inner join #TempStockPriceChange as c
				on b.ASXCode = c.ASXCode
				inner join #TempShareHolder as e
				on b.HolderName = e.ShareHolder
				left join StockData.MedianTradeValue as d
				on b.ASXCode = d.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on b.ASXCode = ttsu.ASXCode
				where CurrDate = @pdtTop20CurrDate
				order by e.RecentPerformance desc, e.ShareHolder, d.MedianTradeValue desc
			end
		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempOutput') is not null
				drop table #TempOutput

			select 
			identity(int, 1, 1) as DisplayOrder,
			*
			into #TempOutput
			from
			(
				select 
					'Top20 holder Stocks' as ReportType, 
					cast(c.StartObservationDate as date) as StartObservationDate, 
					c.ASXCode, 
					cast(c.EndObservationDate as date) as EndObservationDate, 
					e.*, c.EndClose, c.StartClose, c.[PriceIncrease%], c.MC, c.CashPosition, c.Nature, c.Poster, cast(d.MedianTradeValue as int) as MedianTradeValue, cast(d.MedianTradeValueDaily as int) as MedianTradeValueDaily
				from StockData.Top20Holder as b
				inner join #TempStockPriceChange as c
				on b.ASXCode = c.ASXCode
				inner join #TempShareHolder as e
				on b.HolderName = e.ShareHolder
				left join StockData.MedianTradeValue as d
				on b.ASXCode = d.ASXCode
				where CurrDate = @pdtTop20CurrDate
			) as x
			order by ASXCode desc;
			
			select
				distinct
				ASXCode,
				DisplayOrder,
				EndObservationDate as ObservationDate,
				OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) as ReportProc
			from #TempOutput

		end



		--select b.ASXCode, avg(a.RecentPerformance) as ShareHolderPerformance, count(*) as NoOfHolder, avg(c.[PriceIncrease%]) as [PriceIncrease%], max(c.MC) as MC, max(c.CashPosition) as CashPosition
		--from StockData.ShareHolderRating as a
		--inner join StockData.Top20Holder as b
		--on a.ShareHolder = b.HolderName
		--inner join #TempStockPriceChange as c
		--on b.ASXCode = c.ASXCode
		--where CurrDate = @pdtTop20CurrDate
		----and b.ASXCode = 'CAZ.AX'
		--and exists
		--(
		--	select 1
		--	from StockData.MedianTradeValue 
		--	where ASXCode = c.ASXCode
		--	and MedianTradeValue > 1000
		--)
		--group by b.ASXCode
		--order by avg(a.RecentPerformance) desc


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