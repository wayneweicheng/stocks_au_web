-- Stored procedure: [Report].[usp_GetStockScanResult_BAK]



create PROCEDURE [Report].[usp_GetStockScanResult_BAK]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSortBy as varchar(50) = 'Alert Occurrence',
@pintNumPrevDay as int = 0,
@pbitAddToTable as bit = 0
AS
/******************************************************************************
File: usp_GetStockScanResult.sql
Stored Procedure Name: usp_GetStockScanResult
Overview
-----------------
usp_GetStockScanResult

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
Date:		2018-02-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStockScanResult'
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

		if object_id(N'Tempdb.dbo.#TempAnnouncement') is not null
			drop table #TempAnnouncement

		select 
			ASXCode,
			AnnDescr,
			AnnDateTime,
			row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
		into #TempAnnouncement
		from Transform.v_Announcement as x
		where cast(AnnDateTime as date) = @dtDate

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select * 
		into #TempPriceSummary
		from StockData.v_PriceSummary
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
		from Transform.PriceHistory as a
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
		from StockData.PriceHistory
		where ObservationDate = @dtNextDate

		if object_id(N'Tempdb.dbo.#TempPrevDayPrice') is not null
			drop table #TempPrevDayPrice

		select * 
		into #TempPrevDayPrice
		from Transform.PriceHistory
		where ObservationDate = @dtPrevDate

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
		--		from StockData.PriceHistoryCurrent
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
		--	from StockData.PriceHistoryCurrent
		--	where ASXCode = x.ASXCode
		--)
		--group by x.ASXCode

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate = @dtDate
		group by ASXCode, b.DisplayBrokerCode

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate >= Common.DateAddBusinessDay(-8, @dtDate)
		and ObservationDate <= @dtDate
		group by ASXCode, b.DisplayBrokerCode

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
			from Stock.ASXAlertHistory
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

		if object_id(N'Tempdb.dbo.#TempBrokerReportListLastNDay') is not null
			drop table #TempBrokerReportListLastNDay

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListLastNDay
		from #TempBRAggregateLastNDay as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNegLastNDay') is not null
			drop table #TempBrokerReportListNegLastNDay

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNegLastNDay
		from #TempBRAggregateLastNDay as x

		if @pvchSortBy = 'Value Over MC'
		begin
			select top 500
				a.ASXCode,
				a.AlertTypeName,
				a.CreateDate as AlertCreateDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,				
				g.[AnnDescr],
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from #TempAlertHistoryAggregate as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempAnnouncement as g
			on a.ASXCode = g.ASXCode
			and g.RowNumber = 1
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			order by cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) desc
		end

		if @pvchSortBy = 'Price Changes'
		begin
			select top 500
				a.ASXCode,
				a.AlertTypeName,
				a.CreateDate as AlertCreateDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				g.[AnnDescr],
				i.Poster
			from #TempAlertHistoryAggregate as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempAnnouncement as g
			on a.ASXCode = g.ASXCode
			and g.RowNumber = 1
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
		end

		if @pvchSortBy = 'Market Cap'
		begin
			select top 500
				a.ASXCode,
				a.AlertTypeName,
				a.CreateDate as AlertCreateDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				g.[AnnDescr],
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from #TempAlertHistoryAggregate as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempAnnouncement as g
			on a.ASXCode = g.ASXCode
			and g.RowNumber = 1
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			where cast(c.MC as decimal(8, 2)) >= 2
			order by cast(c.MC as decimal(8, 2)) asc
		end

		if @pvchSortBy = 'Alert Type Name'
		begin
			select top 500
				a.ASXCode,
				a.AlertTypeName,
				a.CreateDate as AlertCreateDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				g.[AnnDescr],
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from #TempAlertHistoryAggregate as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempAnnouncement as g
			on a.ASXCode = g.ASXCode
			and g.RowNumber = 1
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			order by a.AlertTypeName

		end

		if @pvchSortBy = 'Alert CreateDate'
		begin
			select top 500
				a.ASXCode,
				a.AlertTypeName,
				a.CreateDate as AlertCreateDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				g.[AnnDescr],
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from #TempAlertHistoryAggregate as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempAnnouncement as g
			on a.ASXCode = g.ASXCode
			and g.RowNumber = 1
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			order by a.CreateDate desc

		end

		if @pvchSortBy = 'Alert Occurrence'
		begin
			if object_id(N'Tempdb.dbo.#TempPriceSummaryHistory') is not null
				drop table #TempPriceSummaryHistory

			select row_number() over (partition by ASXCode order by ObservationDate asc) as DayRank, *
			into #TempPriceSummaryHistory
			from #TempPriceSummary
			where 1 = 1
			and ObservationDate >= @dtDate
			and DateTo is null
			and LatestForTheDay = 1

			if @pbitAddToTable = 0
			begin
				select top 500
					a.ASXCode,
					a.AlertTypeName,
					a.CreateDate as AlertCreateDate,
					case when a.AlertTypeScore >= 50 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 3.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 2000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 1.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 3.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) and case when s.MovingAverage10d > 0 then cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) else null end < 30 then 1.1
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 2.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 700 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) and case when s.MovingAverage10d > 0 then cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) else null end < 30 then 2.5
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 3.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(j.MedianTradeValue as int) > 300 and case when s.MovingAverage10d > 0 then cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) else null end < 30 then 3.5
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(j.MedianTradeValue as int) > 1000 then 4.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) > 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 8.2
						 when a.AlertTypeScore >= 25 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 500 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 6.2
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 500 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 7.2
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1.25 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int) then 4.5
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.60 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int) then 7.5
						 when a.AlertTypeScore >= 50 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 3.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 then 3.0
						 when a.AlertTypeScore >= 50 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 then 3.5					 
						 else 99
					end as Grade,
					case when a.AlertTypeScore >= 30 and h.[Volume] > psh2.[Volume] and psh2.[Volume] > psh3.[Volume] and psh3.Volume < h.[Volume]*0.55 and psh3.[close] >= (h.[Close] + h.[Open])/2.0 and psh3.[close] <= h.[Close] then 3.0
						 when a.AlertTypeScore >= 15 and h.[Volume] > psh2.[Volume] and psh2.[Volume] > psh3.[Volume] and psh3.Volume < h.[Volume]*0.55 and psh3.[close] >= (h.[Close] + h.[Open])/2.0 and psh3.[close] <= h.[High] then 5.0
						 else 99
					end as RetraceScore,
					e.IndustrySubGroup,
					cast(coalesce(b.SharesIssued*h.[Close]*1.0, c.MC) as decimal(8, 2)) as MC,
					cast(c.CashPosition as decimal(8, 2)) CashPosition,
					cast(h.[Value]/1000.0 as int) as [T/O in K],
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
					cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
					case when h.[Close] > 0 then cast(cast(pdp.PriceChangeVsPrevClose as decimal(20, 2)) as varchar(20)) + '%' else null end as PrevDayChangePerc,
					case when h.PrevClose >  0 then cast(cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) as varchar(20)) + '%' else null end as TodayChangePerc,
					cast(cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as varchar(20)) + '%' as [T/O Rate], 
					case when ndp.[Open] > 0 and h.[Close] > 0 then cast(cast((ndp.[Open] - h.[Close])*100.0/h.[Close] as decimal(20, 2)) as varchar(20)) + '%' else null end as NextDayOpenProfit,
					case when ndp.[Close] > 0 and h.[Close] > 0 then cast(cast((ndp.[Close] - h.[Close])*100.0/h.[Close] as decimal(20, 2)) as varchar(20)) + '%' else null end as NextDayCloseProfit,
					m.BrokerCode as ObservationDayTopBuyBroker,
					n.BrokerCode as ObservationDayTopSellBroker,
					m2.BrokerCode as RecentTopBuyBroker,
					n2.BrokerCode as RecentTopSellBroker,
					case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
					case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
					g.[AnnDescr],
					o.NoBuy,
					p.NoSigNotice as NoSig,
					q.WeekMonthPositive as [WkMon+],
					cast(d.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
					cast(d.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
					cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) as BarStrength,
					a.AlertTypeScore
				from #TempAlertHistoryAggregate as a
				left join StockData.v_CompanyFloatingShare as b
				on a.ASXCode = b.ASXCode
				left join #TempCashVsMC as c
				on a.ASXCode = c.ASXCode
				left join StockData.RetailParticipation as d
				on a.ASXCode = d.ASXCode
				left join StockData.CompanyInfo as e
				on a.ASXCode = e.ASXCode
				left join #TempAnnouncement as g
				on a.ASXCode = g.ASXCode
				and g.RowNumber = 1
				left join #TempPriceSummary as h
				on a.ASXCode = h.ASXCode
				left join Transform.PosterList as i
				on a.ASXCode = i.ASXCode
				left join StockData.MedianTradeValue as j
				on a.ASXCode = j.ASXCode
				left join StockData.StockStatsHistoryPlusCurrent as l
				on a.ASXCode = l.ASXCode
				left join #TempBrokerReportList as m
				on a.ASXCode = m.ASXCode
				left join #TempBrokerReportListNeg as n
				on a.ASXCode = n.ASXCode
				left join #TempBrokerReportListLastNDay as m2
				on a.ASXCode = m2.ASXCode
				left join #TempBrokerReportListNegLastNDay as n2
				on a.ASXCode = n2.ASXCode
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
					where cast(AnnDateTime as date) = @dtDate
					and MarketSensitiveIndicator = 1
					group by ASXCode
				) as r
				on a.ASXCode = r.ASXCode
				left join ScanResults.StockStatsHistoryPlusCurrent as s
				on a.ASXCode = s.ASXCode
				left join
				(
					select 
						ASXCode,
						ObservationDate,
						DayRank,
						[Open],
						[High],
						[Low],
						[Close],
						[Volume]
					from #TempPriceSummaryHistory as a
					where DayRank = 2
				) as psh2
				on a.ASXCode = psh2.ASXCode
				left join
				(
					select 
						ASXCode,
						ObservationDate,
						DayRank,
						[Open],
						[High],
						[Low],
						[Close],
						[Volume]
					from #TempPriceSummaryHistory as a
					where DayRank = 3
				) as psh3
				on a.ASXCode = psh3.ASXCode
				left join #TempNextDayPrice as ndp
				on a.ASXCode = ndp.ASXCode
				left join #TempPrevDayPrice as pdp
				on a.ASXCode = pdp.ASXCode
				where 1 = 1
				and h.[High] > h.[Open]
				and 
				(
					cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.6
					or
					cast(j.MedianTradeValue as int) > 2000000
				)
				and a.AlertTypeScore >= 20
				order by Grade, a.AlertTypeScore desc, a.CreateDate desc
			end
			else
			begin
				if object_id(N'Tempdb.dbo.#TempScanResult') is not null
					drop table #TempScanResult

				select 
					a.ASXCode,
					a.AlertTypeName,
					a.CreateDate as AlertCreateDate,
					case when a.AlertTypeScore >= 50 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 3.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 2000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 1.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 3.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) and case when s.MovingAverage10d > 0 then cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) else null end < 30 then 1.1
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 2.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 700 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) and case when s.MovingAverage10d > 0 then cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) else null end < 30 then 2.5
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 3.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(j.MedianTradeValue as int) > 300 and case when s.MovingAverage10d > 0 then cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) else null end < 30 then 3.5
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(j.MedianTradeValue as int) > 1000 then 4.2
						 when a.AlertTypeScore >= 30 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 75 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) > 0 and (cast(j.MedianTradeValue as int) > 1000 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 8.2
						 when a.AlertTypeScore >= 25 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 500 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 6.2
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.4 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and (cast(j.MedianTradeValue as int) > 500 or cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int)) then 7.2
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1.25 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int) then 4.5
						 when a.AlertTypeScore >= 20 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 70 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.5 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.60 and case when h.PrevClose > 0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 and isnull(r.NoSensitiveNews, 0) = 0 and cast(h.[Value]/1000.0 as int) > cast(j.MedianTradeValue as int) then 7.5
						 when a.AlertTypeScore >= 50 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 3.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 then 3.0
						 when a.AlertTypeScore >= 50 and cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) >= 85 and cast(h.[Value]/1000.0 as int)*1.0/cast(j.MedianTradeValueDaily as int) >= 2.0 and cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end > 5 then 3.5					 
						 else 99
					end as Grade,
					case when a.AlertTypeScore >= 30 and h.[Volume] > psh2.[Volume] and psh2.[Volume] > psh3.[Volume] and psh3.Volume < h.[Volume]*0.55 and psh3.[close] >= (h.[Close] + h.[Open])/2.0 and psh3.[close] <= h.[Close] then 3.0
						 when a.AlertTypeScore >= 15 and h.[Volume] > psh2.[Volume] and psh2.[Volume] > psh3.[Volume] and psh3.Volume < h.[Volume]*0.55 and psh3.[close] >= (h.[Close] + h.[Open])/2.0 and psh3.[close] <= h.[High] then 5.0
						 else 99
					end as RetraceScore,
					e.IndustrySubGroup,
					cast(coalesce(b.SharesIssued*h.[Close]*1.0, c.MC) as decimal(8, 2)) as MC,
					cast(c.CashPosition as decimal(8, 2)) CashPosition,
					cast(h.[Value]/1000.0 as int) as [T/O in K],
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
					j.MedianPriceChangePerc as [MedianPriceChg],
					case when h.[Close] > 0 then cast(cast(pdp.PriceChangeVsPrevClose as decimal(20, 2)) as varchar(20)) else null end as PrevDayChangePerc,
					case when h.PrevClose >  0 then cast(cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) as varchar(20)) else null end as TodayChangePerc,
					cast(cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as varchar(20)) as [T/O Rate], 
					case when ndp.[Open] > 0 and h.[Close] > 0 then cast(cast((ndp.[Open] - h.[Close])*100.0/h.[Close] as decimal(20, 2)) as varchar(20)) else null end as NextDayOpenProfit,
					case when ndp.[Close] > 0 and h.[Close] > 0 then cast(cast((ndp.[Close] - h.[Close])*100.0/h.[Close] as decimal(20, 2)) as varchar(20)) else null end as NextDayCloseProfit,
					m.BrokerCode as ObservationDayTopBuyBroker,
					n.BrokerCode as ObservationDayTopSellBroker,
					m2.BrokerCode as RecentTopBuyBroker,
					n2.BrokerCode as RecentTopSellBroker,
					case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) else null end as VsMA5,
					case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) else null end as VsMA10,
					g.[AnnDescr],
					o.NoBuy,
					p.NoSigNotice as NoSig,
					q.WeekMonthPositive as [WkMon+],
					cast(d.MediumTermRetailParticipationRate as varchar(20)) as [MT Retail %],
					cast(d.ShortTermRetailParticipationRate as varchar(20)) as [ST Retail %],
					cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) as BarStrength,
					a.AlertTypeScore
				into #TempScanResult
				from #TempAlertHistoryAggregate as a
				left join StockData.v_CompanyFloatingShare as b
				on a.ASXCode = b.ASXCode
				left join #TempCashVsMC as c
				on a.ASXCode = c.ASXCode
				left join StockData.RetailParticipation as d
				on a.ASXCode = d.ASXCode
				left join StockData.CompanyInfo as e
				on a.ASXCode = e.ASXCode
				left join #TempAnnouncement as g
				on a.ASXCode = g.ASXCode
				and g.RowNumber = 1
				left join #TempPriceSummary as h
				on a.ASXCode = h.ASXCode
				left join Transform.PosterList as i
				on a.ASXCode = i.ASXCode
				left join StockData.MedianTradeValue as j
				on a.ASXCode = j.ASXCode
				left join StockData.StockStatsHistoryPlusCurrent as l
				on a.ASXCode = l.ASXCode
				left join #TempBrokerReportList as m
				on a.ASXCode = m.ASXCode
				left join #TempBrokerReportListNeg as n
				on a.ASXCode = n.ASXCode
				left join #TempBrokerReportListLastNDay as m2
				on a.ASXCode = m2.ASXCode
				left join #TempBrokerReportListNegLastNDay as n2
				on a.ASXCode = n2.ASXCode
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
					where cast(AnnDateTime as date) = @dtDate
					and MarketSensitiveIndicator = 1
					group by ASXCode
				) as r
				on a.ASXCode = r.ASXCode
				left join ScanResults.StockStatsHistoryPlusCurrent as s
				on a.ASXCode = s.ASXCode
				left join
				(
					select 
						ASXCode,
						ObservationDate,
						DayRank,
						[Open],
						[High],
						[Low],
						[Close],
						[Volume]
					from #TempPriceSummaryHistory as a
					where DayRank = 2
				) as psh2
				on a.ASXCode = psh2.ASXCode
				left join
				(
					select 
						ASXCode,
						ObservationDate,
						DayRank,
						[Open],
						[High],
						[Low],
						[Close],
						[Volume]
					from #TempPriceSummaryHistory as a
					where DayRank = 3
				) as psh3
				on a.ASXCode = psh3.ASXCode
				left join #TempNextDayPrice as ndp
				on a.ASXCode = ndp.ASXCode
				left join #TempPrevDayPrice as pdp
				on a.ASXCode = pdp.ASXCode
				where 1 = 1
				and h.[High] > h.[Open]
				and 
				(
					cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.6
					or
					cast(j.MedianTradeValue as int) > 2000000
				)
				and a.AlertTypeScore >= 20
				order by Grade, a.AlertTypeScore desc, a.CreateDate desc

				delete a
				from Transform.ScanResultHistory as a
				inner join #TempScanResult as b
				on a.AlertCreateDate = b.AlertCreateDate
				and a.ASXCode = b.ASXCode
				and a.AlertTypeName = b.AlertTypeName

				insert into Transform.ScanResultHistory
				(
				   [ASXCode]
				  ,[AlertTypeName]
				  ,[AlertCreateDate]
				  ,[Grade]
				  ,[RetraceScore]
				  ,[IndustrySubGroup]
				  ,[MC]
				  ,[CashPosition]
				  ,[T/O in K]
				  ,[MedianValue Wk]
				  ,[MedianValue Day]
				  ,[MedianPriceChg]
				  ,[PrevDayChangePerc]
				  ,[TodayChangePerc]
				  ,[T/O Rate]
				  ,[NextDayOpenProfit]
				  ,[NextDayCloseProfit]
				  ,[ObservationDayTopBuyBroker]
				  ,[ObservationDayTopSellBroker]
				  ,[RecentTopBuyBroker]
				  ,[RecentTopSellBroker]
				  ,[VsMA5]
				  ,[VsMA10]
				  ,[AnnDescr]
				  ,[NoBuy]
				  ,[NoSig]
				  ,[WkMon+]
				  ,[MT Retail %]
				  ,[ST Retail %]
				  ,[BarStrength]
				  ,[AlertTypeScore]
				)
				select
				   [ASXCode]
				  ,[AlertTypeName]
				  ,[AlertCreateDate]
				  ,[Grade]
				  ,[RetraceScore]
				  ,[IndustrySubGroup]
				  ,[MC]
				  ,[CashPosition]
				  ,[T/O in K]
				  ,[MedianValue Wk]
				  ,[MedianValue Day]
				  ,[MedianPriceChg]
				  ,[PrevDayChangePerc]
				  ,[TodayChangePerc]
				  ,[T/O Rate]
				  ,[NextDayOpenProfit]
				  ,[NextDayCloseProfit]
				  ,[ObservationDayTopBuyBroker]
				  ,[ObservationDayTopSellBroker]
				  ,[RecentTopBuyBroker]
				  ,[RecentTopSellBroker]
				  ,[VsMA5]
				  ,[VsMA10]
				  ,[AnnDescr]
				  ,[NoBuy]
				  ,[NoSig]
				  ,[WkMon+]
				  ,[MT Retail %]
				  ,[ST Retail %]
				  ,[BarStrength]
				  ,[AlertTypeScore]
				from #TempScanResult

			end
			
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
