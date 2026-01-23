-- Stored procedure: [Report].[usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh]


CREATE PROCEDURE [Report].[usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh.sql
Stored Procedure Name: usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh
Overview
-----------------
usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh

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
Date:		2020-07-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh'
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
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtNextDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 1, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select * 
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDate
		and DateTo is null

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
			d.MedianPriceChangePerc
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
		and cast(a.CreateDate as date) <=  cast(Common.DateAddBusinessDay(-1 * 2, @dtObservationDate) as date)
		and b.AlertTypeName in
		(
			'Break Through',
			'Breakaway Gap',
			'Breakthrough Trading Range'
		)
		order by a.CreateDate desc

		if object_id(N'Tempdb.dbo.#TempNext1ObservationDate') is not null
			drop table #TempNext1ObservationDate

		select b.UniqueKey, min(a.ObservationDate) as Next1ObservationDate
		into #TempNext1ObservationDate
		from StockData.PriceHistory as a
		inner join #TempAlertHistory as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate > b.ObservationDate
		group by b.UniqueKey

		if @pbitASXCodeOnly = 0
		begin
			select distinct
				a.ObservationDate as BreakThroughDate,
				'Break Through Previous Break Through High' as ReportType,
				a.ASXCode,
				d.ObservationDate as CurrDate,
				a.[High] as BTDayHigh,
				c.[High] as BTNextDayHigh,
				cast(a.[Value]/1000.0 as int) as BTDayValue,
				d.[Close] as CurrPrice,
				cast(d.[Value]/1000.0 as int) as CurrValue,
				a.[Close] as BTDayClose,
				c.[Close] as BTNextDayClose,
				ttsu.FriendlyNameList,
				cast(a.MedianTradeValue as int) as [MedianValue Wk],
				cast(a.MedianTradeValueDaily as int) as [MedianValue Day],
				cast(a.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
				case when ndp.[Open] > 0 and d.[Close] > 0 then cast((ndp.[Open] - d.[Close])*100.0/d.[Close] as decimal(20, 2)) else null end as NextDayOpenProfit,
				case when ndp.[Close] > 0 and d.[Close] > 0 then cast((ndp.[Close] - d.[Close])*100.0/d.[Close] as decimal(20, 2)) else null end as NextDayCloseProfit,
				a.AlertTypeName,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				o.NoBuy,
				p.NoSigNotice as NoSig,
				q.WeekMonthPositive as [WkMon+]
			from #TempAlertHistory as a
			inner join #TempNext1ObservationDate as b
			on a.UniqueKey = b.UniqueKey
			inner join StockData.PriceHistory as c
			on b.Next1ObservationDate = c.ObservationDate
			and a.ASXCode = c.ASXCode
			inner join #TempPriceSummary as d
			on a.ASXCode = d.ASXCode
			and d.[Close] > a.[High]
			and d.[Close] > c.[High]
			and c.[Close] <= a.[Close]
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.ObservationDate = cast(@dtObservationDate as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.ObservationDate = cast(@dtObservationDate as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtObservationDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtObservationDate as date)
			and n2.NetBuySell = 'S'
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
			left join
			(
				select ASXCode, count(ASXCode) as NoSensitiveNews
				from StockData.Announcement
				where cast(AnnDateTime as date) = @dtObservationDate
				and MarketSensitiveIndicator = 1
				group by ASXCode
			) as r
			on a.ASXCode = r.ASXCode
			left join #TempNextDayPrice as ndp
			on a.ASXCode = ndp.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where 1 = 1
			--and a.[Value] > 0.5 * MedianTradeValue*1000
			and not exists
			(
				select 1
				from StockData.PriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate < cast(Common.DateAddBusinessDay(0, @dtObservationDate) as date)
				and ObservationDate > b.Next1ObservationDate
				and [Close] > a.[High]
				and [Close] > c.[High]
			)
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
				select distinct
					a.ObservationDate as BreakThroughDate,
					'Break Through Previous Break Through High' as ReportType,
					a.ASXCode,
					d.ObservationDate as CurrDate,
					a.[High] as BTDayHigh,
					c.[High] as BTNextDayHigh,
					cast(a.[Value]/1000.0 as int) as BTDayValue,
					d.[Close] as CurrPrice,
					cast(d.[Value]/1000.0 as int) as CurrValue,
					a.[Close] as BTDayClose,
					c.[Close] as BTNextDayClose,
					cast(a.MedianTradeValue as int) as [MedianValue Wk],
					cast(a.MedianTradeValueDaily as int) as [MedianValue Day],
					cast(a.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
					a.AlertTypeName,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker,
					o.NoBuy,
					p.NoSigNotice as NoSig,
					q.WeekMonthPositive as [WkMon+]
				from #TempAlertHistory as a
				inner join #TempNext1ObservationDate as b
				on a.UniqueKey = b.UniqueKey
				inner join StockData.PriceHistory as c
				on b.Next1ObservationDate = c.ObservationDate
				and a.ASXCode = c.ASXCode
				inner join #TempPriceSummary as d
				on a.ASXCode = d.ASXCode
				and d.[Close] > a.[High]
				and d.[Close] > c.[High]
				and c.[Close] <= a.[Close]
				left join [Transform].[BrokerReportList] as m
				on a.ASXCode = m.ASXCode
				and m.LookBackNoDays = 0
				and m.ObservationDate = cast(@dtObservationDate as date)
				and m.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n
				on a.ASXCode = n.ASXCode
				and n.LookBackNoDays = 0
				and n.ObservationDate = cast(@dtObservationDate as date)
				and n.NetBuySell = 'S'
				left join [Transform].[BrokerReportList] as m2
				on a.ASXCode = m2.ASXCode
				and m2.LookBackNoDays = 10
				and m2.ObservationDate = cast(@dtObservationDate as date)
				and m2.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n2
				on a.ASXCode = n2.ASXCode
				and n2.LookBackNoDays = 10
				and n2.ObservationDate = cast(@dtObservationDate as date)
				and n2.NetBuySell = 'S'
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
				left join
				(
					select ASXCode, count(ASXCode) as NoSensitiveNews
					from StockData.Announcement
					where cast(AnnDateTime as date) = @dtObservationDate
					and MarketSensitiveIndicator = 1
					group by ASXCode
				) as r
				on a.ASXCode = r.ASXCode
				where 1 = 1
				--and a.[Value] > 0.5 * MedianTradeValue*1000
				and not exists
				(
					select 1
					from StockData.PriceHistory
					where ASXCode = a.ASXCode
					and ObservationDate < cast(Common.DateAddBusinessDay(0, @dtObservationDate) as date)
					and ObservationDate > b.Next1ObservationDate
					and [Close] > a.[High]
					and [Close] > c.[High]
				)
			) as x

			select
				distinct
				ASXCode,
				DisplayOrder,
				CurrDate as ObservationDate,
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
