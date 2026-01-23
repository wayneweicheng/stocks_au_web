-- Stored procedure: [Report].[usp_GetMostTradedMidLargeCap]



CREATE PROCEDURE [Report].[usp_GetMostTradedMidLargeCap]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_GetMostTradedSmallCap.sql
Stored Procedure Name: usp_GetMostTradedSmallCap
Overview
-----------------
usp_GetMostTradedSmallCap

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
Date:		2021-10-31
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMostTradedMidLargeCap'
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
		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtNextDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 1, getdate()) as date)
		declare @dtPrevDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 1, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition with(nolock)
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
		right join StockData.CompanyInfo as b with(nolock)
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempAnnouncement') is not null
			drop table #TempAnnouncement

		select 
			ASXCode,
			AnnDescr,
			AnnDateTime,
			row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
		into #TempAnnouncement
		from Transform.v_Announcement as x with(nolock)
		where cast(AnnDateTime as date) = @dtDate

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select * 
		into #TempPriceSummary
		from StockData.v_PriceSummary with(nolock)
		where ObservationDate = @dtDate
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

		insert into #TempPriceSummary
		(
			PriceSummaryID,
			ASXCode,
			[Open],
			[High],
			[Low],
			[Close],
			[PrevClose],
			[Volume],
			[Value],
			[VWAP],
			[Trades],
			DateFrom,
			ObservationDate
		)
		select 
			-1 as PriceSummaryID,
			ASXCode,
			[Open],
			[High],
			[Low],
			[Close],
			[PrevClose],
			[Volume],
			[Value],
			[VWAP],
			[Trades],
			ObservationDate,
			ObservationDate
		from Transform.PriceHistory as a with(nolock)
		where not exists
		(
			select 1
			from #TempPriceSummary
			where ASXCode = a.ASXCode
		)
		and ObservationDate = @dtDate
		and Volume > 0;

		if object_id(N'Tempdb.dbo.#TempNextDayPrice') is not null
			drop table #TempNextDayPrice

		select * 
		into #TempNextDayPrice
		from StockData.PriceHistory with(nolock)
		where ObservationDate = @dtNextDate

		if object_id(N'Tempdb.dbo.#TempPrevDayPrice') is not null
			drop table #TempPrevDayPrice

		select * 
		into #TempPrevDayPrice
		from Transform.PriceHistory with(nolock)
		where ObservationDate = @dtPrevDate

		if object_id(N'Tempdb.dbo.#TempAlertHistory') is not null
			drop table #TempAlertHistory

		select 
			b.AlertTypeName,
			a.ASXCode,
			a.CreateDate,
			case when b.AlertTypeName in ('Breakaway Gap') then 40 
				 when b.AlertTypeName in ('Break Through') then 30 
				 when b.AlertTypeName in ('Gain Momentum', 'Breakthrough Trading Range') then 15
				 else 10
			end as AlertTypeScore
		into #TempAlertHistory
		from 
		(
			select AlertTypeID, ASXCode, CreateDate
			from Stock.ASXAlertHistory with(nolock)
			group by AlertTypeID, ASXCode, CreateDate
		) as a
		inner join LookupRef.AlertType as b
		on a.AlertTypeID = b.AlertTypeID
		where cast(a.CreateDate as date) = @dtDate
		order by a.CreateDate desc

		if object_id(N'Tempdb.dbo.#TempAlertHistoryAggregate') is not null
			drop table #TempAlertHistoryAggregate

		select 
			x1.ASXCode,
			x1.AlertTypeName,
			x1.CreateDate,
			y.AlertTypeScore
		into #TempAlertHistoryAggregate
		from
		(
			select 
				x.ASXCode,
				x.CreateDate,
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

		if object_id(N'Tempdb.dbo.#TempHighVolumeMidLargeCap') is not null
			drop table #TempHighVolumeMidLargeCap
		select top 100 c.MC, a.ASXCode, a.MedianTradeValue, a.MedianTradeValueDaily, a.MedianPriceChangePerc 
		into #TempHighVolumeSmallCap
		from StockData.MedianTradeValue as a
		inner join StockData.PriceHistoryCurrent as b
		on a.ASXCode = b.ASXCode
		inner join StockData.v_CompanyFloatingShare as c
		on a.ASXCode = c.ASXCode
		where MedianPriceChangePerc > 1
		and c.MC >= 4000
		--and [Close] < 1
		--order by MedianTradeValue desc;
		order by MedianTradeValueDaily desc;

		select top 500
			'Most Traded SmallCap' as ReportType,
			left(cast(cast(getdate() as time) as varchar(50)), 8) as RefreshTime,
			a.ASXCode,
			h.ObservationDate,
			case when h.Volume > 0 then h.[Close] else h.IndicativePrice end as [Close],
			h.SurplusVolume,
			h.Bid,
			h.Offer as Ask,
			case when h.PrevClose >  0 and case when h.Volume > 0 then h.[Close] else h.IndicativePrice end > 0 then cast((case when h.Volume > 0 then h.[Close] else h.IndicativePrice end - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end as [ChangePerc],
			case when h.PrevClose >  0 and h.[Open] > 0 then cast((h.[Open] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end as OpenChangePerc,
			case when h.[High] - h.[Low] > 0 then cast((h.[Close] - h.[Low])*100.0/(h.[High] - h.[Low]) as int) else null end as BarStrength,
			g.[AnnDescr],
			ttsu.FriendlyNameList,
			cast(coalesce(b.SharesIssued*h.[Close]*1.0, c.MC) as decimal(8, 2)) as MC,
			cast(c.CashPosition as decimal(8, 2)) CashPosition,
			cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as [T/O Rate],
			cast(h.[Value]/1000.0 as int) as [T/O in K],
			--cast(j.MedianTradeValue as int) as [MedianValue Wk],
			--cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
			--cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
			--case when h.[Close] > 0 then cast(pdp.PriceChangeVsPrevClose as decimal(20, 2)) else null end as PrevDayChangePerc,
			m.BrokerCode as ObservationDayTopBuyBroker,
			n.BrokerCode as ObservationDayTopSellBroker,
			m2.BrokerCode as RecentTopBuyBroker,
			n2.BrokerCode as RecentTopSellBroker,
			--case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
			--case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
			dibs.InstituteTradeValue as InstTradeValue,
			dibs.InstituteTradeValuePerc as [InstTradeValue%],
			dibs.AvgTradeValuePerc,
			format(dibs.InstituteBuyPerc, 'N1') as [InstBuy%],
			format(dibs.RetailBuyPerc, 'N1') as [RetailBuy%],
			dibs.InstituteBuyVWAP as InstBuyVWAP,
			dibs.RetailBuyVWAP as RetailBuyVWAP,
			h.MatchVolume,
			h.SurplusVolume,
			--cast(d.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
			--cast(d.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
			case when h.[Close] > plfm.MovingAverage100D and h.[Close] > plfm.MovingAverage50D then 1 else 0 end as AboveLongMA,
			case when plfm.MovingAverage100D >= plfm2.MovingAverage100D and plfm.MovingAverage50D >= plfm2.MovingAverage50D then 1 else 0 end TrendUpLongMA,
			e.IndustrySubGroup,
			a.notes as Notes
		from (
			select 
				a.[ASXCode],
				substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
				null as Notes,
				MedianTradeValueDaily
			from #TempHighVolumeSmallCap as a
		) as a
		left join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode
		left join #TempCashVsMC as c
		on a.ASXCode = c.ASXCode
		--left join StockData.RetailParticipation as d
		--on a.ASXCode = d.ASXCode
		left join StockData.CompanyInfo as e with(nolock)
		on a.ASXCode = e.ASXCode
		left join #TempAnnouncement as g
		on a.ASXCode = g.ASXCode
		and g.RowNumber = 1
		left join #TempPriceSummary as h
		on a.ASXCode = h.ASXCode
		left join Transform.PosterList as i
		on a.ASXCode = i.ASXCode
		--left join StockData.MedianTradeValue as j
		--on a.ASXCode = j.ASXCode
		--left join StockData.StockStatsHistoryPlusCurrent as l
		--on a.ASXCode = l.ASXCode
		left join [Transform].[BrokerReportList] as m
		on a.ASXCode = m.ASXCode
		and m.LookBackNoDays = 0
		and m.ObservationDate = @dtDate
		and m.NetBuySell = 'B'
		left join [Transform].[BrokerReportList] as n
		on a.ASXCode = n.ASXCode
		and n.LookBackNoDays = 0
		and n.ObservationDate = @dtDate
		and n.NetBuySell = 'S'
		left join [Transform].[BrokerReportList] as m2
		on a.ASXCode = m2.ASXCode
		and m2.LookBackNoDays = 10
		and m2.ObservationDate = @dtDate
		and m2.NetBuySell = 'B'
		left join [Transform].[BrokerReportList] as n2
		on a.ASXCode = n2.ASXCode
		and n2.LookBackNoDays = 10
		and n2.ObservationDate = @dtDate
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
			select ASXCode, count(ASXCode) as NoSensitiveNews
			from StockData.Announcement
			where cast(AnnDateTime as date) = @dtDate
			and MarketSensitiveIndicator = 1
			group by ASXCode
		) as r
		on a.ASXCode = r.ASXCode
		left join ScanResults.StockStatsHistoryPlusCurrent as s
		on a.ASXCode = s.ASXCode
		--left join #TempNextDayPrice as ndp
		--on a.ASXCode = ndp.ASXCode
		--left join #TempPrevDayPrice as pdp
		--on a.ASXCode = pdp.ASXCode
		left join Transform.TTSymbolUser as ttsu
		on a.ASXCode = ttsu.ASXCode
		left join Transform.DailyInstituteBuySell as dibs
		on a.ASXCode = dibs.ASXCode
		and dibs.ObservationDate = @dtDate
		left join Transform.PriceSummaryLatestFutureMA as plfm
		on a.ASXCode = plfm.ASXCode
		and plfm.RowNumber = @pintNumPrevDay + 2
		left join Transform.PriceSummaryLatestFutureMA as plfm2
		on a.ASXCode = plfm2.ASXCode
		and plfm2.RowNumber = @pintNumPrevDay + 3
		where 1 = 1
		order by 
			a.MedianTradeValueDaily desc,
			case when len(a.ASXCode) = 6 then 0 else 1 end,
			a.ASXCode

		
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
