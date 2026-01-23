-- Stored procedure: [Report].[usp_Get_Strategy_TraceMomentumStock]


CREATE PROCEDURE [Report].[usp_Get_Strategy_TraceMomentumStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_TraceMomentumStock.sql
Stored Procedure Name: usp_Get_Strategy_TraceMomentumStock
Overview
-----------------
usp_Get_Strategy_TraceMomentumStock

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
Date:		2021-03-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_TraceMomentumStock'
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
		--declare @pintNumPrevDay as int = 0
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtNextDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 1, getdate()) as date)
		declare @dtPrevDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 1, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select * 
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where 1 = 0

		if exists
		(
			select 1
			from StockData.v_PriceSummary
			where ObservationDate = @dtObservationDate
			and DateTo is null
			and LatestForTheDay = 1
		)
		begin
			insert into #TempPriceSummary
			select *
			from StockData.v_PriceSummary
			where ObservationDate = @dtObservationDate
			and DateTo is null
			and LatestForTheDay = 1
		end
		else
		begin
			insert into #TempPriceSummary
			select *
			from StockData.v_PriceSummary
			where ObservationDate = @dtPrevDate
			and DateTo is null
			and LatestForTheDay = 1
		end

		delete a
		from #TempPriceSummary as a
		where exists
		(
			select 1
			from #TempPriceSummary 
			where ASXCode = a.ASXCode
			and DateFrom > a.DateFrom
		)

		if object_id(N'Tempdb.dbo.#TempNextDayPrice') is not null
			drop table #TempNextDayPrice

		select * 
		into #TempNextDayPrice
		from StockData.PriceHistory
		where ObservationDate = @dtNextDate

		if object_id(N'Tempdb.dbo.#TempAlertHistory') is not null
			drop table #TempAlertHistory

		select 
			identity(int, 1, 1) as UniqueKey,
			b.AlertTypeName,
			a.ASXCode,
			a.CreateDate,
			cast(a.CreateDate as date) as ObservationDate,
			c.[Value],
			c.Volume,
			c.[High],
			c.[Close],
			d.MedianTradeValue,
			d.MedianTradeValueDaily,
			d.MedianPriceChangePerc,
			case when b.AlertTypeName in ('Breakaway Gap') then 40 
				 when b.AlertTypeName in ('Break Through') then 30 
				 when b.AlertTypeName in ('Gain Momentum', 'Breakthrough Trading Range') then 15
				 else 10
			end as AlertTypeScore
		into #TempAlertHistory
		from 
		(
			select AlertTypeID, ASXCode, CreateDate
			from Stock.ASXAlertHistory
			group by AlertTypeID, ASXCode, CreateDate
		) as a
		inner join LookupRef.AlertType as b
		on a.AlertTypeID = b.AlertTypeID
		inner join StockData.PriceHistory as c
		on a.ASXCode = c.ASXCode
		and cast(a.CreateDate as date) = c.ObservationDate
		left join StockData.MedianTradeValue as d
		on a.ASXCode = d.ASXCode
		where cast(a.CreateDate as date) > cast(Common.DateAddBusinessDay(-1 * 25, @dtObservationDate) as date)
		and cast(a.CreateDate as date) <=  cast(Common.DateAddBusinessDay(-1 * 1, @dtObservationDate) as date)
		and b.AlertTypeName in
		(
			'Break Through',
			'Breakaway Gap',
			'Breakthrough Trading Range',
			'Gain Momentum'
		)
		order by a.CreateDate desc

		if object_id(N'Tempdb.dbo.#TempAlertHistoryAggregate') is not null
			drop table #TempAlertHistoryAggregate

		select 
			x1.ASXCode,
			x1.AlertTypeName,
			x1.CreateDate,
			x1.ObservationDate,
			x1.MedianTradeValue,
			x1.MedianTradeValueDaily,
			x1.MedianPriceChangePerc,
			y.AlertTypeScore
		into #TempAlertHistoryAggregate
		from
		(
			select 
				x.ASXCode,
				x.CreateDate,
				x.ObservationDate,
				x.MedianTradeValue,
				x.MedianTradeValueDaily,
				x.MedianPriceChangePerc,
				stuff((
				select ',' + [AlertTypeName]
				from #TempAlertHistory as a
				where x.ASXCode = a.ASXCode
				order by AlertTypeScore desc
				for xml path('')), 1, 1, ''
				) as [AlertTypeName],
				row_number() over (partition by ASXCode order by AlertTypeScore desc) as RowNumber
			from #TempAlertHistory as x
		) as x1
		inner join 
		(
			select ASXCode, sum(AlertTypeScore) as AlertTypeScore
			from #TempAlertHistory 
			group by ASXCode
		) as y
		on x1.ASXCode = y.ASXCode
		where x1.RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate >= Common.DateAddBusinessDay(-8, @dtObservationDate)
		and ObservationDate <= @dtObservationDate
		group by ASXCode, BrokerCode

		if object_id(N'Tempdb.dbo.#TempBrokerReportList') is not null
			drop table #TempBrokerReportList

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregate as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportList
		from #TempBRAggregate as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNeg') is not null
			drop table #TempBrokerReportListNeg

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregate as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNeg
		from #TempBRAggregate as x
		
		if @pbitASXCodeOnly = 0
		begin
			select 
				'Trace Momentum Stock' as ReportType,
				a.AlertTypeName,
				a.ASXCode,
				d.ObservationDate as ObservationDate,
				d.[Close] as CurrPrice,
				[Common].[RoundStockPrice](s.MovingAverage5d + 0*[Common].[GetPriceTick](s.MovingAverage5d)) as MovingAverage5dPrice,
				[Common].[RoundStockPrice](s.MovingAverage10d + 0*[Common].[GetPriceTick](s.MovingAverage10d)) as MovingAverage10dPrice,
				cast(a.MedianTradeValue as int) as [MedianValue Wk],
				cast(a.MedianTradeValueDaily as int) as [MedianValue Day],
				cast(a.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
				case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
				case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				ttsu.FriendlyNameList,
				o.NoBuy,
				p.NoSigNotice as NoSig,
				q.WeekMonthPositive as [WkMon+]
			from #TempAlertHistoryAggregate as a
			inner join #TempPriceSummary as d
			on a.ASXCode = d.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			left join 
			(
				select ASXCode, count(ASXCode) as NoBuy
				from StockData.DirectorBuyOnMarket
				group by ASXCode
			) as o
			on a.ASXCode = o.ASXCode
			left join 
			(
				select ASXCode, count(ASXCode) as NoSigNotice
				from StockData.SignificantHolder
				group by ASXCode
			) as p
			on a.ASXCode = p.ASXCode
			left join 
			(
				select ASXCode, sum(case when ASXCode is not null then 1 else 0 end) as WeekMonthPositive 
				from StockData.WeeklyMonthlyPriceAction
				where CreateDate > Common.DateAddBusinessDay(-3, getdate())
				group by ASXCode
			) as q
			on a.ASXCode = q.ASXCode
			left join ScanResults.StockStatsHistoryPlus as s
			on a.ASXCode = s.ASXCode
			and s.DateSeqReverse = 1
			left join ScanResults.StockStatsHistoryPlus as s2
			on a.ASXCode = s2.ASXCode
			and s2.DateSeqReverse = 2
			left join ScanResults.StockStatsHistoryPlus as s3
			on a.ASXCode = s3.ASXCode
			and s3.DateSeqReverse = 3
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where 1 = 1
			and s3.MovingAverage20d < s2.MovingAverage20d
			and s2.MovingAverage20d < s.MovingAverage20d
			and d.[Close] > s.MovingAverage10d 
			and d.[Close] < 3
			and a.MedianPriceChangePerc >  0.5
			--and a.ASXCode = 'AVG.AX'
			order by abs(case when s.MovingAverage5d > 0 then cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) else null end) asc

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
					a.ObservationDate as BreakThroughDate,
					'Trace Momentum Stock' as ReportType,
					a.ASXCode,
					d.ObservationDate as CurrDate,
					d.[Close] as CurrPrice,
					[Common].[RoundStockPrice](s.MovingAverage5d + 0*[Common].[GetPriceTick](s.MovingAverage5d)) as MovingAverage5dPrice,
					[Common].[RoundStockPrice](s.MovingAverage10d + 0*[Common].[GetPriceTick](s.MovingAverage10d)) as MovingAverage10dPrice,
					cast(a.MedianTradeValue as int) as [MedianValue Wk],
					cast(a.MedianTradeValueDaily as int) as [MedianValue Day],
					cast(a.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
					case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
					case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
					a.AlertTypeName,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker,
					o.NoBuy,
					p.NoSigNotice as NoSig,
					q.WeekMonthPositive as [WkMon+]
				from #TempAlertHistoryAggregate as a
				inner join #TempPriceSummary as d
				on a.ASXCode = d.ASXCode
				left join #TempBrokerReportList as m
				on a.ASXCode = m.ASXCode
				left join #TempBrokerReportListNeg as n
				on a.ASXCode = n.ASXCode
				left join 
				(
					select ASXCode, count(ASXCode) as NoBuy
					from StockData.DirectorBuyOnMarket
					group by ASXCode
				) as o
				on a.ASXCode = o.ASXCode
				left join 
				(
					select ASXCode, count(ASXCode) as NoSigNotice
					from StockData.SignificantHolder
					group by ASXCode
				) as p
				on a.ASXCode = p.ASXCode
				left join 
				(
					select ASXCode, sum(case when ASXCode is not null then 1 else 0 end) as WeekMonthPositive 
					from StockData.WeeklyMonthlyPriceAction
					where CreateDate > Common.DateAddBusinessDay(-3, getdate())
					group by ASXCode
				) as q
				on a.ASXCode = q.ASXCode
				left join ScanResults.StockStatsHistoryPlus as s
				on a.ASXCode = s.ASXCode
				and s.DateSeqReverse = 1
				left join ScanResults.StockStatsHistoryPlus as s2
				on a.ASXCode = s2.ASXCode
				and s2.DateSeqReverse = 2
				left join ScanResults.StockStatsHistoryPlus as s3
				on a.ASXCode = s3.ASXCode
				and s3.DateSeqReverse = 3
				where 1 = 1
				and s3.MovingAverage20d < s2.MovingAverage20d
				and s2.MovingAverage20d < s.MovingAverage20d
				and d.[Close] > s.MovingAverage10d 
				and d.[Close] < 3
				and a.MedianPriceChangePerc >  1
			) as x

			select
				distinct
				ASXCode,
				DisplayOrder
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
