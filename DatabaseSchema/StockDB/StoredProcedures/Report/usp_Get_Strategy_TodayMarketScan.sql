-- Stored procedure: [Report].[usp_Get_Strategy_TodayMarketScan]


CREATE PROCEDURE [Report].[usp_Get_Strategy_TodayMarketScan]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0,
@bitFromPriceSummary as bit = 1
AS
/******************************************************************************
File: usp_Get_Strategy_TodayMarketScan.sql
Stored Procedure Name: usp_Get_Strategy_TodayMarketScan
Overview
-----------------
usp_Get_Strategy_TodayMarketScan

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
Date:		2021-08-23
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_TodayMarketScan'
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
		--declare @pbitASXCodeOnly as bit = 0
		--declare @bitFromPriceSummary as bit = 1

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		--declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 1, getdate()) as date)
		--declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -10, getdate()) as date)
		--declare @dtObservationDateNext1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 1, getdate()) as date)
		--declare @dtObservationDateNext3 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 3, getdate()) as date)
		--declare @dtObservationDateNext7 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 7, getdate()) as date)

		--select @dtObservationDate
		--select @dtObservationDatePrev1 
		--select @dtObservationDatePrevN 

		if object_id(N'Tempdb.dbo.#TempPriceSummaryLatest') is not null 
			drop table #TempPriceSummaryLatest

		select 
			*
		into #TempPriceSummaryLatest
		from StockData.v_PriceSummary
		where 1 != 1

		--declare @bitFromPriceSummary as bit = 0

		if @bitFromPriceSummary = 1
		begin
			insert into #TempPriceSummaryLatest
			select 
				*
			from StockData.v_PriceSummary
			where 1 = 1
			and ObservationDate = @dtObservationDate
			--and ASXCode = 'SYA.AX'
			and DateTo is null
			and LatestForTheDay = 1
			and [PrevClose] > 0
			and Volume > 0

		end
		else
		begin
			insert into #TempPriceSummaryLatest
			(
				PriceSummaryID,
				ASXCode,
				Bid,
				Offer,
				[Open],
				[High],
				[Low],
				[Close], 
				Volume,
				[Value],
				Trades,
				VWAP,
				ObservationDate,
				DateFrom
			)
			select
				-1 as PriceSummaryID,
				ASXCode,
				null as Bid,
				null as Offer,
				[Open],
				[High],
				[Low],
				[Close], 
				Volume,
				[Value],
				Trades,
				cast([Value]*1.0/Volume as decimal(20, 4)) as VWAP,
				ObservationDate,
				ObservationDate as DateFrom
			from StockData.v_PriceHistory
			where 1 = 1
			and ObservationDate = @dtObservationDate
			and Volume > 0
		end

		if object_id(N'Tempdb.dbo.#TempPriceSummaryLatest_DaySeq') is not null 
			drop table #TempPriceSummaryLatest_DaySeq

		select *, row_number() over (partition by ASXCode order by ObservationDate desc) - 1 as DaySeq 
		into #TempPriceSummaryLatest_DaySeq
		from #TempPriceSummaryLatest
		
		if object_id(N'Tempdb.dbo.#TempBrokerReportList') is not null
			drop table #TempBrokerReportList

		select *
		into #TempBrokerReportList
		from [Transform].[BrokerReportList]
		where LookBackNoDays = 0
		and ObservationDate = cast(@dtObservationDate as date)

		select distinct
			'Today Market Scan' as ReportType,
			null as [AnnDescr],
			a.ASXCode, 
			@dtObservationDate as ObservationDate,
			case when monitor.ASXCode is not null then 1 else 0 end as MonitorASXCode,
			--x.TodayChange,
			--x.TomorrowChange,
			--x.TomorrowOpenChange,
			m.BrokerCode as ObservationDateBuyBroker,
			n.BrokerCode as ObservationDateSellBroker,
			--m2.BrokerCode as RecentBuyBroker,
			--n2.BrokerCode as RecentSellBroker,
			--ttsu.FriendlyNameList,
			a.[Close] as CurrentClose,
			a.vwap,
			case when a.PrevClose > 0 then cast((a.[Close] - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end as PriceChange,
			case when a.vwap > 0 then cast((a.[Close] - a.vwap)*100.0/a.vwap as decimal(10, 2)) else null end as CloseVsVWAP,
			cast(a.[Value]/1000.0 as int) as [T/O in K],
			cast(j.MedianTradeValue as int) as [MedianValue Wk],
			cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
			cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
			case when f.FloatingShares > 0 then cast(a.Volume*1.0/(f.FloatingShares*10000) as decimal(20, 2)) else null end as [T/O Rate],
			a.[close],
			case when a.[High] - a.[Open] > 0 then cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) else null end as BarStrength
			--case when ndp.[Close] > 0 and a.[Close] > 0 then cast((ndp.[Close] - a.[Close])*100.0/a.[Close] as decimal(20, 2)) else null end as NextDayCloseProfit,
			--case when nd3p.[Close] > 0 and a.[Close] > 0 then cast((nd3p.[Close] - a.[Close])*100.0/a.[Close] as decimal(20, 2)) else null end as NextDay3CloseProfit,
			--case when nd7p.[Close] > 0 and a.[Close] > 0 then cast((nd7p.[Close] - a.[Close])*100.0/a.[Close] as decimal(20, 2)) else null end as NextDay7CloseProfit
		from 
		(
			select a.ASXCode, b.[Close], b.[Value], b.Volume, b.[Open], b.[High], b.[Low], b.VWAP, b.PrevClose
			from (
				select distinct ASXCode
				from StockData.MarketScan
				where ObservationDate = @dtObservationDate
			) as a
			left join #TempPriceSummaryLatest as b
			on a.ASXCode = b.ASXCode
			left join (
				select *
				from StockData.MonitorStock
				where MonitorTypeID in ('M', 'X')
				and isnull(PriorityLevel, 999) <= 999
			) as monitor
			on a.ASXCode = monitor.ASXCode
			where 1 = 1
		) as a
		left join StockData.v_CompanyFloatingShare as f
		on a.ASXCode = f.ASXCode
		left join StockData.MedianTradeValue as j
		on a.ASXCode = j.ASXCode
		left join #TempBrokerReportList as m
		on a.ASXCode = m.ASXCode
		and m.LookBackNoDays = 0
		and m.NetBuySell = 'B'
		left join #TempBrokerReportList as n
		on a.ASXCode = n.ASXCode
		and n.LookBackNoDays = 0
		and n.NetBuySell = 'S'
		left join #TempBrokerReportList as m2
		on a.ASXCode = m2.ASXCode
		and m2.LookBackNoDays = 10
		and m2.NetBuySell = 'B'
		left join #TempBrokerReportList as n2
		on a.ASXCode = n2.ASXCode
		and n2.LookBackNoDays = 10
		and n2.NetBuySell = 'S'
		left join Transform.TTSymbolUser as ttsu
		on a.ASXCode = ttsu.ASXCode
		left join (
			select *
			from StockData.MonitorStock
			where MonitorTypeID in ('M', 'X')
			and isnull(PriorityLevel, 999) <= 999
		) as monitor
		on a.ASXCode = monitor.ASXCode
		--left join StockData.v_PriceHistory as x
		--on a.ASXCode = x.ASXCode
		--and x.ObservationDate = @dtObservationDate
		where 1 = 1
		order by 
			case when a.vwap > 0 then cast((a.[Close] - a.vwap)*100.0/a.vwap as decimal(10, 2)) else null end desc,
			case when monitor.ASXCode is not null then 1 else 0 end desc,
			case when a.[High] - a.[Open] > 0 then cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) else null end desc, 
			case when f.FloatingShares > 0 then cast(a.Volume*1.0/(f.FloatingShares*10000) as decimal(20, 2)) else null end desc



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