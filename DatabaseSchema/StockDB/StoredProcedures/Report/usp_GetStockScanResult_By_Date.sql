-- Stored procedure: [Report].[usp_GetStockScanResult_By_Date]


CREATE PROCEDURE [Report].[usp_GetStockScanResult_By_Date]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSortBy as varchar(50) = 'Price Changes',
@pdtObservationDate as date
AS
SET NOCOUNT ON

BEGIN 
	IF @pintErrorNumber <> 0
	BEGIN
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
		declare @pintNumPrevDay as int
		SELECT @pintNumPrevDay = -1*Common.BusinessDayDiff(@pdtObservationDate, CAST(GETDATE() AS DATE))

		IF @pintNumPrevDay > 0
			SET @pintNumPrevDay = @pintNumPrevDay * -1
		ELSE
			SET @pintNumPrevDay = ABS(@pintNumPrevDay)

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtNextDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 1, getdate()) as date)
		declare @dtPrevDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 1, getdate()) as date)

		-- ==============================================================================
		-- 1. TempCashPosition
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null drop table #TempCashPosition

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
		
		CREATE CLUSTERED INDEX IX_TempCashPosition_ASXCode ON #TempCashPosition(ASXCode);


		-- ==============================================================================
		-- 2. TempCashVsMC
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		CREATE CLUSTERED INDEX IX_TempCashVsMC_ASXCode ON #TempCashVsMC(ASXCode);


		-- ==============================================================================
		-- 3. TempStockNature
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempStockNature') is not null drop table #TempStockNature

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

		CREATE CLUSTERED INDEX IX_TempStockNature_ASXCode ON #TempStockNature(ASXCode);


		-- ==============================================================================
		-- 4. TempAnnouncement
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempAnnouncement') is not null drop table #TempAnnouncement

		select 
			ASXCode,
			AnnDescr,
			AnnDateTime,
			row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
		into #TempAnnouncement
		from Transform.v_Announcement as x
		where cast(AnnDateTime as date) = @dtDate

		CREATE CLUSTERED INDEX IX_TempAnnouncement_ASXCode ON #TempAnnouncement(ASXCode);


		-- ==============================================================================
		-- 5. TempPriceSummary
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null drop table #TempPriceSummary

		select * into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtDate
		and DateTo is null

		-- Index immediately to help the delete/insert
		CREATE CLUSTERED INDEX IX_TempPriceSummary_ASXCode ON #TempPriceSummary(ASXCode);

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
			PriceSummaryID, ASXCode, [Open], [High], [Low], [Close], [PrevClose], [Volume], [Value], [VWAP], [Trades], DateFrom, ObservationDate, LastVerifiedDate, LatestForTheDay
		)
		select 
			-1 as PriceSummaryID, ASXCode, [Open], [High], [Low], [Close], [PrevClose], [Volume], [Value], [VWAP], [Trades], ObservationDate, ObservationDate, ObservationDate as LastVerifiedDate, 1 as LatestForTheDay
		from Transform.PriceHistory as a
		where not exists
		(
			select 1
			from #TempPriceSummary
			where ASXCode = a.ASXCode
		)
		and ObservationDate = @dtDate
		and Volume > 0;
		

		-- ==============================================================================
		-- 6. TempNextDayPrice & TempPrevDayPrice
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempNextDayPrice') is not null drop table #TempNextDayPrice

		select * into #TempNextDayPrice
		from StockData.PriceHistory
		where ObservationDate = @dtNextDate

		CREATE CLUSTERED INDEX IX_TempNextDayPrice_ASXCode ON #TempNextDayPrice(ASXCode);

		if object_id(N'Tempdb.dbo.#TempPrevDayPrice') is not null drop table #TempPrevDayPrice

		select * into #TempPrevDayPrice
		from Transform.PriceHistory
		where ObservationDate = @dtPrevDate

		CREATE CLUSTERED INDEX IX_TempPrevDayPrice_ASXCode ON #TempPrevDayPrice(ASXCode);


		-- ==============================================================================
		-- 7. TempAlertHistory & Aggregate
		-- ==============================================================================
		if object_id(N'Tempdb.dbo.#TempAlertHistory') is not null drop table #TempAlertHistory

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

		CREATE CLUSTERED INDEX IX_TempAlertHistory_ASXCode ON #TempAlertHistory(ASXCode, CreateDate);

		if object_id(N'Tempdb.dbo.#TempAlertHistoryAggregate') is not null drop table #TempAlertHistoryAggregate

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
		
		CREATE CLUSTERED INDEX IX_TempAlertHistoryAggregate_ASXCode ON #TempAlertHistoryAggregate(ASXCode);


		-- ================================================================================================
		-- SORTING LOGIC BLOCKS
		-- ================================================================================================

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
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.CurrBRDate = cast(@dtDate as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.CurrBRDate = cast(@dtDate as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtDate as date)
			and n2.NetBuySell = 'S'
			order by cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) desc
		end

		if @pvchSortBy = 'Price Changes'
		begin
			select top 500
				a.ASXCode,
				cast(PriceChangeVsPrevClose as decimal(20, 2)) as ChangePerc,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				g.[AnnDescr],
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				i.Poster
			from (
				select 
					ASXCode,
					'Simple' as AlertTypeName,
					99 as AlertTypeScore,
					ObservationDate as CreateDate,
					PriceChangeVsPrevClose
				from Transform.PriceHistory
				where 1 = 1
				and ObservationDate = @dtDate
				and PriceChangeVsPrevClose > 5
				and PriceChangeVsOpen > 0
				and [Value] > 200000
			) as a
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
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.CurrBRDate = cast(@dtDate as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.CurrBRDate = cast(@dtDate as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtDate as date)
			and n2.NetBuySell = 'S'
			order by cast(PriceChangeVsPrevClose as decimal(20, 2)) desc
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
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.CurrBRDate = cast(@dtDate as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.CurrBRDate = cast(@dtDate as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtDate as date)
			and n2.NetBuySell = 'S'
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
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.CurrBRDate = cast(@dtDate as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.CurrBRDate = cast(@dtDate as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtDate as date)
			and n2.NetBuySell = 'S'
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
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.CurrBRDate = cast(@dtDate as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.CurrBRDate = cast(@dtDate as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtDate as date)
			and n2.NetBuySell = 'S'
			order by a.CreateDate desc
		end

		----------------------------------------------------------------------------------
		-- FIXED SECTION: 'Alert Occurrence'
		----------------------------------------------------------------------------------
		if @pvchSortBy = 'Alert Occurrence'
		begin
			-- 1. Create Price Summary History
			if object_id(N'Tempdb.dbo.#TempPriceSummaryHistory') is not null drop table #TempPriceSummaryHistory

			select row_number() over (partition by ASXCode order by ObservationDate asc) as DayRank, *
			into #TempPriceSummaryHistory
			from #TempPriceSummary
			where ObservationDate >= @dtDate 
			and DateTo is null 
			and LatestForTheDay = 1
			
			CREATE CLUSTERED INDEX IX_TempPriceSummaryHistory_ASXCode ON #TempPriceSummaryHistory(ASXCode, DayRank);


			-- 2. Create Scan Result Output
			-- CHANGE: Removed "TOP 500" (we filter at the end).
			-- CHANGE: Removed invalid WHERE clauses using aliases ([T/O Rate], PrevDayChangePerc).
			if object_id(N'Tempdb.dbo.#TempScanResultOutput') is not null drop table #TempScanResultOutput

			select 
				a.ASXCode,
				a.AlertTypeName,
				a.CreateDate as AlertCreateDate,
				cast(99 as decimal(10, 1)) as Grade, -- Default Grade
				case when a.AlertTypeScore >= 30 and h.[Volume] > psh2.[Volume] and psh2.[Volume] > psh3.[Volume] and psh3.Volume < h.[Volume]*0.55 and psh3.[close] >= (h.[Close] + h.[Open])/2.0 and psh3.[close] <= h.[Close] then 3.0
						when a.AlertTypeScore >= 15 and h.[Volume] > psh2.[Volume] and psh2.[Volume] > psh3.[Volume] and psh3.Volume < h.[Volume]*0.55 and psh3.[close] >= (h.[Close] + h.[Open])/2.0 and psh3.[close] <= h.[High] then 5.0
						else 99
				end as RetraceScore,
				e.IndustrySubGroup,
				case when h.[High] - h.[Open] = 0 then null else cast((h.[Close] - h.[Open])*100.0/(h.[High] - h.[Open]) as int) end as BarStrength,
				ttsu.FriendlyNameList,
				cast(coalesce(b.SharesIssued*h.[Close]*1.0, c.MC) as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.Volume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as [T/O Rate],
				cast(h.[Value]/1000.0 as int) as [T/O in K],
				cast(j.MedianTradeValue as int) as [MedianValue Wk],
				cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
				cast(j.MedianPriceChangePerc as varchar(20)) + '%' as [MedianPriceChg],
				case when h.[Close] > 0 then cast(pdp.PriceChangeVsPrevClose as decimal(20, 2)) else null end as PrevDayChangePerc,
				case when h.PrevClose >  0 then cast((h.[Close] - h.PrevClose)*100.0/h.PrevClose as decimal(10, 2)) else null end as TodayChangePerc,
				case when ndp.[Open] > 0 and h.[Close] > 0 then cast((ndp.[Open] - h.[Close])*100.0/h.[Close] as decimal(20, 2)) else null end as NextDayOpenProfit,
				case when ndp.[Close] > 0 and h.[Close] > 0 then cast((ndp.[Close] - h.[Close])*100.0/h.[Close] as decimal(20, 2)) else null end as NextDayCloseProfit,
				m.BrokerCode as ObservationDayTopBuyBroker,
				n.BrokerCode as ObservationDayTopSellBroker,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				dibs.InstituteTradeValue,
				dibs.InstituteTradeValuePerc,
				dibs.AvgTradeValuePerc,
				format(dibs.InstituteBuyPerc, 'N1') as InstituteBuyPerc,
				format(dibs.RetailBuyPerc, 'N1') as RetailBuyPerc,
				dibs.InstituteBuyVWAP,
				dibs.RetailBuyVWAP,
				g.[AnnDescr],
				cast(d.MediumTermRetailParticipationRate as varchar(20)) + '%' as [MT Retail %],
				cast(d.ShortTermRetailParticipationRate as varchar(20)) + '%' as [ST Retail %],
				case when h.[Close] > plfm.MovingAverage100D and h.[Close] > plfm.MovingAverage50D then 1 else 0 end as AboveLongMA,
				case when plfm.MovingAverage100D >= plfm2.MovingAverage100D and plfm.MovingAverage50D >= plfm2.MovingAverage50D then 1 else 0 end TrendUpLongMA,
				a.AlertTypeScore,
				h.[Close]
			into #TempScanResultOutput
			from #TempAlertHistoryAggregate as a
			left join StockData.v_CompanyFloatingShare as b on a.ASXCode = b.ASXCode
			left join #TempCashVsMC as c on a.ASXCode = c.ASXCode
			left join StockData.RetailParticipation as d on a.ASXCode = d.ASXCode
			left join StockData.CompanyInfo as e on a.ASXCode = e.ASXCode
			left join #TempAnnouncement as g on a.ASXCode = g.ASXCode and g.RowNumber = 1
			left join #TempPriceSummary as h on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i on a.ASXCode = i.ASXCode
			left join StockData.MedianTradeValue as j on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l on a.ASXCode = l.ASXCode
			left join [Transform].[BrokerReportList] as m on a.ASXCode = m.ASXCode and m.LookBackNoDays = 0 and m.CurrBRDate = cast(@dtDate as date) and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n on a.ASXCode = n.ASXCode and n.LookBackNoDays = 0 and n.CurrBRDate = cast(@dtDate as date) and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2 on a.ASXCode = m2.ASXCode and m2.LookBackNoDays = 10 and m2.ObservationDate = cast(@dtDate as date) and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2 on a.ASXCode = n2.ASXCode and n2.LookBackNoDays = 10 and n2.ObservationDate = cast(@dtDate as date) and n2.NetBuySell = 'S'
			left join (select ASXCode, count(ASXCode) as NoBuy from StockData.DirectorBuyOnMarket group by ASXCode) as o on a.ASXCode = o.ASXCode
			left join (select ASXCode, count(ASXCode) as NoSigNotice from StockData.SignificantHolder group by ASXCode) as p on a.ASXCode = p.ASXCode
			left join (select ASXCode, sum(case when ASXCode is not null then 1 else 0 end) as WeekMonthPositive from StockData.WeeklyMonthlyPriceAction where CreateDate > Common.DateAddBusinessDay(-3, getdate()) group by ASXCode) as q on a.ASXCode = q.ASXCode
			left join (select ASXCode, count(ASXCode) as NoSensitiveNews from StockData.Announcement where cast(AnnDateTime as date) = @dtDate and MarketSensitiveIndicator = 1 group by ASXCode) as r on a.ASXCode = r.ASXCode
			left join ScanResults.StockStatsHistoryPlusCurrent as s on a.ASXCode = s.ASXCode
			left join (select ASXCode, ObservationDate, DayRank, [Open], [High], [Low], [Close], [Volume] from #TempPriceSummaryHistory as a where DayRank = 2) as psh2 on a.ASXCode = psh2.ASXCode
			left join (select ASXCode, ObservationDate, DayRank, [Open], [High], [Low], [Close], [Volume] from #TempPriceSummaryHistory as a where DayRank = 3) as psh3 on a.ASXCode = psh3.ASXCode
			left join #TempNextDayPrice as ndp on a.ASXCode = ndp.ASXCode
			left join #TempPrevDayPrice as pdp on a.ASXCode = pdp.ASXCode
			left join Transform.TTSymbolUser as ttsu on a.ASXCode = ttsu.ASXCode
			left join Transform.DailyInstituteBuySell as dibs on a.ASXCode = dibs.ASXCode and dibs.ObservationDate = @dtDate
			left join Transform.PriceSummaryLatestFutureMA as plfm on a.ASXCode = plfm.ASXCode and plfm.RowNumber = @pintNumPrevDay + 2
			left join Transform.PriceSummaryLatestFutureMA as plfm2 on a.ASXCode = plfm2.ASXCode and plfm2.RowNumber = @pintNumPrevDay + 3
			where 1 = 1
			and g.AnnDescr is null 
			
			-- 3. Index the Result Table (Crucial for the UPDATE speed)
			CREATE CLUSTERED INDEX IX_TempScanResultOutput_ASXCode ON #TempScanResultOutput(ASXCode);

			-- 4. Update the Grade
			-- Now that the table is created, we CAN reference [T/O Rate] and PrevDayChangePerc in the WHERE clause.
			update a
			set Grade = case when AlertTypeName like '%Gain Momentum%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 1.5
								when AlertTypeName like '%Gain Momentum%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 1.8
								when AlertTypeName like '%Fu Rong Chu Shui%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 2.1
								when AlertTypeName like '%High Volumn EMA Cross%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 2.1
								when AlertTypeName like '%Break Through%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 2.1
								when AlertTypeName like '%High Volume Up Simple%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 2.1
								when AlertTypeName like '%Fu Rong Chu Shui%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 2.3
								when AlertTypeName like '%High Volume Up Simple%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 2.3
								when AlertTypeName like '%High Volumn EMA Cross%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 2.3
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 2.3
								when AlertTypeName like '%Fu Rong Chu Shui%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 2.3
								when AlertTypeName like '%High Volume Up Simple%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 2.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 2.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 2.8
								when AlertTypeName like '%Breakaway Gap%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 2.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 2.8
								when AlertTypeName like '%Break Through%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 3.3
								when AlertTypeName like '%Break Through%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 3.3
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 3.3
								when AlertTypeName like '%High Volume Up Simple%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 3.3
								when AlertTypeName like '%Gain Momentum%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 3.3
								when AlertTypeName like '%Breakaway Gap%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 3.8
								when AlertTypeName like '%Breakaway Gap%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 3.8
								when AlertTypeName like '%Breakaway Gap%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 3.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 3.8
								when AlertTypeName like '%Gain Momentum%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 3.8
								when AlertTypeName like '%Break Through%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 4.3
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 4.3
								when AlertTypeName like '%High Volumn EMA Cross%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 4.3
								when AlertTypeName like '%High Volumn EMA Cross%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 4.3
								when AlertTypeName like '%Fu Rong Chu Shui%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 4.3
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('a. 0 - 20M') then 4.8
								when AlertTypeName like '%High Volume Up Simple%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 4.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 4.8
								when AlertTypeName like '%Breakaway Gap%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('b. 20 - 50M') then 4.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 4.8
								when AlertTypeName like '%Gain Momentum%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 5.3
								when AlertTypeName like '%High Volumn EMA Cross%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('e. 300 - 1000M') then 5.3
								when AlertTypeName like '%Breakaway Gap%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 5.3
								when AlertTypeName like '%High Volumn EMA Cross%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('c. 50 - 100M') then 5.3
								when AlertTypeName like '%Break Through%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('d. 100 - 300M') then 5.3
								when AlertTypeName like '%Break Through%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 5.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 5.8
								when AlertTypeName like '%Fu Rong Chu Shui%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 5.8
								when AlertTypeName like '%High Volume Up Simple%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 5.8
								when AlertTypeName like '%Breakthrough Trading Range%' and case when MC < 20 then 'a. 0 - 20M' when MC >= 20 and MC < 50 then 'b. 20 - 50M' when MC >= 50 and MC < 100 then 'c. 50 - 100M' when MC >= 100 and MC < 300 then 'd. 100 - 300M' when MC >= 300 and MC < 1000 then 'e. 300 - 1000M' when MC >= 1000 then 'f. 1B+' end in ('f. 1B+') then 5.8
						else 50
						end 
			from #TempScanResultOutput as a
			where 1= 1
			and
				case when MC < 20 and [T/O Rate] >= 1.5 then 1
					when MC >= 20 and MC < 50 and [T/O Rate] >= 1.2 then 1
					when MC >= 50 and MC < 100 and [T/O Rate] >= 1.0 then 1
					when MC >= 100 and MC < 300 and [T/O Rate] >= 1.0 then 1
					when MC >= 300 and MC < 1000 and [T/O Rate] >= 1.0 then 1
					when MC >= 1000 and [T/O Rate] >= 0.9 then 1
				end = 1
			and [T/O Rate] < 10.0
			and PrevDayChangePerc < 5.0
			and AnnDescr is null


			-- 5. Final Selection (TOP 500 applied HERE)
			select top 500
				a.[ASXCode]
				,[AlertTypeName]
				,[AlertCreateDate]
				,[Grade]
				,[RetraceScore]
				,case when AboveLongMA = 1 and TrendUpLongMA = 1 and [T/O Rate] between 0.85 and 8 and [TodayChangePerc] >= 20 then 'Buy limit at half bar' 
					when AboveLongMA = 1 and TrendUpLongMA = 1 and [T/O Rate] between 0.85 and 8 and [TodayChangePerc] < 20 then 'Buy market at close'
					else ''
				end as [BuyStrategyName]
				,[NextDayOpenProfit]
				,AboveLongMA
				,TrendUpLongMA
				,[IndustrySubGroup]
				,[BarStrength]
				,[FriendlyNameList]
				,[MC]
				,[CashPosition]
				,cast([T/O Rate] as varchar(50)) + '%' as [T/O Rate]
				,format([T/O in K], 'N0') as [T/O in K]
				,[MedianValue Wk]
				,[MedianValue Day]
				,[MedianPriceChg]
				,[AnnDescr]
				,[PrevDayChangePerc]
				,[TodayChangePerc]
				,[ObservationDayTopBuyBroker]
				,[ObservationDayTopSellBroker]
				,[RecentTopBuyBroker]
				,[RecentTopSellBroker]
				,[NextDayCloseProfit]
				,InstituteTradeValue
				,InstituteTradeValuePerc
				,AvgTradeValuePerc
				,InstituteBuyPerc
				,RetailBuyPerc
				,InstituteBuyVWAP
				,RetailBuyVWAP
				,[MT Retail %]
				,[ST Retail %]
				,[AlertTypeScore]
				,[Close]
			from #TempScanResultOutput as a
			where a.[Close] > 0.01
			and a.[Close] < 10
			and [T/O in K] > 400
			and BarStrength >= 60
			order by 
				case when AboveLongMA = 1 and TrendUpLongMA = 1 then 1 else 0 end desc,
				[T/O Rate] desc,
				case when BarStrength >= 75 then 1 else 0 end desc, 
				case when [T/O Rate] > 0.8 then 1 else 0 end desc, 
				AlertTypeScore desc, 
				Grade, 
				AlertCreateDate desc
			
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

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END

	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END