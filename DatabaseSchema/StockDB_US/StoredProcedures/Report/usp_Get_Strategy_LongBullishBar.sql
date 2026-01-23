-- Stored procedure: [Report].[usp_Get_Strategy_LongBullishBar]


CREATE PROCEDURE [Report].[usp_Get_Strategy_LongBullishBar]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0
AS
/******************************************************************************
File: usp_Get_Strategy_LongBullishBar.sql
Stored Procedure Name: usp_Get_Strategy_LongBullishBar
Overview
-----------------
usp_Get_Strategy_LongBullishBar

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
Date:		2020-08-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_LongBullishBar'
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
		declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -1, getdate()) as date)

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

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate = @dtObservationDate
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

		if object_id(N'Tempdb.dbo.#TempAvgVolume') is not null
				drop table #TempAvgVolume

		select ASXCode, avg(Volume) as AvgVolume
		into #TempAvgVolume
		from StockData.PriceHistory
		where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -2, getdate()) as date)
		and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		group by ASXCode

		select distinct
			'Long Bullish Bar' as ReportType,			
			c.IndustrySubGroup as IndustrySubGroup,
			a.ASXCode, 
			@dtObservationDate as ObservationDate,
			cast((a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) as int) as BarStrength, 
			cast(cast((a.[Close] - a.[Open])*100.0/a.[Open] as decimal(10, 2)) as varchar(20)) + '%' as BarChg, 
			cast(a.[Value]/1000.0 as int) as [Value],
			cast(j.MedianTradeValue as int) as [MedianValue Wk],
			cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
			cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
			cast(g.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
			cast(g.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
			cast(a.[Close]*c1.SharesIssued as decimal(10, 2)) as [M Cap],
			cast(case when c1.FloatingShares > 0 then a.[Volume]/(c1.FloatingShares*10000.0) else null end as decimal(10, 2)) as ChangeRate,
			cast(g1.AvgVolume*1.0/(c1.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
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
			--case when NoBuy >= 2 and p.NoSigNotice >= 2 and q.WeekMonthPositive >= 1 then 10
			--	 when NoBuy >= 1 and p.NoSigNotice >= 2 and q.WeekMonthPositive >= 1 then 20
			--	 when NoBuy >= 1 and p.NoSigNotice >= 1 and q.WeekMonthPositive >= 1 then 30
			--	 when NoBuy >= 2 and q.WeekMonthPositive >= 1 then 40
			--	 when NoBuy >= 1 and q.WeekMonthPositive >= 1 then 50
			--	 when p.NoSigNotice >= 1 and q.WeekMonthPositive >= 1 then 60
			--	 when p.NoSigNotice >= 1 and q.WeekMonthPositive >= 1 then 60
			--end
		from #TempPriceSummary as a
		inner join #TempPriceSummaryPrev1 as b
		on a.ASXCode = b.ASXCode
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
				ASXCode,
				AnnDescr,
				AnnDateTime,
				stuff((
				select ',' + [SearchTerm]
				from StockData.AnnouncementAlert as a
				where x.AnnouncementID = a.AnnouncementID
				order by CreateDate desc
				for xml path('')), 1, 1, ''
				) as [SearchTerm],
				row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
			from StockData.Announcement as x
			where cast(AnnDateTime as date) = @dtObservationDate			
		) as f
		on a.ASXCode = f.ASXCode
		and f.RowNumber = 1
		left join StockData.RetailParticipation as g
		on a.ASXCode = g.ASXCode
		left join #TempAvgVolume as g1
		on a.ASXCode = g1.ASXCode
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
		where a.DateTo is null
		and (a.Volume > 2*b.Volume or a.[Value]/1000.0 > 2*isnull(j.MedianTradeValueDaily, 99999999))
		and a.[Value] > 150000
		and 
		(
			cast((a.[Close] - a.[Open])*100.0/a.[Open] as decimal(10, 2)) > 4.0
			or
			cast((a.[Close] - a.[PrevClose])*100.0/a.[PrevClose] as decimal(10, 2)) > 4.0
		)
		and a.[High] > a.[Open]
		and (a.[Close] - a.[Open])*100.0/(a.[High] - a.[Open]) >= 75
		order by BarStrength desc, [MedianPriceChg] desc


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
