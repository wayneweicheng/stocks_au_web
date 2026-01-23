-- Stored procedure: [Report].[usp_GetStockAnnouncement]


--exec [Report].[usp_GetStockAnnouncement]
--@pintNumPrevDay = 0,
--@pvchSortBy = 'Change Rate'

CREATE PROCEDURE [Report].[usp_GetStockAnnouncement]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0,
@pvchSortBy as varchar(50) = 'Ann DateTime'
AS
/******************************************************************************
File: usp_GetStockAnnouncement.sql
Stored Procedure Name: usp_GetStockAnnouncement
Overview
-----------------
usp_GetStockScreening

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
Date:		2018-02-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStockAnnouncement'
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
		--declare @pintNumPrevDay as int = 1
		
		if object_id(N'Tempdb.dbo.#TempAnnouncement') is not null
			drop table #TempAnnouncement

		select 
			AnnouncementID,
			ASXCode,
			AnnDescr,
			AnnDateTime,
			cast(AnnDateTime as date) as ObservationDate,
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

		if object_id(N'Tempdb.dbo.#TempPriceSummaryHistory') is not null
			drop table #TempPriceSummaryHistory

		select distinct
			a.ASXCode,
			a.ObservationDate,
			b.DateFrom,
			b.[Open],
			b.[Close],
			b.Volume,
			b.Value,
			b.VWap,
			cast(null as bit) as IsMinute0,
			cast(null as bit) as IsMinute5,
			cast(null as bit) as IsMinute15,
			cast(null as bit) as IsMinute30,
			cast(null as bit) as IsMinute60
		into #TempPriceSummaryHistory
		from #TempAnnouncement as a
		inner join StockData.v_PriceSummaryHistory as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		where b.Volume > 0

		update a
		set a.IsMinute0 = 1
		from #TempPriceSummaryHistory as a
		inner join 
		(
			select ASXCode, ObservationDate, min(DateFrom) as DateFrom
			from #TempPriceSummaryHistory
			group by ASXCode, ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.DateFrom = b.DateFrom

		update a
		set a.IsMinute5 = 1
		from #TempPriceSummaryHistory as a
		inner join 
		(
			select a.ASXCode, a.ObservationDate, min(a.DateFrom) as DateFrom
			from #TempPriceSummaryHistory as a
			inner join #TempPriceSummaryHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.IsMinute0 = 1
			and a.DateFrom > dateadd(minute, 5, b.DateFrom) 
			group by a.ASXCode, a.ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.DateFrom = b.DateFrom

		update a
		set a.IsMinute15 = 1
		from #TempPriceSummaryHistory as a
		inner join 
		(
			select a.ASXCode, a.ObservationDate, min(a.DateFrom) as DateFrom
			from #TempPriceSummaryHistory as a
			inner join #TempPriceSummaryHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.IsMinute0 = 1
			and a.DateFrom > dateadd(minute, 15, b.DateFrom) 
			group by a.ASXCode, a.ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.DateFrom = b.DateFrom

		update a
		set a.IsMinute30 = 1
		from #TempPriceSummaryHistory as a
		inner join 
		(
			select a.ASXCode, a.ObservationDate, min(a.DateFrom) as DateFrom
			from #TempPriceSummaryHistory as a
			inner join #TempPriceSummaryHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.IsMinute0 = 1
			and a.DateFrom > dateadd(minute, 30, b.DateFrom) 
			group by a.ASXCode, a.ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.DateFrom = b.DateFrom

		update a
		set a.IsMinute60 = 1
		from #TempPriceSummaryHistory as a
		inner join 
		(
			select a.ASXCode, a.ObservationDate, min(a.DateFrom) as DateFrom
			from #TempPriceSummaryHistory as a
			inner join #TempPriceSummaryHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.IsMinute0 = 1
			and a.DateFrom > dateadd(minute, 60, b.DateFrom) 
			group by a.ASXCode, a.ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.DateFrom = b.DateFrom

		if object_id(N'Tempdb.dbo.#TempIndPrice') is not null
			drop table #TempIndPrice

		select *, 
		cast(null as decimal(20, 4)) as Prev1IndicativePrice, 
		cast(null as char(1)) as IndPriceDirection,
		cast(null as int) as Prev1SurplusVolume
		into #TempIndPrice
		from StockData.v_PriceSummary as a 
		where ObservationDate = cast(dateadd(day, -1 * @pintNumPrevDay, getdate()) as date)
		and exists(
			select 1
			from #TempAnnouncement
			where ASXCode = a.ASXCode
		)
		and cast(DateFrom as time) < cast('10:10:15' as time)
		and Volume = 0
		order by PriceSummaryID

		update a
		set a.Prev1IndicativePrice = b.IndicativePrice,
			a.Prev1SurplusVolume = b.SurplusVolume
		from #TempIndPrice as a
		inner join #TempIndPrice as b
		on a.Prev1PriceSummaryID = b.PriceSummaryID

		update a
		set IndicativePrice = null
		from #TempIndPrice as a
		where IndicativePrice = 0

		update a
		set a.IndPriceDirection = case when a.IndicativePrice > a.Prev1IndicativePrice or (a.IndicativePrice = a.Prev1IndicativePrice and a.SurplusVolume > a.Prev1SurplusVolume) then 'U'
									   when (a.IndicativePrice = a.Prev1IndicativePrice and a.SurplusVolume = a.Prev1SurplusVolume) then 'S'
									   when a.IndicativePrice < a.Prev1IndicativePrice or (a.IndicativePrice = a.Prev1IndicativePrice and a.SurplusVolume < a.Prev1SurplusVolume) then 'D'
								  else 'I'
								  end
		from #TempIndPrice as a

		if object_id(N'Tempdb.dbo.#TempIndPriceLast') is not null
			drop table #TempIndPriceLast

		select
			PriceSummaryID,
			ASXCode,
			IndicativePrice,
			PrevClose,
			PriceChange,
			IndPriceDirection
		into #TempIndPriceLast
		from
		(
			select
				PriceSummaryID,
				ASXCode,
				IndicativePrice,
				PrevClose,
				cast(case when PrevClose > 0 and IndicativePrice > 0 then (IndicativePrice - PrevClose)*100.0/PrevClose else null end as decimal(8, 2)) as PriceChange,
				IndPriceDirection,
				row_number() over (partition by ASXCode order by DateFrom desc) as RowNumber
			from #TempIndPrice
		) as a
		where RowNumber = 1

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

		if object_id(N'Tempdb.dbo.#TempDirectorCurrent') is not null
			drop table #TempDirectorCurrent

		select a.ASXCode, a.DirName
		into #TempDirectorCurrent
		from StockData.DirectorCurrentPvt as a

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
		--	and exists
		--	(
		--		select 1
		--		from #TempAnnouncement
		--		where ASXCode = a.ASXCode
		--	)
		--	order by PostDateTime desc, isnull(QualityPosterRating, 200) asc
		--	for xml path('')), 1, 1, ''
		--) as [Poster]
		--into #TempPoster
		--from #TempPostRaw as x
		--where (Sentiment in ('Buy') or Disclosure in ('Held'))
		--and datediff(day, PostDateTime, getdate()) <= 60
		--and exists
		--(
		--	select 1
		--	from #TempAnnouncement
		--	where ASXCode = x.ASXCode
		--)
		--group by x.ASXCode

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[PrevClose] decimal(20, 4),
			[Value] decimal(20, 4) 
		)

		insert into #TempPriceSummary
		(
			ASXCode,
			[Open],
			[Close],
			[PrevClose],
			[Value]
		)
		select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, [Value]
		from StockData.v_PriceSummary as a
		--inner join StockData.PriceHistoryCurrent as b
		--on a.ASXCode = b.ASXCode
		where ObservationDate = cast(dateadd(day, -1*@pintNumPrevDay, getdate()) as date)
		and DateTo is null

		delete a
		from #TempPriceSummary as a
		where PrevClose = 0

		if @pvchSortBy = 'Ann DateTime'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				case when h.[PrevClose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[PrevClose] as decimal(10, 2)) else null end as ChangePerc,
				case when c.MC > 0 then cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) else null end as ValueOverMC,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster,
				j.PriceChange,
				j.IndPriceDirection,
				j.IndicativePrice,
				j.PrevClose,
				cast(min5.[Value] as bigint) as TradeValue5m,				
				case when c.MC > 0 then cast(min5.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate5m,
				min5.VWAP as VWAP5m,
				cast(min15.[Value] as bigint) as TradeValue15m,				
				case when c.MC > 0 then cast(min15.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate15m,
				min15.VWAP as VWAP15m,
				cast(min30.[Value] as bigint) as TradeValue30m,				
				case when c.MC > 0 then cast(min30.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate30m,
				min30.VWAP as VWAP30m,
				x.SearchTerm
			from #TempAnnouncement as x
			left join #TempCashVsMC as c
			on x.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on x.ASXCode = f.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on x.ASXCode = i.ASXCode
			left join #TempIndPriceLast as j
			on x.ASXCode = j.ASXCode
			left join #TempPriceSummaryHistory as min5
			on x.ASXCode = min5.ASXCode
			and cast(x.AnnDateTime as date) = min5.ObservationDate
			and min5.IsMinute5 = 1
			left join #TempPriceSummaryHistory as min15
			on x.ASXCode = min15.ASXCode
			and cast(x.AnnDateTime as date) = min15.ObservationDate
			and min15.IsMinute15 = 1
			left join #TempPriceSummaryHistory as min30
			on x.ASXCode = min30.ASXCode
			and cast(x.AnnDateTime as date) = min30.ObservationDate
			and min30.IsMinute30 = 1
			order by x.AnnDateTime desc

		end

		if @pvchSortBy = 'Market Cap'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				case when h.[PrevClose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[PrevClose] as decimal(10, 2)) else null end as ChangePerc,
				case when c.MC > 0 then cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) else null end as ValueOverMC,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster,
				j.PriceChange,
				j.IndPriceDirection,
				j.IndicativePrice,
				j.PrevClose,
				cast(min5.[Value] as bigint) as TradeValue5m,				
				case when c.MC > 0 then cast(min5.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate5m,
				min5.VWAP as VWAP5m,
				cast(min15.[Value] as bigint) as TradeValue15m,				
				case when c.MC > 0 then cast(min15.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate15m,
				min15.VWAP as VWAP15m,
				cast(min30.[Value] as bigint) as TradeValue30m,				
				case when c.MC > 0 then cast(min30.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate30m,
				min30.VWAP as VWAP30m,
				x.SearchTerm
			from #TempAnnouncement as x
			left join #TempCashVsMC as c
			on x.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on x.ASXCode = f.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on x.ASXCode = i.ASXCode
			left join #TempIndPriceLast as j
			on x.ASXCode = j.ASXCode
			left join #TempPriceSummaryHistory as min5
			on x.ASXCode = min5.ASXCode
			and cast(x.AnnDateTime as date) = min5.ObservationDate
			and min5.IsMinute5 = 1
			left join #TempPriceSummaryHistory as min15
			on x.ASXCode = min15.ASXCode
			and cast(x.AnnDateTime as date) = min15.ObservationDate
			and min15.IsMinute15 = 1
			left join #TempPriceSummaryHistory as min30
			on x.ASXCode = min30.ASXCode
			and cast(x.AnnDateTime as date) = min30.ObservationDate
			and min30.IsMinute30 = 1
			order by isnull(cast(h.[Value]/1000.0 as decimal(10, 2)), 0) desc
		end

		if @pvchSortBy = 'Poster'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				case when h.[PrevClose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[PrevClose] as decimal(10, 2)) else null end as ChangePerc,
				case when c.MC > 0 then cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) else null end as ValueOverMC,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster,
				j.PriceChange,
				j.IndPriceDirection,
				j.IndicativePrice,
				j.PrevClose,
				cast(min5.[Value] as bigint) as TradeValue5m,				
				case when c.MC > 0 then cast(min5.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate5m,
				min5.VWAP as VWAP5m,
				cast(min15.[Value] as bigint) as TradeValue15m,				
				case when c.MC > 0 then cast(min15.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate15m,
				min15.VWAP as VWAP15m,
				cast(min30.[Value] as bigint) as TradeValue30m,				
				case when c.MC > 0 then cast(min30.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate30m,
				min30.VWAP as VWAP30m,
				x.SearchTerm
			from #TempAnnouncement as x
			left join #TempCashVsMC as c
			on x.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on x.ASXCode = f.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on x.ASXCode = i.ASXCode
			left join #TempIndPriceLast as j
			on x.ASXCode = j.ASXCode
			left join #TempPriceSummaryHistory as min5
			on x.ASXCode = min5.ASXCode
			and cast(x.AnnDateTime as date) = min5.ObservationDate
			and min5.IsMinute5 = 1
			left join #TempPriceSummaryHistory as min15
			on x.ASXCode = min15.ASXCode
			and cast(x.AnnDateTime as date) = min15.ObservationDate
			and min15.IsMinute15 = 1
			left join #TempPriceSummaryHistory as min30
			on x.ASXCode = min30.ASXCode
			and cast(x.AnnDateTime as date) = min30.ObservationDate
			and min30.IsMinute30 = 1
			order by len(i.Poster) desc
		end

		if @pvchSortBy = 'Search Term'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				case when h.[PrevClose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[PrevClose] as decimal(10, 2)) else null end as ChangePerc,
				case when c.MC > 0 then cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) else null end as ValueOverMC,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster,
				j.PriceChange,
				j.IndPriceDirection,
				j.IndicativePrice,
				j.PrevClose,
				cast(min5.[Value] as bigint) as TradeValue5m,				
				case when c.MC > 0 then cast(min5.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate5m,
				min5.VWAP as VWAP5m,
				cast(min15.[Value] as bigint) as TradeValue15m,				
				case when c.MC > 0 then cast(min15.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate15m,
				min15.VWAP as VWAP15m,
				cast(min30.[Value] as bigint) as TradeValue30m,				
				case when c.MC > 0 then cast(min30.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate30m,
				min30.VWAP as VWAP30m,
				x.SearchTerm
			from #TempAnnouncement as x
			left join #TempCashVsMC as c
			on x.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on x.ASXCode = f.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on x.ASXCode = i.ASXCode
			left join #TempIndPriceLast as j
			on x.ASXCode = j.ASXCode
			left join #TempPriceSummaryHistory as min5
			on x.ASXCode = min5.ASXCode
			and cast(x.AnnDateTime as date) = min5.ObservationDate
			and min5.IsMinute5 = 1
			left join #TempPriceSummaryHistory as min15
			on x.ASXCode = min15.ASXCode
			and cast(x.AnnDateTime as date) = min15.ObservationDate
			and min15.IsMinute15 = 1
			left join #TempPriceSummaryHistory as min30
			on x.ASXCode = min30.ASXCode
			and cast(x.AnnDateTime as date) = min30.ObservationDate
			and min30.IsMinute30 = 1
			order by case when len(x.SearchTerm) > 0 then 0 else 1 end, isnull(c.MC, 99999) asc

		end

		if @pvchSortBy = 'Change Rate'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				--cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				case when h.[PrevClose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[PrevClose] as decimal(10, 2)) else null end as ChangePerc,
				case when c.MC > 0 then cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) else null end as ValueOverMC,
				j.PriceChange,
				j.IndPriceDirection,
				j.IndicativePrice,
				j.PrevClose,
				cast(min5.[Value] as bigint) as TradeValue5m,				
				case when c.MC > 0 then cast(min5.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate5m,
				min5.VWAP as VWAP5m,
				cast(min15.[Value] as bigint) as TradeValue15m,				
				case when c.MC > 0 then cast(min15.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate15m,
				min15.VWAP as VWAP15m,
				cast(min30.[Value] as bigint) as TradeValue30m,				
				case when c.MC > 0 then cast(min30.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end as ChangeRate30m,
				min30.VWAP as VWAP30m,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster,
				x.SearchTerm
			from #TempAnnouncement as x
			left join 
			(
				select 
					ASXCode,
					CleansedMarketCap as MC,
					DateFrom,
					DateTo
				from HC.StockOverview 
			) as c
			on x.ASXCode = c.ASXCode
			and x.AnnDateTime > c.DateFrom
			and x.AnnDateTime <= isnull(c.DateTo, '2050-01-01')
			left join #TempStockNature as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on x.ASXCode = f.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on x.ASXCode = i.ASXCode
			left join #TempIndPriceLast as j
			on x.ASXCode = j.ASXCode
			left join #TempPriceSummaryHistory as min5
			on x.ASXCode = min5.ASXCode
			and cast(x.AnnDateTime as date) = min5.ObservationDate
			and min5.IsMinute5 = 1
			left join #TempPriceSummaryHistory as min15
			on x.ASXCode = min15.ASXCode
			and cast(x.AnnDateTime as date) = min15.ObservationDate
			and min15.IsMinute15 = 1
			left join #TempPriceSummaryHistory as min30
			on x.ASXCode = min30.ASXCode
			and cast(x.AnnDateTime as date) = min30.ObservationDate
			and min30.IsMinute30 = 1
			order by coalesce(
								case when c.MC > 0 then cast(min30.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end, 
								case when c.MC > 0 then cast(min15.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end, 
								case when c.MC > 0 then cast(min5.[Value]*100.0/(c.MC*1000.0*1000.0) as decimal(20,2)) else null end,
								0
							) desc

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
