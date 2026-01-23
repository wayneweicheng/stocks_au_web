-- Stored procedure: [Report].[usp_Get_Strategy_AdvancedFRCS]


CREATE PROCEDURE [Report].[usp_Get_Strategy_AdvancedFRCS]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_AdvancedFRCS.sql
Stored Procedure Name: usp_Get_Strategy_AdvancedFRCS
Overview
-----------------
usp_Get_Strategy_AdvancedFRCS

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
Date:		2021-03-23
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_AdvancedFRCS'
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
		--declare @pintNumPrevDay as int = 0

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 1, getdate()) as date)
		declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -30, getdate()) as date)

		--select @dtObservationDate
		--select @dtObservationDatePrev1 
		--select @dtObservationDatePrevN 

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null 
			drop table #TempPriceSummary

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDate
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempPriceSummaryPrev1') is not null 
			drop table #TempPriceSummaryPrev1

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummaryPrev1
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDatePrev1
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempStockStatsHistoryPlus') is not null 
			drop table #TempStockStatsHistoryPlus

		select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
		into #TempStockStatsHistoryPlus
		from StockData.StockStatsHistoryPlus
		where ObservationDate >= @dtObservationDatePrevN
		and ObservationDate < @dtObservationDate
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempABSMADifference5d') is not null 
			drop table #TempABSMADifference5d

		select ASXCode, sum(abs(MovingAverage10d - MovingAverage5d)) as ABSMADifference5d
		into #TempABSMADifference5d
		from #TempStockStatsHistoryPlus
		where RowNumber < = 5
		group by ASXCode

		if object_id(N'Tempdb.dbo.#TempABSMADifference3d') is not null 
			drop table #TempABSMADifference3d

		select ASXCode, sum(abs(MovingAverage10d - MovingAverage5d)) as ABSMADifference3d
		into #TempABSMADifference3d
		from #TempStockStatsHistoryPlus
		where RowNumber < = 3
		group by ASXCode

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

		if @pbitASXCodeOnly = 0
		begin
			select 
				'Advanced FRCS' as ReportType,
				a.Volume,
				a.ASXCode, 
				a.ObservationDate,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				ttsu.FriendlyNameList,
				cast(coalesce(f.SharesIssued*a.[Close]*1.0, g.MC) as decimal(8, 2)) as MC,
				cast(g.CashPosition as decimal(8, 2)) CashPosition,
				a.[Close] as CurrentClose,
				cast(a.[Value]/1000.0 as int) as [T/O in K],
				cast(j.MedianTradeValue as int) as [MedianValue Wk],
				cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
				cast(b.ABSMADifference5d/[Common].[GetPriceTick](a.[Close]) as decimal(10, 2)) as NumTicks5Days, 
				cast(c.ABSMADifference3d/[Common].[GetPriceTick](a.[Close]) as decimal(10, 2)) as NumTicks3Days,
				cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) as BarStrength
			from #TempPriceSummary as a
			left join #TempABSMADifference5d as b
			on a.ASXCode = b.ASXCode
			and b.ABSMADifference5d < 5 * [Common].[GetPriceTick](a.[Close])
			left join #TempABSMADifference3d as c
			on a.ASXCode = c.ASXCode
			and c.ABSMADifference3d < 3 * [Common].[GetPriceTick](a.[Close])
			left join #TempStockStatsHistoryPlus as d
			on a.ASXCode = d.ASXCode
			and a.[Close] > d.[Close]
			and d.RowNumber = 1
			and a.Volume > d.Volume
			and a.[Close] > d.MovingAverage5d
			and a.[Close] > d.MovingAverage10d
			left join #TempStockStatsHistoryPlus as e
			on a.ASXCode = e.ASXCode
			and a.[Close] > e.[Close]
			and e.RowNumber = 2
			and a.Volume > e.Volume
			and a.[Close] > e.MovingAverage5d
			and a.[Close] > e.MovingAverage10d
			left join StockData.v_CompanyFloatingShare as f
			on a.ASXCode = f.ASXCode
			left join #TempCashVsMC as g
			on a.ASXCode = g.ASXCode
			left join StockData.MedianTradeValue as j
			on a.ASXCode = j.ASXCode
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
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where (b.ASXcode is not null or c.ASXCode is not null)
			and c.ASXCode is not null
			and d.ASXCode is not null
			and e.ASXCode is not null
			--and a.ASXCode = 'SCU.AX'
			and a.[Close] > d.MovingAverage30d
			and a.[Close] > d.MovingAverage60d
			and a.[Value] > 100000 
			and a.[High] - a.[Open] > 0
			and case when a.[High] - a.[Open] <= 3*[Common].[GetPriceTick](a.[Close]) and cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) >= 66 then 1
					 when a.[High] - a.[Open] > 3*[Common].[GetPriceTick](a.[Close]) and cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) >= 75 then 1
			    end = 1
			order by cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) desc
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
					'Advanced FRCS' as ReportType,
					a.Volume,
					a.ASXCode, 
					a.ObservationDate,
					m2.BrokerCode as RecentTopBuyBroker,
					n2.BrokerCode as RecentTopSellBroker,
					cast(coalesce(f.SharesIssued*a.[Close]*1.0, g.MC) as decimal(8, 2)) as MC,
					cast(g.CashPosition as decimal(8, 2)) CashPosition,
					a.[Close] as CurrentClose,
					cast(a.[Value]/1000.0 as int) as [T/O in K],
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
					cast(b.ABSMADifference5d/[Common].[GetPriceTick](a.[Close]) as decimal(10, 2)) as NumTicks5Days, 
					cast(c.ABSMADifference3d/[Common].[GetPriceTick](a.[Close]) as decimal(10, 2)) as NumTicks3Days,
					cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) as BarStrength,
					ttsu.FriendlyNameList
				from #TempPriceSummary as a
				left join #TempABSMADifference5d as b
				on a.ASXCode = b.ASXCode
				and b.ABSMADifference5d < 5 * [Common].[GetPriceTick](a.[Close])
				left join #TempABSMADifference3d as c
				on a.ASXCode = c.ASXCode
				and c.ABSMADifference3d < 3 * [Common].[GetPriceTick](a.[Close])
				left join #TempStockStatsHistoryPlus as d
				on a.ASXCode = d.ASXCode
				and a.[Close] > d.[Close]
				and d.RowNumber = 1
				and a.Volume > d.Volume
				and a.[Close] > d.MovingAverage5d
				and a.[Close] > d.MovingAverage10d
				left join #TempStockStatsHistoryPlus as e
				on a.ASXCode = e.ASXCode
				and a.[Close] > e.[Close]
				and e.RowNumber = 2
				and a.Volume > e.Volume
				and a.[Close] > e.MovingAverage5d
				and a.[Close] > e.MovingAverage10d
				left join StockData.v_CompanyFloatingShare as f
				on a.ASXCode = f.ASXCode
				left join #TempCashVsMC as g
				on a.ASXCode = g.ASXCode
				left join StockData.MedianTradeValue as j
				on a.ASXCode = j.ASXCode
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
				left join Transform.TTSymbolUser as ttsu
				on a.ASXCode = ttsu.ASXCode
				where (b.ASXcode is not null or c.ASXCode is not null)
				and c.ASXCode is not null
				and d.ASXCode is not null
				and e.ASXCode is not null
				--and a.ASXCode = 'SCU.AX'
				and a.[Close] > d.MovingAverage30d
				and a.[Close] > d.MovingAverage60d
				and a.[Value] > 100000 
				and a.[High] - a.[Open] > 0
				and case when a.[High] - a.[Open] <= 3*[Common].[GetPriceTick](a.[Close]) and cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) >= 66 then 1
						 when a.[High] - a.[Open] > 3*[Common].[GetPriceTick](a.[Close]) and cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) >= 75 then 1
					end = 1
			) as x
			order by ASXCode desc;
			
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