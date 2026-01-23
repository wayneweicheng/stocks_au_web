-- Stored procedure: [Report].[usp_GetSectorTodayPerformance]


CREATE PROCEDURE [Report].[usp_GetSectorTodayPerformance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0,
@pvchSortBy as varchar(50) = 'Sector'
AS
/******************************************************************************
File: usp_GetSectorTodayPerformance.sql
Stored Procedure Name: usp_GetSectorTodayPerformance
Overview
-----------------
usp_GetSectorTodayPerformance

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
Date:		2018-03-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetSectorTodayPerformance'
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
		
		if object_id(N'Tempdb.dbo.#TempAnnouncement') is not null
			drop table #TempAnnouncement

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
			) as [SearchTerm]
		into #TempAnnouncement
		from StockData.Announcement as x
		where cast(AnnDateTime as date) = cast(dateadd(day, -1 * @pintNumPrevDay, getdate()) as date)
		
		delete a
		from #TempAnnouncement as a
		inner join
		(
			select 
				ASXCode,
				AnnDescr,
				row_number() over (partition by ASXCode order by AnnDateTime) as RowNumber
			from #TempAnnouncement
		) as b
		on a.ASXCode = b.ASXCode
		and a.AnnDescr = b.AnnDescr
		and b.RowNumber > 1

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
		right join StockData.StockOverviewCurrent as b
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

		--if object_id(N'Tempdb.dbo.#TempDirectorCurrent') is not null
		--	drop table #TempDirectorCurrent

		--select a.ASXCode, a.DirName
		--into #TempDirectorCurrent
		--from StockData.DirectorCurrentPvt as a
		
		--if object_id(N'Tempdb.dbo.#TempPostRaw') is not null
		--	drop table #TempPostRaw

		--select
		--	PostRawID,
		--	ASXCode,
		--	Poster,
		--	PostDateTime,
		--	PosterIsHeart,
		--	QualityPosterRating,
		--	Sentiment,
		--	Disclosure
		--into #TempPostRaw
		--from HC.TempPostLatest

		--if object_id(N'Tempdb.dbo.#TempPoster') is not null
		--	drop table #TempPoster

		--select x.ASXCode, stuff((
		--	select ',' + [Poster]
		--	from #TempPostRaw as a
		--	where x.ASXCode = a.ASXCode
		--	and (Sentiment in ('Buy') or Disclosure in ('Held'))
		--	and datediff(day, PostDateTime, getdate()) <= 60
		--	order by PostDateTime desc, isnull(QualityPosterRating, 200) asc
		--	for xml path('')), 1, 1, ''
		--) as [Poster]
		--into #TempPoster
		--from #TempPostRaw as x
		--where (Sentiment in ('Buy') or Disclosure in ('Held'))
		--and datediff(day, PostDateTime, getdate()) <= 60
		--group by x.ASXCode

		declare @dtMaxHistory as date
		select @dtMaxHistory = max(ObservationDate) from StockData.PriceHistoryCurrent

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[VWAP] decimal(20, 4),
			[PrevClose] decimal(20, 4)
		)

		if @pintNumPrevDay = 0
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose] 
			)
			select a.ASXCode, a.[Open], a.[Close], a.[VWAP], a.[PrevClose] as PrevClose
			from StockData.PriceSummaryToday as a
			--inner join StockData.PriceHistoryCurrent as b
			--on a.ASXCode = b.ASXCode
			where ObservationDate = [Common].[DateAddBusinessDay](0, cast(getdate() as date))
			and DateTo is null

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose] 
			)
			select
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose] 			
			from StockData.PriceSummary as a
			where ObservationDate = [Common].[DateAddBusinessDay](0, cast(getdate() as date))
			and a.LatestForTheDay = 1
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)			

		end
		else
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose] 
			)
			select
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose] 			
			from StockData.PriceSummary as a
			where ObservationDate = [Common].[DateAddBusinessDay](-1 * @pintNumPrevDay, cast(getdate() as date))
			and a.LatestForTheDay = 1

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 			
			from StockData.StockStatsHistoryPlus as a
			where ObservationDate = [Common].[DateAddBusinessDay](-1 * @pintNumPrevDay, cast(getdate() as date))
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)			

		end

		delete a
		from #TempPriceSummary as a
		where PrevClose = 0

		--declare @pintNumPrevDay as int = 5

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempPriceSummaryMatchVolume') is not null
			drop table #TempPriceSummaryMatchVolume

		select *
		into #TempPriceSummaryMatchVolume
		from
		(
			select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
			from StockData.v_PriceSummary
			where ObservationDate = @dtDate
			and MatchVolume > 0
			and Volume = 0
			--and cast(DateFrom as time) < '11:15:00'
		) as a
		where RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempPriceSummaryIndicativePrice') is not null
			drop table #TempPriceSummaryIndicativePrice

		select *
		into #TempPriceSummaryIndicativePrice
		from
		(
			select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
			from StockData.v_PriceSummary
			where ObservationDate = @dtDate
			and MatchVolume > 0
			and Volume = 0
			--and cast(DateFrom as time) < '11:15:00'
			and IndicativePrice > 0
		) as a
		where RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempPriceSummaryHighOpen') is not null
			drop table #TempPriceSummaryHighOpen

		select ASXCode, ObservationDate, [High], [Open]
		into #TempPriceSummaryHighOpen
		from StockData.v_PriceSummary
		where DateTo is null
		and LatestForTheDay = 1
		and ObservationDate = @dtDate

		if object_id(N'Tempdb.dbo.#TempAvgVolume') is not null
			drop table #TempAvgVolume

		select ASXCode, avg(Volume) as AvgVolume
		into #TempAvgVolume
		from StockData.PriceHistory
		where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -2, getdate()) as date)
		and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		group by ASXCode

		if object_id(N'Tempdb.dbo.#TempMatchOutofFreeFloat') is not null
			drop table #TempMatchOutofFreeFloat

		select 
			a.ASXCode, 
			a.DateFrom as ObservationDateTime,
			--case when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 3 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 1.2
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 20 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.75 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 200 then 1.5
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.50 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 100 then 2.5
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 3 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 2.3
			--		when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 2.2
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 3.2
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 100 then 4.2
			--		when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 20 then 3.3
			--		when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 100 then 4.3	
			--		when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 5.2	
			--		when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.8 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 6.2	
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 200 then 7.2
			--		when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 7.2	
			--		else 99
			--end as Grade,
			c.AnnDateTime,
			a1.IndicativePrice,
			case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end as PriceChange,
			a.MatchVolume as MatchVolume,
			cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) as IndicativeMatchValue,
			cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as MatchVolumeOutOfFreeFloat, 
			cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
			cast(case when h.[Open] > 0 then (h.[High] - h.[Open])*100.0/h.[Open] else null end as decimal(20, 2)) as MaxPriceIncrease,
			c.AnnDescr, 
			d.CleansedMarketCap as MarketCap, 
			cast(e.MedianTradeValue as int) as MedianTradeValueWeekly, 
			cast(e.MedianTradeValueDaily as int) as MedianTradeValueDaily, 
			e.MedianPriceChangePerc,
			f.RelativePriceStrength	
		into #TempMatchOutofFreeFloat	
		from #TempPriceSummaryMatchVolume as a
		inner join #TempPriceSummaryIndicativePrice as a1
		on a.ASXCode = a1.ASXCode
		inner join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode
		left join 
		(
			select ASXCode, AnnDescr, AnnDateTime, cast(AnnDateTime as date) as ObservationDate, row_number() over (partition by ASXCode, cast(AnnDateTime as date) order by AnnDateTime asc) as RowNumber
			from StockData.Announcement
			where cast(AnnDateTime as time) < '10:10:00'
		) as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and c.RowNumber = 1
		left join StockData.CompanyInfo as d
		on a.ASXCode = d.ASXCode
		left join StockData.MedianTradeValue as e
		on a.ASXCode = e.ASXCode
		left join StockData.v_RelativePriceStrength as f
		on a.ASXCode = f.ASXCode
		left join #TempAvgVolume as g
		on a.ASXCode = g.ASXCode
		left join #TempPriceSummaryHighOpen as h
		on a.ASXCode = h.ASXCode
		and a.ObservationDate = h.ObservationDate
		where b.FloatingShares > 0
		and a.MatchVolume > 0
		--and g.AvgVolume > 0
		--and cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0
		--and (a1.IndicativePrice is null or cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) >= 10)
		--AND a.ASXCode = 'EM1.AX'
		--and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.3

		if @pvchSortBy = 'Sector'
		begin
			select
			   upper(Sector) as Sector
			  ,[ASXCode]
			  ,cast(@dtDate as varchar(50)) as ObservationDate
			  ,[Open]
			  ,[Last]
			  ,[Close] as PrevClose
			  ,[VWAP]
			  ,case when cast(getdate() as time) < '10:10:00' then cast(replace(replace(MatchPriceChange, '%', ''), ',', '') as decimal(10, 2)) else ChangePerc end as ChangePerc
			  ,MatchPriceChange
			  ,IndicativeMatchValue
			  ,MatchVolumeOutOfFreeFloat
			  ,DailyChangeRate
			  ,MC
			  ,CashPosition
			  ,AnnDescr
			  ,AnnDateTime
			  ,RecentTopBuyBroker
			  ,RecentTopSellBroker
			  ,FriendlyNameList
			  ,SearchTerm
			  ,RankNumber
			from
			(
				select 
				   a.[Token] as Sector
				  ,a.[ASXCode]
				  ,b.[Open]
				  ,b.[Close] as [Last]
				  ,b.[PrevClose] as [Close]
				  ,b.VWAP
				  ,cast((b.[Close] - b.[PrevClose])*100.0/b.[Prevclose] as decimal(10, 2)) as ChangePerc
				  --,case when b.[Close] > 0 and b.VWAP > 0 then cast((b.[Close] - b.[VWAP])*100.0/b.[Close] as decimal(10, 2)) else null end as ChangePerc
				  ,cast(j.PriceChange as varchar(20)) + '%' as MatchPriceChange
				  ,j.IndicativeMatchValue
				  ,j.MatchVolumeOutOfFreeFloat
				  ,j.DailyChangeRate
				  ,cast(y.MC as decimal(8, 2)) as MC
				  ,cast(y.CashPosition as decimal(8, 2)) CashPosition
				  ,x.AnnDescr
				  ,x.AnnDateTime
				  ,m2.BrokerCode as RecentTopBuyBroker
				  ,n2.BrokerCode as RecentTopSellBroker
				  ,ttsu.FriendlyNameList
				  ,x.SearchTerm
				  ,cast(dense_rank() over (order by a.Token) as decimal(5, 1)) as RankNumber
				from LookupRef.StockKeyToken as a
				left join #TempPriceSummary as b
				on a.ASXCode = b.ASXCode
				left join #TempAnnouncement as x
				on a.ASXCode = x.ASXCode
				left join #TempCashVsMC as y
				on a.ASXCode = y.ASXCode
				left join #TempStockNature as d
				on a.ASXCode = d.ASXCode
				left join HC.HeadPostSummary as f
				on a.ASXCode = f.ASXCode
				left join Transform.PosterList as i
				on a.ASXCode = i.ASXCode
				left join #TempMatchOutofFreeFloat as j
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
				union
				select 
				   'N/A' as Sector
				  ,'XXX' as [ASXCode]
				  ,null as [Open]
				  ,null as [Last]
				  ,null as PrevClose
				  ,null as [VWAP]
				  ,null as ChangePerc
				  ,null as MatchPriceChange
				  ,null as IndicativeMatchValue
				  ,null as MatchVolumeOutOfFreeFloat
				  ,null as DailyChangeRate
				  ,null as MC
				  ,null as CashPosition
				  ,null as AnnDescr
				  ,null as AnnDateTime
				  ,null as RecentTopBuyBroker
				  ,null as RecentTopSellBroker
				  ,null as FriendlyNameList
				  ,null as SearchTerm
				  ,RowNumber as RankNumber
				from
				(
					select 1.1 as RowNumber
					union
					select 2.1 as RowNumber
					union
					select 3.1 as RowNumber
					union
					select 4.1 as RowNumber
					union
					select 5.1 as RowNumber
					union
					select 6.1 as RowNumber
					union
					select 7.1 as RowNumber
					union
					select 8.1 as RowNumber
					union
					select 9.1 as RowNumber
					union
					select 10.1 as RowNumber
					union
					select 11.1 as RowNumber
					union
					select 12.1 as RowNumber
					union
					select 13.1 as RowNumber
					union
					select 14.1 as RowNumber
					union
					select 15.1 as RowNumber
					union
					select 16.1 as RowNumber
					union
					select 17.1 as RowNumber
					union
					select 18.1 as RowNumber
					union
					select 19.1 as RowNumber
					union
					select 20.1 as RowNumber
					union
					select 21.1 as RowNumber
					union
					select 22.1 as RowNumber
					union
					select 23.1 as RowNumber
					union
					select 24.1 as RowNumber
					union
					select 25.1 as RowNumber
					union
					select 26.1 as RowNumber
					union
					select 27.1 as RowNumber
					union
					select 28.1 as RowNumber
					union
					select 29.1 as RowNumber
					union
					select 30.1 as RowNumber
					union
					select 31.1 as RowNumber
					union
					select 32.1 as RowNumber
					union
					select 33.1 as RowNumber
					union
					select 34.1 as RowNumber
					union
					select 35.1 as RowNumber
					union
					select 36.1 as RowNumber
					union
					select 37.1 as RowNumber
					union
					select 38.1 as RowNumber
					union
					select 39.1 as RowNumber
					union
					select 40.1 as RowNumber
					union
					select 41.1 as RowNumber
					union
					select 42.1 as RowNumber
					union
					select 43.1 as RowNumber
					union
					select 44.1 as RowNumber
					union
					select 45.1 as RowNumber
					union
					select 46.1 as RowNumber
					union
					select 47.1 as RowNumber
					union
					select 48.1 as RowNumber
					union
					select 49.1 as RowNumber
					union
					select 50.1 as RowNumber
				) as a
			) as x
			order by x.RankNumber

		end

		if @pvchSortBy = 'Sector - AggregateNumDays'
		begin

			if object_id(N'Tempdb.dbo.#TempPriceSummaryToday') is not null
				drop table #TempPriceSummaryToday

			create table #TempPriceSummaryToday
			(
				ASXCode varchar(10) not null,
				[Open] decimal(20, 4),
				[Close] decimal(20, 4),
				[PrevClose] decimal(20, 4)
			)

			insert into #TempPriceSummaryToday
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 
			)
			select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose
			from StockData.PriceSummaryToday as a
			where ObservationDate = [Common].[DateAddBusinessDay](0, cast(getdate() as date))
			and DateTo is null

			insert into #TempPriceSummaryToday
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 			
			from StockData.PriceSummary as a
			where ObservationDate = [Common].[DateAddBusinessDay](0, cast(getdate() as date))
			and a.LatestForTheDay = 1
			and not exists
			(
				select 1
				from #TempPriceSummaryToday
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)			

			if not exists(
				select 1
				from #TempPriceSummaryToday
			)
			insert into #TempPriceSummaryToday
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 
			)
			select
				ASXCode,
				[Open],
				[Close],
				null as [PrevClose] 			
			from StockData.PriceHistoryCurrent as a

			select
			   upper(Sector) as Sector
			  ,[ASXCode]
			  ,[Open]
			  ,[Last]
			  ,[Close]
			  ,ChangePerc
			  ,MC
			  ,CashPosition
			  ,AnnDescr
			  ,AnnDateTime
			  ,RecentTopBuyBroker
			  ,RecentTopSellBroker
			  ,FriendlyNameList
			  ,SearchTerm
			  ,RankNumber
			from
			(
				select 
				   a.[Token] as Sector
				  ,a.[ASXCode]
				  ,b.[Open]
				  ,j.[Close] as [Last]
				  ,b.[PrevClose] as [Close]
				  ,cast((j.[Close] - b.[PrevClose])*100.0/b.[Prevclose] as decimal(10, 2)) as ChangePerc
				  ,cast(y.MC as decimal(8, 2)) as MC
				  ,cast(y.CashPosition as decimal(8, 2)) CashPosition
				  ,'N/A' as AnnDescr
				  ,'N/A' as AnnDateTime
				  ,m2.BrokerCode as RecentTopBuyBroker
				  ,n2.BrokerCode as RecentTopSellBroker
				  ,ttsu.FriendlyNameList
				  ,x.SearchTerm
				  ,cast(dense_rank() over (order by a.Token) as decimal(5, 1)) as RankNumber
				from LookupRef.StockKeyToken as a
				left join #TempPriceSummary as b
				on a.ASXCode = b.ASXCode
				left join #TempPriceSummaryToday as j
				on a.ASXCode = j.ASXCode
				left join #TempAnnouncement as x
				on a.ASXCode = x.ASXCode
				left join #TempCashVsMC as y
				on a.ASXCode = y.ASXCode
				left join #TempStockNature as d
				on a.ASXCode = d.ASXCode
				left join HC.HeadPostSummary as f
				on a.ASXCode = f.ASXCode
				left join Transform.PosterList as i
				on a.ASXCode = i.ASXCode
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
				union
				select 
				   'N/A' as Sector
				  ,'XXX' as [ASXCode]
				  ,null as [Open]
				  ,null as [Last]
				  ,null as [Close]
				  ,null as ChangePerc
				  ,null as MC
				  ,null as CashPosition
				  ,null as AnnDescr
				  ,null as AnnDateTime
				  ,null as RecentTopBuyBroker
				  ,null as RecentTopSellBroker
				  ,null as FriendlyNameList
				  ,null as SearchTerm
				  ,RowNumber as RankNumber
				from
				(
					select 1.1 as RowNumber
					union
					select 2.1 as RowNumber
					union
					select 3.1 as RowNumber
					union
					select 4.1 as RowNumber
					union
					select 5.1 as RowNumber
					union
					select 6.1 as RowNumber
					union
					select 7.1 as RowNumber
					union
					select 8.1 as RowNumber
					union
					select 9.1 as RowNumber
					union
					select 10.1 as RowNumber
					union
					select 11.1 as RowNumber
					union
					select 12.1 as RowNumber
					union
					select 13.1 as RowNumber
					union
					select 14.1 as RowNumber
					union
					select 15.1 as RowNumber
					union
					select 16.1 as RowNumber
					union
					select 17.1 as RowNumber
					union
					select 18.1 as RowNumber
					union
					select 19.1 as RowNumber
					union
					select 20.1 as RowNumber
					union
					select 21.1 as RowNumber
					union
					select 22.1 as RowNumber
					union
					select 23.1 as RowNumber
					union
					select 24.1 as RowNumber
					union
					select 25.1 as RowNumber
					union
					select 26.1 as RowNumber
					union
					select 27.1 as RowNumber
					union
					select 28.1 as RowNumber
					union
					select 29.1 as RowNumber
					union
					select 30.1 as RowNumber
					union
					select 31.1 as RowNumber
					union
					select 32.1 as RowNumber
					union
					select 33.1 as RowNumber
					union
					select 34.1 as RowNumber
					union
					select 35.1 as RowNumber
					union
					select 36.1 as RowNumber
					union
					select 37.1 as RowNumber
					union
					select 38.1 as RowNumber
					union
					select 39.1 as RowNumber
					union
					select 40.1 as RowNumber
					union
					select 41.1 as RowNumber
					union
					select 42.1 as RowNumber
					union
					select 43.1 as RowNumber
					union
					select 44.1 as RowNumber
					union
					select 45.1 as RowNumber
					union
					select 46.1 as RowNumber
					union
					select 47.1 as RowNumber
					union
					select 48.1 as RowNumber
					union
					select 49.1 as RowNumber
					union
					select 50.1 as RowNumber
				) as a
			) as x
			order by x.RankNumber

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
