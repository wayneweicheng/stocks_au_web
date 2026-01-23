-- Stored procedure: [Report].[usp_Get_Strategy_BreakoutRetrace]


CREATE PROCEDURE [Report].[usp_Get_Strategy_BreakoutRetrace]
@pbitDebug AS BIT = 0,
@pintNumPrevDay as int, 
@pintErrorNumber AS INT = 0 OUTPUT,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_BreakoutRetrace.sql
Stored Procedure Name: usp_Get_Strategy_BreakoutRetrace
Overview
-----------------
usp_Get_Strategy_BreakoutRetrace

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
Date:		2020-02-22
Author:		WAYNE CHENG
Description: usp_Get_Strategy_BreakoutRetrace
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_BreakoutRetrace'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		--declare @pintNumPrevDay as int = 4
		
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
	
		declare @pintAlertLookupDay as int = 6
		--declare @pintNumPrevDay as int = 0

		if object_id(N'Tempdb.dbo.#TempAlertHistory') is not null
			drop table #TempAlertHistory

		select distinct
			a.ASXCode
		into #TempAlertHistory
		from 
		(
			select AlertTypeID, ASXCode, CreateDate
			from Stock.ASXAlertHistory
			group by AlertTypeID, ASXCode, CreateDate
		) as a
		inner join LookupRef.AlertType as b
		on a.AlertTypeID = b.AlertTypeID
		where cast(a.CreateDate as date) > cast(dateadd(day, -1 * @pintAlertLookupDay, getdate()) as date)
		
		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[PrevClose] decimal(20, 4),
			ObservationDate date
		)

		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate) from StockData.v_PriceSummary

		if @pintNumPrevDay = 0
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, a.ObservationDate
			from StockData.PriceSummaryToday as a
			--inner join StockData.PriceHistoryCurrent as b
			--on a.ASXCode = b.ASXCode
			where ObservationDate = @dtMaxDate
			and DateTo is null
			and exists
			(
				select 1
				from #TempAlertHistory
				where ASXCode = a.ASXCode
			)

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			from StockData.PriceSummary as a
			where ObservationDate = @dtMaxDate
			and a.LatestForTheDay = 1
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)			
			and exists
			(
				select 1
				from #TempAlertHistory
				where ASXCode = a.ASXCode
			)
		end
		else
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			from StockData.PriceSummary as a
			where ObservationDate = [Common].[DateAddBusinessDay](-1 * @pintNumPrevDay, @dtMaxDate)
			and a.LatestForTheDay = 1

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			from StockData.StockStatsHistoryPlus as a
			where ObservationDate = [Common].[DateAddBusinessDay](-1 * @pintNumPrevDay, @dtMaxDate)
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)			
			
		end

		if @pbitASXCodeOnly = 0
		begin
			select 
				'RetraceToMA10' as ReportType,			
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				a.*,
				b.MovingAverage5d, 
				b.MovingAverage10d, 
				b.MovingAverage20d, 
				b.MovingAverage30d, 
				ttsu.FriendlyNameList,
				c.MC, 
				c.CashPosition,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d
			from #TempPriceSummary as a
			inner join ScanResults.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where a.[Close] > b.MovingAverage10d
			and a.[Close] < b.MovingAverage5d
			and a.[Close] < b.MovingAverage10d + 2 * [Common].[GetPriceTick](a.[Close])
			union
			select 
				'RetraceToMA5' as ReportType,			
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				a.*,
				b.MovingAverage5d, 
				b.MovingAverage10d, 
				b.MovingAverage20d, 
				b.MovingAverage30d, 
				ttsu.FriendlyNameList,
				c.MC, 
				c.CashPosition,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d
			from #TempPriceSummary as a
			inner join ScanResults.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			inner join ScanResults.StockStatsHistoryPlus as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = [Common].[DateAddBusinessDay](1, d.ObservationDate)
			and d.[Close] > b.[Close]
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where a.[Close] > b.MovingAverage5d
			and a.[Close] <= b.MovingAverage5d + 1 * [Common].[GetPriceTick](a.[Close])
			union
			select 
				'RetraceToMA20' as ReportType,	
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				a.*,		
				b.MovingAverage5d, 
				b.MovingAverage10d, 
				b.MovingAverage20d, 
				b.MovingAverage30d, 
				ttsu.FriendlyNameList,
				c.MC, 
				c.CashPosition,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d
			from #TempPriceSummary as a
			inner join ScanResults.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where a.[Close] > b.MovingAverage20d
			and a.[Close] < b.MovingAverage10d
			and b.MovingAverage20d > b.MovingAverage30d
			and a.[Close] < b.MovingAverage20d + 2 * [Common].[GetPriceTick](a.[Close])
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
					'RetraceToMA10' as ReportType,			
					format(j.MedianTradeValue, 'N0') as MedianTradeValue,
					a.*,
					b.MovingAverage5d, 
					b.MovingAverage10d, 
					b.MovingAverage20d, 
					b.MovingAverage30d, 
					c.MC, 
					c.CashPosition,
					l.TrendMovingAverage60d,
					l.TrendMovingAverage200d
				from #TempPriceSummary as a
				inner join ScanResults.StockStatsHistoryPlus as b
				on a.ASXCode = b.ASXCode
				and a.ObservationDate = b.ObservationDate
				left join #TempCashVsMC as c
				on a.ASXCode = c.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue from StockData.MedianTradeValue
				) as j
				on a.ASXCode = j.ASXCode
				left join StockData.StockStatsHistoryPlusCurrent as l
				on a.ASXCode = l.ASXCode
				where a.[Close] > b.MovingAverage10d
				and a.[Close] < b.MovingAverage5d
				and a.[Close] < b.MovingAverage10d + 2 * [Common].[GetPriceTick](a.[Close])
				union
				select 
					'RetraceToMA5' as ReportType,			
					format(j.MedianTradeValue, 'N0') as MedianTradeValue,
					a.*,
					b.MovingAverage5d, 
					b.MovingAverage10d, 
					b.MovingAverage20d, 
					b.MovingAverage30d, 
					c.MC, 
					c.CashPosition,
					l.TrendMovingAverage60d,
					l.TrendMovingAverage200d
				from #TempPriceSummary as a
				inner join ScanResults.StockStatsHistoryPlus as b
				on a.ASXCode = b.ASXCode
				and a.ObservationDate = b.ObservationDate
				inner join ScanResults.StockStatsHistoryPlus as d
				on a.ASXCode = d.ASXCode
				and a.ObservationDate = [Common].[DateAddBusinessDay](1, d.ObservationDate)
				and d.[Close] > b.[Close]
				left join #TempCashVsMC as c
				on a.ASXCode = c.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue from StockData.MedianTradeValue
				) as j
				on a.ASXCode = j.ASXCode
				left join StockData.StockStatsHistoryPlusCurrent as l
				on a.ASXCode = l.ASXCode
				where a.[Close] > b.MovingAverage5d
				and a.[Close] <= b.MovingAverage5d + 1 * [Common].[GetPriceTick](a.[Close])
				union
				select 
					'RetraceToMA20' as ReportType,	
					format(j.MedianTradeValue, 'N0') as MedianTradeValue,
					a.*,		
					b.MovingAverage5d, 
					b.MovingAverage10d, 
					b.MovingAverage20d, 
					b.MovingAverage30d, 
					c.MC, 
					c.CashPosition,
					l.TrendMovingAverage60d,
					l.TrendMovingAverage200d
				from #TempPriceSummary as a
				inner join ScanResults.StockStatsHistoryPlus as b
				on a.ASXCode = b.ASXCode
				and a.ObservationDate = b.ObservationDate
				left join #TempCashVsMC as c
				on a.ASXCode = c.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue from StockData.MedianTradeValue
				) as j
				on a.ASXCode = j.ASXCode
				left join StockData.StockStatsHistoryPlusCurrent as l
				on a.ASXCode = l.ASXCode
				where a.[Close] > b.MovingAverage20d
				and a.[Close] < b.MovingAverage10d
				and b.MovingAverage20d > b.MovingAverage30d
				and a.[Close] < b.MovingAverage20d + 2 * [Common].[GetPriceTick](a.[Close])
			) as x

			select
				distinct
				ASXCode,
				DisplayOrder,
				ObservationDate,
				OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) as ReportProc
			from #TempOutput

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
