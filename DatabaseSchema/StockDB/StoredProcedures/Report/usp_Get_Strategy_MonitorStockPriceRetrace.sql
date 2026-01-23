-- Stored procedure: [Report].[usp_Get_Strategy_MonitorStockPriceRetrace]



CREATE PROCEDURE [Report].[usp_Get_Strategy_MonitorStockPriceRetrace]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_monitorstockpriceretrace.sql
Stored Procedure Name: usp_Get_Strategy_monitorstockpriceretrace
Overview
-----------------
usp_Get_Strategy_monitorstockpriceretrace

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_monitorstockpriceretrace'
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
		--declare @pintNumPrevDay as int = 8

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate >= Common.DateAddBusinessDay(-10, @dtObservationDate)
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

		if object_id(N'Tempdb.dbo.#TempCandidate') is not null
			drop table #TempCandidate

		select distinct
			ASXCode,
			ObservationDate,
			[Close],
			[Open],
			[Low],
			[High],
			[Volume],
			cast(Volume*[Close]/1000.0 as int) as TodayValue,
			MovingAverage5d,
			MovingAverage10d,
			MovingAverage20d,
			MovingAverage60d,
			cast(MovingAverage120dVol*[Close] as int) as MovingAverage120dValue
		into #TempCandidate
		from [ScanResults].[StockStatsHistoryPlus]
		where ASXCode in
		(
			select ASXCode
			from [Alert].TradingAlert
			where TradingAlertTypeID = 7
		)
		and ObservationDate = @dtObservationDate

		if @pbitASXCodeOnly = 0
		begin
			select distinct
				'Breakout Retrace' as ReportType,			
				c.IndustrySubGroup as IndustrySubGroup,
				a.ASXCode, 
				a.ObservationDate as ObservationDate,
				a.[Close],
				a.MovingAverage5d,
				case when a.MovingAverage5d > 0 then cast(cast((a.[Close] - a.MovingAverage5d)*100.0/a.MovingAverage5d as decimal(20, 1)) as varchar(20)) + '%' else null end as VSMA5,
				a.MovingAverage10d,
				case when a.MovingAverage10d > 0 then cast(cast((a.[Close] - a.MovingAverage10d)*100.0/a.MovingAverage10d as decimal(20, 1)) as varchar(20)) + '%' else null end as VSA10,
				a.MovingAverage20d,
				case when a.MovingAverage20d > 0 then cast(cast((a.[Close] - a.MovingAverage20d)*100.0/a.MovingAverage20d as decimal(20, 1)) as varchar(20)) + '%' else null end as VSMA20,
				a.TodayValue,
				cast(j.MedianTradeValue as int) as [MedianValue Wk],
				cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
				cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
				cast(g.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
				cast(g.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
				ttsu.FriendlyNameList,
				cast(a.[Close]*c1.SharesIssued as decimal(10, 2)) as [M Cap],
				cast(case when c1.FloatingShares > 0 then a.[Volume]/(c1.FloatingShares*10000.0) else null end as decimal(10, 2)) as ChangeRate,
				--cast(g1.AvgVolume*1.0/(c1.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
				f.AnnDescr,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
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
				and cast(x.AnnDateTime as date) = @dtObservationDate
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
			and a.ObservationDate = @dtObservationDate
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
					'Breakout Retrace' as ReportType,			
					c.IndustrySubGroup as IndustrySubGroup,
					a.ASXCode, 
					a.ObservationDate as ObservationDate,
					a.[Close],
					a.MovingAverage5d,
					case when a.MovingAverage5d > 0 then cast(cast((a.[Close] - a.MovingAverage5d)*100.0/a.MovingAverage5d as decimal(20, 1)) as varchar(20)) + '%' else null end as VSMA5,
					a.MovingAverage10d,
					case when a.MovingAverage10d > 0 then cast(cast((a.[Close] - a.MovingAverage10d)*100.0/a.MovingAverage10d as decimal(20, 1)) as varchar(20)) + '%' else null end as VSA10,
					a.MovingAverage20d,
					case when a.MovingAverage20d > 0 then cast(cast((a.[Close] - a.MovingAverage20d)*100.0/a.MovingAverage20d as decimal(20, 1)) as varchar(20)) + '%' else null end as VSMA20,
					a.TodayValue,
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
					cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
					cast(g.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
					cast(g.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
					cast(a.[Close]*c1.SharesIssued as decimal(10, 2)) as [M Cap],
					cast(case when c1.FloatingShares > 0 then a.[Volume]/(c1.FloatingShares*10000.0) else null end as decimal(10, 2)) as ChangeRate,
					--cast(g1.AvgVolume*1.0/(c1.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
					f.AnnDescr,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker,
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
					and cast(x.AnnDateTime as date) = @dtObservationDate
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
				and a.ObservationDate = @dtObservationDate
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
