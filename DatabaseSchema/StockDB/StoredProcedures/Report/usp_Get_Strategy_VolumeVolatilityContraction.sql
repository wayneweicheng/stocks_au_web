-- Stored procedure: [Report].[usp_Get_Strategy_VolumeVolatilityContraction]


CREATE PROCEDURE [Report].[usp_Get_Strategy_VolumeVolatilityContraction]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_VolumeVolatilityContraction.sql
Stored Procedure Name: usp_Get_Strategy_VolumeVolatilityContraction
Overview
-----------------
usp_Get_Strategy_VolumeVolatilityContraction

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
Date:		2020-11-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_VolumeVolatilityContraction'
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
		--declare @pintNumPrevDay as int = 11

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -1, getdate()) as date)
		declare @dtObservationDatePrev60Day as date = cast(Common.DateAddBusinessDay(-1 * 60, @dtObservationDate) as date)

		if object_id(N'Tempdb.dbo.#TempPriceHistoryPre') is not null 
			drop table #TempPriceHistoryPre

		select 
			ASXCode,
			[Open],
			[High],
			[Low],
			[Close],
			[Value],
			Volume,
			ObservationDate,
			Spread,
			PriceChangeVsOpen,
			PriceChangeVsPrevClose
		into #TempPriceHistoryPre
		from Transform.v_PriceHistory
		where 1 = 1
		and ObservationDate <= @dtObservationDate
		and ObservationDate >= @dtObservationDatePrev60Day
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null 
			drop table #TempPriceHistory

		select 
			*, 
			lead([Volume], 1) over (partition by ASXCode order by ObservationDate desc) as Prev1Volume,
			lead([Volume], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Volume,
			lead([Volume], 3) over (partition by ASXCode order by ObservationDate desc) as Prev3Volume,
			lead([Volume], 4) over (partition by ASXCode order by ObservationDate desc) as Prev4Volume,
			lead([Volume], 5) over (partition by ASXCode order by ObservationDate desc) as Prev5Volume,
			lead([Volume], 6) over (partition by ASXCode order by ObservationDate desc) as Prev6Volume,
			lead([Volume], 7) over (partition by ASXCode order by ObservationDate desc) as Prev7Volume,
			lead([Volume], 8) over (partition by ASXCode order by ObservationDate desc) as Prev8Volume,
			lead([ObservationDate], 1) over (partition by ASXCode order by ObservationDate desc) as Prev1ObservationDate,
			lead([ObservationDate], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2ObservationDate,
			lead([ObservationDate], 3) over (partition by ASXCode order by ObservationDate desc) as Prev3ObservationDate,
			lead([ObservationDate], 4) over (partition by ASXCode order by ObservationDate desc) as Prev4ObservationDate,
			lead([ObservationDate], 5) over (partition by ASXCode order by ObservationDate desc) as Prev5ObservationDate,
			lead([ObservationDate], 6) over (partition by ASXCode order by ObservationDate desc) as Prev6ObservationDate,
			lead([ObservationDate], 7) over (partition by ASXCode order by ObservationDate desc) as Prev7ObservationDate,
			lead([ObservationDate], 8) over (partition by ASXCode order by ObservationDate desc) as Prev8ObservationDate,
			stdev([Spread]) over (partition by ASXCode order by ObservationDate asc rows 5 preceding) as SpreadLastNDStd,
			avg([Spread]) over (partition by ASXCode order by ObservationDate asc rows 5 preceding) as SpreadLastNDAvg,
			avg([Spread]) over (partition by ASXCode order by ObservationDate asc rows 5 preceding) - stdev([Spread]) over (partition by ASXCode order by ObservationDate asc rows 5 preceding) as SpreadLastNDAvgMinusStd,
			stdev(abs(PriceChangeVsPrevClose)) over (partition by ASXCode order by ObservationDate asc rows 20 preceding) as PriceChangeVsPrevCloseLastNDStd,
			avg(abs(PriceChangeVsPrevClose)) over (partition by ASXCode order by ObservationDate asc rows 20 preceding) as PriceChangeVsPrevCloseLastNDAvg,
			avg(abs(PriceChangeVsPrevClose)) over (partition by ASXCode order by ObservationDate asc rows 20 preceding) + stdev(abs(PriceChangeVsPrevClose)) over (partition by ASXCode order by ObservationDate asc rows 5 preceding) as PriceChangeVsPrevCloseLastNDAvgPlusStd,
			stdev([Volume]) over (partition by ASXCode order by ObservationDate asc rows 20 preceding) as VolumeLastNDStd,
			avg([Volume]) over (partition by ASXCode order by ObservationDate asc rows 20 preceding) as VolumeLastNDAvg,
			avg([Volume]) over (partition by ASXCode order by ObservationDate asc rows 20 preceding) + 2*stdev([Volume]) over (partition by ASXCode order by ObservationDate asc rows 5 preceding) as VolumeLastNDAvgPlus2Std
		into #TempPriceHistory
		from #TempPriceHistoryPre
		
		if object_id(N'Tempdb.dbo.#TempCandidate') is not null
			drop table #TempCandidate

		select 
			a.ASXCode,
			a.ObservationDate as ObservationDate,
			b.ObservationDate as BreakOutDate, 
			b.PriceChangeVsPrevClose as BreakOutPriceChange, 
			b.PriceChangeVsPrevCloseLastNDAvgPlusStd, 
			b.Volume as BreakOutVolume,
			b.[Value] as BreakOutValue,
			b.[Open] as BreakOutOpen,
			b.[Close] as BreakOutClose,
			b.[High] as BreakOutHigh,
			b.[Low] as BreakOutLow,
			a.Volume as ObservationDateVolume,
			a.[Value] as ObservationDateValue,
			a.[Close] as ObservationDateClose,
			a.PriceChangeVsPrevClose as ObservationDatePriceChange
		into #TempCandidate
		from #TempPriceHistory as a
		inner join #TempPriceHistory as b
		on a.ASXCode = b.ASXCode
		where a.Spread <= a.SpreadLastNDAvg
		and a.Volume < a.Prev1Volume
		and a.Prev1Volume < a.Prev2Volume
		--and a.ASXCode = 'LCL.AX'
		and b.PriceChangeVsPrevClose > b.PriceChangeVsPrevCloseLastNDAvgPlusStd 
		and b.Volume > b.VolumeLastNDAvgPlus2Std
		and a.[Close] >= b.[Low]
		and b.PriceChangeVsPrevClose < 50
		and
		(
			a.Prev1ObservationDate = b.ObservationDate or 
			a.Prev2ObservationDate = b.ObservationDate or 
			a.Prev3ObservationDate = b.ObservationDate or 
			a.Prev4ObservationDate = b.ObservationDate or 
			a.Prev5ObservationDate = b.ObservationDate or 
			a.Prev6ObservationDate = b.ObservationDate or 			
			a.Prev7ObservationDate = b.ObservationDate or 
			a.Prev8ObservationDate = b.ObservationDate 
		)
		order by a.ObservationDate desc;

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate >= Common.DateAddBusinessDay(-20, @dtObservationDate)
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

		--if object_id(N'Tempdb.dbo.#TempAvgVolume') is not null
		--		drop table #TempAvgVolume

		--select ASXCode, avg(Volume) as AvgVolume
		--into #TempAvgVolume
		--from StockData.PriceHistory
		--where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -2, getdate()) as date)
		--and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		--group by ASXCode

		if @pbitASXCodeOnly = 0
		begin
			select distinct
				'Volume Volatility Contraction' as ReportType,			
				c.IndustrySubGroup as IndustrySubGroup,
				a.ASXCode, 
				a.ObservationDate as ObservationDate,
				a.BreakOutDate as BreakOutDate,
				Common.BusinessDayDiff(BreakOutDate, a.ObservationDate) as DaysSinceBreakOut,
				cast((a.[BreakOutClose] - a.[BreakOutOpen])*100.0/(a.[BreakOutHigh] - a.[BreakOutOpen]) as int) as BreakOutBarStrength, 
				a.BreakOutPriceChange as BreakOutPriceChange,
				--cast(cast((a.[Close] - a.[Open])*100.0/a.[Open] as decimal(10, 2)) as varchar(20)) + '%' as BarChg, 
				cast(a.[BreakOutValue]/1000.0 as int) as [Value],
				cast(j.MedianTradeValue as int) as [MedianValue Wk],
				cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
				cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
				cast(g.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
				cast(g.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
				cast(a.[ObservationDateClose]*c1.SharesIssued as decimal(10, 2)) as [M Cap],
				cast(case when c1.FloatingShares > 0 then a.[BreakOutVolume]/(c1.FloatingShares*10000.0) else null end as decimal(10, 2)) as ChangeRate,
				--cast(g1.AvgVolume*1.0/(c1.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
				f.AnnDescr,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				ttsu.FriendlyNameList,
				case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
				case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
				o.NoBuy,
				p.NoSigNotice as NoSig,
				q.WeekMonthPositive as [WkMon+],
				r.NoSensitiveNews as NoSensNews,
				case when isnull(NoBuy, 0) >= 2 then 10 when isnull(NoBuy, 0) >= 1 and isnull(NoBuy, 0) < 2 then 8 else 0 end + 
				case when isnull(NoSigNotice, 0) >= 1 then 5 else 0 end + 
				case when isnull(WeekMonthPositive, 0) >= 1 then 10 else 0 end + 
				case when isnull(r.NoSensitiveNews, 0) >= 1 then -10 else 0 end
				as Score			
			from #TempCandidate as a
			left join StockData.CompanyInfo as c
			on a.ASXCode = c.ASXCode
			left join StockData.v_CompanyFloatingShare as c1
			on a.ASXCode = c1.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue, MedianTradeValueDaily, MedianPriceChangePerc 
				from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join (
				select 
					AnnouncementID,
					x.ASXCode,
					AnnDescr,
					AnnDateTime,
					stuff((
					select ',' + [SearchTerm]
					from StockData.AnnouncementAlert as a
					where x.AnnouncementID = a.AnnouncementID
					order by CreateDate desc
					for xml path('')), 1, 1, ''
					) as [SearchTerm],
					row_number() over (partition by x.ASXCode order by AnnDateTime asc) as RowNumber
				from StockData.Announcement as x
				inner join #TempCandidate as y
				on x.ASXCode = y.ASXCode
				and cast(x.AnnDateTime as date) = y.BreakOutDate
			) as f
			on a.ASXCode = f.ASXCode
			and f.RowNumber = 1
			left join StockData.RetailParticipation as g
			on a.ASXCode = g.ASXCode
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
			left join
			(
				select ASXCode, count(ASXCode) as NoSensitiveNews
				from StockData.Announcement
				where cast(AnnDateTime as date) = @dtObservationDate
				and MarketSensitiveIndicator = 1
				group by ASXCode
			) as r
			on a.ASXCode = r.ASXCode
			left join ScanResults.StockStatsHistoryPlusCurrent as s
			on a.ASXCode = s.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where 1 = 1
			and (a.[BreakOutHigh] - a.[BreakOutOpen]) > 0
			and a.ObservationDate = @dtObservationDate
			order by cast((a.[BreakOutClose] - a.[BreakOutOpen])*100.0/(a.[BreakOutHigh] - a.[BreakOutOpen]) as int) desc, Common.BusinessDayDiff(BreakOutDate, a.ObservationDate), [MedianPriceChg] desc
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
					'Volume Volatility Contraction' as ReportType,			
					c.IndustrySubGroup as IndustrySubGroup,
					a.ASXCode, 
					a.ObservationDate as ObservationDate,
					a.BreakOutDate as BreakOutDate,
					Common.BusinessDayDiff(BreakOutDate, a.ObservationDate) as DaysSinceBreakOut,
					cast((a.[BreakOutClose] - a.[BreakOutOpen])*100.0/(a.[BreakOutHigh] - a.[BreakOutOpen]) as int) as BreakOutBarStrength, 
					a.BreakOutPriceChange as BreakOutPriceChange,
					--cast(cast((a.[Close] - a.[Open])*100.0/a.[Open] as decimal(10, 2)) as varchar(20)) + '%' as BarChg, 
					cast(a.[BreakOutValue]/1000.0 as int) as [Value],
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
					cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
					cast(g.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
					cast(g.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
					cast(a.[ObservationDateClose]*c1.SharesIssued as decimal(10, 2)) as [M Cap],
					cast(case when c1.FloatingShares > 0 then a.[BreakOutVolume]/(c1.FloatingShares*10000.0) else null end as decimal(10, 2)) as ChangeRate,
					--cast(g1.AvgVolume*1.0/(c1.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
					f.AnnDescr,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker,
					case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
					case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
					o.NoBuy,
					p.NoSigNotice as NoSig,
					q.WeekMonthPositive as [WkMon+],
					r.NoSensitiveNews as NoSensNews,
					case when isnull(NoBuy, 0) >= 2 then 10 when isnull(NoBuy, 0) >= 1 and isnull(NoBuy, 0) < 2 then 8 else 0 end + 
					case when isnull(NoSigNotice, 0) >= 1 then 5 else 0 end + 
					case when isnull(WeekMonthPositive, 0) >= 1 then 10 else 0 end + 
					case when isnull(r.NoSensitiveNews, 0) >= 1 then -10 else 0 end
					as Score			
				from #TempCandidate as a
				left join StockData.CompanyInfo as c
				on a.ASXCode = c.ASXCode
				left join StockData.v_CompanyFloatingShare as c1
				on a.ASXCode = c1.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue, MedianTradeValueDaily, MedianPriceChangePerc 
					from StockData.MedianTradeValue
				) as j
				on a.ASXCode = j.ASXCode
				left join (
					select 
						AnnouncementID,
						x.ASXCode,
						AnnDescr,
						AnnDateTime,
						stuff((
						select ',' + [SearchTerm]
						from StockData.AnnouncementAlert as a
						where x.AnnouncementID = a.AnnouncementID
						order by CreateDate desc
						for xml path('')), 1, 1, ''
						) as [SearchTerm],
						row_number() over (partition by x.ASXCode order by AnnDateTime asc) as RowNumber
					from StockData.Announcement as x
					inner join #TempCandidate as y
					on x.ASXCode = y.ASXCode
					and cast(x.AnnDateTime as date) = y.BreakOutDate
				) as f
				on a.ASXCode = f.ASXCode
				and f.RowNumber = 1
				left join StockData.RetailParticipation as g
				on a.ASXCode = g.ASXCode
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
				left join
				(
					select ASXCode, count(ASXCode) as NoSensitiveNews
					from StockData.Announcement
					where cast(AnnDateTime as date) = @dtObservationDate
					and MarketSensitiveIndicator = 1
					group by ASXCode
				) as r
				on a.ASXCode = r.ASXCode
				left join ScanResults.StockStatsHistoryPlusCurrent as s
				on a.ASXCode = s.ASXCode
				where 1 = 1
				and (a.[BreakOutHigh] - a.[BreakOutOpen]) > 0
				and a.ObservationDate = @dtObservationDate
			) as x
			order by BreakOutBarStrength desc, Common.BusinessDayDiff(BreakOutDate, ObservationDate), [MedianPriceChg] desc

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
