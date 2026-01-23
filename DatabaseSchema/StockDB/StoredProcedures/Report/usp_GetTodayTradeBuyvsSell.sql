-- Stored procedure: [Report].[usp_GetTodayTradeBuyvsSell]


CREATE PROCEDURE [Report].[usp_GetTodayTradeBuyvsSell]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0,
@pvchSortBy as varchar(200) = 'BuyvsMC',
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_GetTodayTradeBuyvsSell.sql
Stored Procedure Name: usp_GetTodayTradeBuyvsSell
Overview
-----------------
usp_GetTodayTradeBuyvsSell

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
Date:		2018-06-26
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTodayTradeBuyvsSell'
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

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtMaxDateStockStatsHistoryPlus as date
		select @dtMaxDateStockStatsHistoryPlus = max(ObservationDate)
		from StockData.StockStatsHistoryPlus
		where ObservationDate < @dtDate

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
		right join StockData.CompanyInfo as b with(nolock)
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			UniqueKey int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[VWAP] decimal(20, 4),
			[PrevClose] decimal(20, 4),
			[Value] decimal(20, 4),
			DateFrom datetime
		)

		if object_id(N'Tempdb.dbo.#Temp_StockPreMarketMatchVolume') is not null
			drop table #Temp_StockPreMarketMatchVolume

		select * 
		into #Temp_StockPreMarketMatchVolume
		from Transform.StockPreMarketMatchVolume with(nolock)
		where ObservationDate < @dtDate
		and ObservationDate >= Common.DateAddBusinessDay(-8, @dtDate)
		order by ObservationDate desc;

		if object_id(N'Tempdb.dbo.#TempMatchVolumeRatioLastNDay') is not null
			drop table #TempMatchVolumeRatioLastNDay

		select distinct x.ASXCode, stuff((
			select top 8 ',' + cast([MatchVolumeOutOfFreeFloat] as varchar(20))
			from #Temp_StockPreMarketMatchVolume as a
			where x.ASXCode = a.ASXCode
			order by ObservationDate desc
			for xml path('')), 1, 1, ''
		) as [MatchVolumeOutOfFreeFloatList]
		into #TempMatchVolumeRatioLastNDay
		from #Temp_StockPreMarketMatchVolume as x
		where MatchVolumeOutOfFreeFloat is not null

		if @pintNumPrevDay = 0
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose],
				[Value],
				DateFrom
			)
			select 
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose],
				[Value],
				DateFrom
			from
			(
				select a.ASXCode, a.[Open], a.[Close], a.[VWAP], a.[PrevClose] as PrevClose, [Value], a.DateFrom, row_number() over (partition by a.ASXCode order by a.DateFrom desc) as RowNumber
				from StockData.PriceSummaryToday as a with(nolock)
				--inner join StockData.PriceHistoryCurrent as b
				--on a.ASXCode = b.ASXCode
				where ObservationDate = @dtDate
				and LatestForTheDay = 1
				and DateTo is null
			) as a
			where RowNumber = 1

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[VWAP],
				[PrevClose],
				[Value],
				DateFrom 
			)
			select a.ASXCode, a.[Open], a.[Close], a.[VWAP], a.[PrevClose] as PrevClose, [Value], a.DateFrom
			from StockData.PriceSummary as a with(nolock)
			--inner join StockData.PriceHistoryCurrent as b
			--on a.ASXCode = b.ASXCode
			where ObservationDate = @dtDate
			and LatestForTheDay = 1
			and DateTo is null
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
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
				[PrevClose],
				[Value],
				DateFrom  
			)
			select a.ASXCode, a.[Open], a.[Close], a.VWAP, a.[PrevClose] as PrevClose, [Value], a.DateFrom
			from StockData.PriceSummary as a with(nolock)
			where ObservationDate = @dtDate
			and LatestForTheDay = 1

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				[Value],
				DateFrom
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				Volume*[Close] as [Value],
				CreateDate as DateFrom
			from StockData.StockStatsHistoryPlus as a with(nolock)
			where ObservationDate = @dtDate			
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ObservationDate = a.ObservationDate
				and ASXCode = a.ASXCode
			)
		end

		delete a
		from #TempPriceSummary as a
		where PrevClose = 0

		delete a
		from #TempPriceSummary as a
		inner join
		(
			select
				UniqueKey,
				row_number() over (partition by ASXCode order by DateFrom desc, UniqueKey asc) as RowNumber
			from #TempPriceSummary
		) as b
		on a.UniqueKey = b.UniqueKey
		where RowNumber > 1

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
		from StockData.StockNature as a with(nolock)
		group by a.ASXCode
		
		if object_id(N'Tempdb.dbo.#TempTodayTrade') is not null
			drop table #TempTodayTrade
		
		select 
			ASXCode, 
			ObservationDate as CurrentDate,
			isnull(BuySellInd, 'U') as BuySellInd, 
			sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
			sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
			avg(VWAP)*100.0 as VWAP 
		into #TempTodayTrade
		from StockData.PriceSummary with(nolock)
		where ObservationDate = @dtDate
		and VWAP > 0
		group by ASXCode, ObservationDate, BuySellInd
		union all
		select 
			ASXCode, 
			ObservationDate as CurrentDate,
			isnull(BuySellInd, 'U') as BuySellInd, 
			sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
			sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
			avg(VWAP)*100.0 as VWAP 
		from StockData.PriceSummaryToday with(nolock)
		where ObservationDate = @dtDate
		and VWAP > 0
		group by ASXCode, ObservationDate, BuySellInd

		if object_id(N'Tempdb.dbo.#TempAvgVolume') is not null
			drop table #TempAvgVolume

		select ASXCode, avg(Volume) as AvgVolume
		into #TempAvgVolume
		from
		(
			select ASXCode, Volume, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from StockData.PriceHistory with(nolock)
			where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 20, getdate()) as date)
			and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
			and Volume > 0
		) as a
		where RowNumber <= 2
		group by ASXCode

		if object_id(N'Tempdb.dbo.#TempMaxVWAPClose') is not null
			drop table #TempMaxVWAPClose

		select ASXCode, max(VWAP) as MaxVWAP, max([Close]) as MaxClose
		into #TempMaxVWAPClose
		from StockData.v_PriceSummary_Latest with(nolock)
		where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 60, getdate()) as date)
		and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		--and Volume > 0
		group by ASXCode
			
		if object_id(N'Tempdb.dbo.#TempMaxVolume') is not null
			drop table #TempMaxVolume

		select ASXCode, max(Volume) as MaxVolume
		into #TempMaxVolume
		from StockData.v_PriceSummary_Latest with(nolock)
		where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 3, getdate()) as date)
		and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		and Volume > 0
		group by ASXCode
			
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
			) as [SearchTerm],
			row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
		into #TempAnnouncement
		from StockData.Announcement as x with(nolock)
		where cast(AnnDateTime as date) = @dtDate

		if object_id(N'Tempdb.dbo.#TempTodayTradeBuyvsSell') is not null
			drop table #TempTodayTradeBuyvsSell

		select 
			a.ASXCode, 
			cast(a.CurrentDate as date) as CurrentDate, 
			cast(a.TradeValue/1000.0 as int) as BuyTradeValue, 
			cast(b.TradeValue/1000.0 as int) as SellTradeValue, 
			t.TradeVolume,
			case when h.VWAP > 0 then cast(cast((h.[Close] - h.VWAP)*100.0/h.VWAP as decimal(10, 2)) as varchar(20)) + '%' else null end as CloseVsVWAP,
			case when h.[Open] > 0 then cast(cast((h.[Close] - h.[Open])*100.0/h.[Open] as decimal(10, 2)) as varchar(20)) + '%' else null end as CloseVsOpen,
			cast(h.VWAP as decimal(20, 4)) as VWAP, 
			case when b.TradeValue > 0 then cast(a.TradeValue*100.0/b.TradeValue as decimal(20, 2)) else null end as BuyVsSell,
			c.MC,
			c.CashPosition,
			case when c.MC > 0 then a.TradeValue*100.0/(c.MC*1000000) else null end as BuyVsMC,
			d.Poster,
			f.AnnDescr,
			f.[SearchTerm],
			g.MovingAverage5d as MovingAverage5d,
			g.MovingAverage10d as MovingAverage10d,
			g.MovingAverage30d as MovingAverage30d,
			g.MovingAverage60d as MovingAverage60d,
			case when g.MovingAverage5d > 0 then cast(cast((h.[Close] - g.MovingAverage5d)*100.0/g.MovingAverage5d as decimal(10, 1)) as varchar(20)) else null end as VsMA5,
			case when g.MovingAverage10d > 0 then cast(cast((h.[Close] - g.MovingAverage10d)*100.0/g.MovingAverage10d as decimal(10, 1)) as varchar(20)) else null end as VsMA10,
			cast(g.MovingAverage10dVol as decimal(20, 2)) as MovingAverage10dVol,
			case when g.MovingAverage10dVol = 0 then 0 else cast(t.TradeVolume*100.0/g.MovingAverage10dVol as decimal(20, 2)) end VolumeVsAvg10,
			cast(g.MovingAverage120dVol as decimal(20, 2)) as MovingAverage120dVol,
			case when g.MovingAverage120dVol = 0 then 0 else cast(t.TradeVolume*100.0/g.MovingAverage120dVol as decimal(20, 2)) end VolumeVsAvg120,
			g.MaxClose20d,
			g.MinClose20d,
			g.TrendMovingAverage60d,
			g.TrendMovingAverage200d,
			e.Nature,
			cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) as ChangePerc,
			@pintNumPrevDay as [NumPrevDay],
			h.[Close] as [Close]
		into #TempTodayTradeBuyvsSell
		from #TempTodayTrade as a
		inner join #TempTodayTrade as b
		on a.ASXCode = b.ASXCode
		and a.CurrentDate = b.CurrentDate
		and a.BuySellInd = 'B'
		and b.BuySellInd = 'S'
		inner join 
		(
			select ASXCode, CurrentDate, sum(TradeVolume) as TradeVolume
			from #TempTodayTrade
			group by ASXCode, CurrentDate
		) as t
		on a.ASXCode = t.ASXCode
		and a.CurrentDate = t.CurrentDate
		left join Transform.CashVsMC as c
		on a.ASXCode = c.ASXCode
		left join Transform.PosterList as d
		on a.ASXCode = d.ASXCode
		left join Transform.TempStockNature as e
		on a.ASXCode = e.ASXCode
		left join #TempAnnouncement as f
		on a.ASXCode = f.ASXCode
		and f.RowNumber = 1
		left join StockData.v_StockStatsHistoryPlusCurrent as g with(nolock)
		on a.ASXCode = g.ASXCode
		left join #TempPriceSummary as h
		on a.ASXCode = h.ASXCode
		where 1 = 1
		--and b.TradeValue > 0
		--and a.TradeValue > 60000
		order by isnull(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end, 0) desc

		if @pvchSortBy = 'BuyvsMC'
		begin
			if @pbitASXCodeOnly = 0
			begin
				select 
				   a.[ASXCode]
				  ,[CurrentDate]
				  ,[ChangePerc]
				  ,cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as ChangeRate
				  ,CloseVsVWAP
				  ,CloseVsOpen
				  ,[BuyTradeValue]
				  ,[SellTradeValue]
				  ,[TradeVolume]
				  ,[VWAP]
				  ,[BuyVsSell]
				  ,dibs.InstituteTradeValue
				  ,dibs.InstituteTradeValuePerc
				  ,dibs.AvgTradeValuePerc
				  ,format(dibs.InstituteBuyPerc, 'N1') as InstituteBuyPerc
				  ,format(dibs.RetailBuyPerc, 'N1') as RetailBuyPerc
				  ,dibs.InstituteBuyVWAP
				  ,dibs.RetailBuyVWAP
				  ,ttsu.FriendlyNameList
				  ,m.BrokerCode as ObservationDateTopBuyBroker
				  ,n.BrokerCode as ObservationDateTopSellBroker
				  ,m2.BrokerCode as RecentTopBuyBroker
				  ,n2.BrokerCode as RecentTopSellBroker
				  ,b.[MC]
				  ,[CashPosition]
				  ,format(MedianTradeValue, 'N0') as MedianTradeValue
				  ,[BuyVsMC]
				  --,a.TrendMovingAverage60d
				  --,a.TrendMovingAverage200d
				  --,[Poster]
				  ,[AnnDescr]
				  --,[SearchTerm]
				  --,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
				  --,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
				  --,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
				  ,[Nature]
				  ,[NumPrevDay]
				  ,a.[Close]
				  ,cast(case when a.[Close] > sshp.MaxClose480d then 1 else 0 end as bit) as MaxClose480d
				  ,cast(case when a.[Close] > sshp.MaxClose360d then 1 else 0 end as bit) as MaxClose360d
				  ,cast(case when a.[Close] > sshp.MaxClose240d then 1 else 0 end as bit) as MaxClose240d
				from #TempTodayTradeBuyvsSell as a
				left join StockData.v_CompanyFloatingShare as b
				on a.ASXCode = b.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue from StockData.MedianTradeValue
				) as h
				on a.ASXCode = h.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on a.ASXCode = ttsu.ASXCode
				left join [Transform].[BrokerReportList] as m
				on a.ASXCode = m.ASXCode
				and m.LookBackNoDays = 0
				and m.CurrBRDate = a.CurrentDate
				and m.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n
				on a.ASXCode = n.ASXCode
				and n.LookBackNoDays = 0
				and n.CurrBRDate = a.CurrentDate
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
				left join Transform.DailyInstituteBuySell as dibs
				on a.ASXCode = dibs.ASXCode
				and dibs.ObservationDate = @dtDate
				left join StockData.StockStatsHistoryPlus as sshp
				on a.ASXCode = SSHP.ASXCode
				and sshp.ObservationDate = @dtMaxDateStockStatsHistoryPlus
				where NumPrevDay = @pintNumPrevDay
				--and cast(replace(CloseVsVWAP, '%', '') as decimal(20, 2)) >= 0
				--and cast(replace(CloseVsOpen, '%', '') as decimal(20, 2)) > 0
				--and [BuyTradeValue] + [SellTradeValue] > 300
				--and ([BuyTradeValue] + [SellTradeValue] > 500 or cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.8)
				--and isnull(b.[MC], 100) < 1000
				and TradeVolume*VWAP/1000.0 > 500
				and [ChangePerc] >= 4.5
				order by 
				    cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) desc,
					[ChangePerc] desc,
					case when cast(replace(replace(CloseVsOpen, '%', ''), ',', '') as decimal(10, 2)) > 0 then 1 else 0 end desc,
				    cast(case when a.[Close] > sshp.MaxClose480d then 1 else 0 end as bit) desc,
				    cast(case when a.[Close] > sshp.MaxClose360d then 1 else 0 end as bit) desc,
				    cast(case when a.[Close] > sshp.MaxClose240d then 1 else 0 end as bit) desc
					--cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) desc
					--case when dibs.InstituteBuyVWAP < a.[Close] and ChangePerc > 0 then 1 else 0 end desc,
					--case when dibs.InstituteTradeValuePerc > 0.95*dibs.AvgTradeValuePerc then 1 else 0 end desc,
					--case when InstituteBuyPerc > 1.05*RetailBuyPerc then 1 else 0 end desc,
					--case when dibs.InstituteBuyVWAP > dibs.RetailBuyVWAP then 1 else 0 end desc,
					--BuyVsMC desc
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
					   a.[ASXCode]
					  ,[CurrentDate]
					  ,[ChangePerc]
					  ,cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as ChangeRate
					  ,CloseVsVWAP
					  ,CloseVsOpen
					  ,cast(case when a.[Close] > sshp.MaxClose480d then 1 else 0 end as bit) as MaxClose480d
					  ,cast(case when a.[Close] > sshp.MaxClose360d then 1 else 0 end as bit) as MaxClose360d
					  ,cast(case when a.[Close] > sshp.MaxClose240d then 1 else 0 end as bit) as MaxClose240d
					  ,[BuyTradeValue]
					  ,[SellTradeValue]
					  ,[TradeVolume]
					  ,[VWAP]
					  ,[BuyVsSell]
					  ,b.[MC]
					  ,[CashPosition]
					  ,format(MedianTradeValue, 'N0') as MedianTradeValue
					  ,[BuyVsMC]
					  ,a.TrendMovingAverage60d
					  ,a.TrendMovingAverage200d
					  ,[Poster]
					  ,[AnnDescr]
					  --,[SearchTerm]
					  --,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
					  --,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
					  --,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
					  ,[Nature]
					  ,[NumPrevDay]
					from #TempTodayTradeBuyvsSell as a
					left join StockData.v_CompanyFloatingShare as b
					on a.ASXCode = b.ASXCode
					left join 
					(
						select ASXCode, MedianTradeValue from StockData.MedianTradeValue
					) as h
					on a.ASXCode = h.ASXCode
					left join StockData.StockStatsHistoryPlus as sshp
					on a.ASXCode = SSHP.ASXCode
					and sshp.ObservationDate = @dtMaxDateStockStatsHistoryPlus
					where NumPrevDay = @pintNumPrevDay
					and cast(replace(CloseVsVWAP, '%', '') as decimal(20, 2)) > 0
					and cast(replace(CloseVsOpen, '%', '') as decimal(20, 2)) > 0
					and [BuyTradeValue] + [SellTradeValue] > 500
				) as x
				order by
					case when cast(replace(replace(CloseVsOpen, '%', ''), ',', '') as decimal(10, 2)) > 0 then 1 else 0 end desc,
				    MaxClose480d desc,
				    MaxClose360d desc,
				    MaxClose240d desc,
					ChangeRate desc

				delete a
				from #TempOutput as a
				where DisplayOrder > 50

				select
					distinct
					ASXCode,
					DisplayOrder,
					CurrentDate as ObservationDate,
					OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + @pvchSortBy as ReportProc
				from #TempOutput

			end
		end

		if @pvchSortBy = 'BuyvsSell'
		begin
			select 
				a.[ASXCode]
				,[CurrentDate]
				,[ChangePerc]
				,cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as ChangeRate
				,CloseVsVWAP
				,CloseVsOpen
				,[BuyTradeValue]
				,[SellTradeValue]
				,[TradeVolume]
				,[VWAP]
				,[BuyVsSell]
				,ttsu.FriendlyNameList
				,m.BrokerCode as TopBuyBroker
				,n.BrokerCode as TopSellBroker
				,m2.BrokerCode as RecentTopBuyBroker
				,n2.BrokerCode as RecentTopSellBroker
				,b.[MC]
				,[CashPosition]
				,format(MedianTradeValue, 'N0') as MedianTradeValue
				,[BuyVsMC]
				,a.TrendMovingAverage60d
				,a.TrendMovingAverage200d
				,[Poster]
				,[AnnDescr]
				--,[SearchTerm]
				--,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
				--,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
				--,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
				,[Nature]
				,[NumPrevDay]
			from #TempTodayTradeBuyvsSell as a
			left join StockData.v_CompanyFloatingShare as b
			on a.ASXCode = b.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
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
			where NumPrevDay = @pintNumPrevDay
			and cast(replace(CloseVsVWAP, '%', '') as decimal(20, 2)) > 0
			and cast(replace(CloseVsOpen, '%', '') as decimal(20, 2)) > 0
			and [BuyTradeValue] + [SellTradeValue] > 500
			order by BuyVsSell desc
		end

		if @pvchSortBy = 'BuyvsSell Reverse'
		begin
			select 
				a.[ASXCode]
				,[CurrentDate]
				,[ChangePerc]
				,cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as ChangeRate
				,CloseVsVWAP
				,CloseVsOpen
				,[BuyTradeValue]
				,[SellTradeValue]
				,[TradeVolume]
				,[VWAP]
				,[BuyVsSell]
				,ttsu.FriendlyNameList
				,m.BrokerCode as TopBuyBroker
				,n.BrokerCode as TopSellBroker
				,m2.BrokerCode as RecentTopBuyBroker
				,n2.BrokerCode as RecentTopSellBroker
				,b.[MC]
				,[CashPosition]
				,format(MedianTradeValue, 'N0') as MedianTradeValue
				--,[BuyVsMC]
				,a.TrendMovingAverage60d
				,a.TrendMovingAverage200d
				,[Poster]
				,[AnnDescr]
				--,[SearchTerm]
				--,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
				--,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
				--,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
				,[Nature]
				,[NumPrevDay]
			from #TempTodayTradeBuyvsSell as a
			left join StockData.v_CompanyFloatingShare as b
			on a.ASXCode = b.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
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
			where NumPrevDay = @pintNumPrevDay
			and cast(replace(CloseVsVWAP, '%', '') as decimal(20, 2)) > 0
			and cast(replace(CloseVsOpen, '%', '') as decimal(20, 2)) > 0
			and [BuyTradeValue] + [SellTradeValue] > 500
			order by BuyVsSell asc
		end

		if @pvchSortBy = 'TotalTradeValuevsMC'
		begin
			select 
				a.[ASXCode]
				,[CurrentDate]
				,[ChangePerc]
				,cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as ChangeRate
				,CloseVsVWAP
				,CloseVsOpen
				,[BuyTradeValue]
				,[SellTradeValue]
				,[TradeVolume]
				,[VWAP]
				,[BuyVsSell]
				,ttsu.FriendlyNameList
				,m.BrokerCode as TopBuyBroker
				,n.BrokerCode as TopSellBroker
				,m2.BrokerCode as RecentTopBuyBroker
				,n2.BrokerCode as RecentTopSellBroker
				,b.[MC]
				,[CashPosition]
				,format(MedianTradeValue, 'N0') as MedianTradeValue
				--,[BuyVsMC]
				,a.TrendMovingAverage60d
				,a.TrendMovingAverage200d
				,[Poster]
				,[AnnDescr]
				--,[SearchTerm]
				--,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
				--,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
				--,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
				,[Nature]
				,[NumPrevDay]
			from #TempTodayTradeBuyvsSell as a
			left join StockData.v_CompanyFloatingShare as b
			on a.ASXCode = b.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
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
			where NumPrevDay = @pintNumPrevDay
			and cast(replace(CloseVsVWAP, '%', '') as decimal(20, 2)) > 0
			--and cast(replace(CloseVsOpen, '%', '') as decimal(20, 2)) > 0
			and [BuyTradeValue] + [SellTradeValue] > 500
			and isnull(b.[MC], 100) < 1000
			order by VWAP*TradeVolume*1.0/b.MC desc
		end

		if @pvchSortBy = 'BuyTradeValue'
		begin
				select 
				   a.[ASXCode]
				  ,[CurrentDate]
				  ,[ChangePerc]
				  ,cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as ChangeRate
				  ,CloseVsVWAP
				  ,CloseVsOpen
				  ,[BuyTradeValue]
				  ,[SellTradeValue]
				  ,[TradeVolume]
				  ,[VWAP]
				  ,[BuyVsSell]
				  ,dibs.InstituteTradeValue
				  ,dibs.InstituteTradeValuePerc
				  ,dibs.AvgTradeValuePerc
				  ,format(dibs.InstituteBuyPerc, 'N1') as InstituteBuyPerc
				  ,format(dibs.RetailBuyPerc, 'N1') as RetailBuyPerc
				  ,dibs.InstituteBuyVWAP
				  ,dibs.RetailBuyVWAP
				  ,ttsu.FriendlyNameList
				  ,m.BrokerCode as ObservationDateTopBuyBroker
				  ,n.BrokerCode as ObservationDateTopSellBroker
				  ,m2.BrokerCode as RecentTopBuyBroker
				  ,n2.BrokerCode as RecentTopSellBroker
				  ,b.[MC]
				  ,[CashPosition]
				  ,format(MedianTradeValue, 'N0') as MedianTradeValue
				  ,[BuyVsMC]
				  --,a.TrendMovingAverage60d
				  --,a.TrendMovingAverage200d
				  --,[Poster]
				  ,[AnnDescr]
				  --,[SearchTerm]
				  --,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
				  --,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
				  --,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
				  ,[Nature]
				  ,[NumPrevDay]
				  ,a.[Close]
				from #TempTodayTradeBuyvsSell as a
				left join StockData.v_CompanyFloatingShare as b
				on a.ASXCode = b.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue from StockData.MedianTradeValue
				) as h
				on a.ASXCode = h.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on a.ASXCode = ttsu.ASXCode
				left join [Transform].[BrokerReportList] as m
				on a.ASXCode = m.ASXCode
				and m.LookBackNoDays = 0
				and m.CurrBRDate = a.CurrentDate
				and m.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n
				on a.ASXCode = n.ASXCode
				and n.LookBackNoDays = 0
				and n.CurrBRDate = a.CurrentDate
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
				left join Transform.DailyInstituteBuySell as dibs
				on a.ASXCode = dibs.ASXCode
				and dibs.ObservationDate = @dtDate
				left join #TempMaxVWAPClose as mvc
				on a.ASXCode = mvc.ASXCode
				left join #TempMaxVolume as mv
				on a.ASXCode = mv.ASXCode
				where NumPrevDay = @pintNumPrevDay
				--and cast(replace(CloseVsVWAP, '%', '') as decimal(20, 2)) >= 0
				--and cast(replace(CloseVsOpen, '%', '') as decimal(20, 2)) > 0
				and ([BuyTradeValue] + [SellTradeValue] > 500 or cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.8)
				and isnull(b.[MC], 100) < 1000
				and a.[Close] > mvc.MaxVWAP
				and [ChangePerc] > 0
				and a.TradeVolume > mv.MaxVolume
				order by cast(a.TradeVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) desc
					
		end
				
		if @pvchSortBy = 'ASXCode'
		begin
			select 
			   a.[ASXCode]
			  ,[CurrentDate]
			  ,[ChangePerc]
			  ,[BuyTradeValue]
			  ,[SellTradeValue]
			  ,[TradeVolume]
			  ,[VWAP]
			  ,[BuyVsSell]
			  ,[MC]
			  ,[CashPosition]
			  ,format(MedianTradeValue, 'N0') as MedianTradeValue
			  --,[BuyVsMC]
		      ,a.TrendMovingAverage60d
			  ,a.TrendMovingAverage200d
			  ,[Poster]
			  ,[AnnDescr]
			  --,case when a.VWAP/100.0 > i.ExpMovingAverage30d then 1 else 0 end as PriceAboveEMA30
			  --,case when a.VWAP/100.0 > i.MovingAverage200d then 1 else 0 end as PriceAboveSMA200
			  --,case when i.ExpMovingAverage30d > i.ExpMovingAverage50d then 1 else 0 end as EMA30AboveEMA50
			  ,[Nature]
			  ,[NumPrevDay]
			from #TempTodayTradeBuyvsSell as a
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue		
			) as h
			on a.ASXCode = h.ASXCode
			where NumPrevDay = @pintNumPrevDay
			order by ASXCode asc
		end

		if @pvchSortBy = 'Price Increase 50% last 20 days'
		begin
			select 
			   a.[ASXCode],
			   b.ObservationDate as StartObservationDate,
			   a.ObservationDate as EndObservationDate,
			   a.[Close] as EndClose,
			   b.[Close] as StartClose,
			   cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			   cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) as [EndWeekTradeValue(M)],
			   y.MC,
			   y.CashPosition,
			   d.Nature,
			   i.Poster
			from StockData.StockStatsHistoryPlus as a
			inner join StockData.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.[Close] >= 1.5 * b.[Close]
			and a.[Close] > 0
			and b.[Close] > 0
			and a.DateSeqReverse = @pintNumPrevDay + 1
			and b.DateSeqReverse = @pintNumPrevDay + 20 + 1
			left join #TempCashVsMC as y
			on a.ASXCode = y.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join StockData.PriceHistoryWeekly as x
			on a.ObservationDate >= x.WeekOpenDate
			and a.ObservationDate <= x.WeekCloseDate
			and a.ASXCode = x.ASXCode
			where 1 = 1
			and a.[Close] > 0.03
			and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
			order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 

		end

		if @pvchSortBy = 'Price Increase 100% last 90 days'
		begin
			select 
			   a.[ASXCode],
			   b.ObservationDate as StartObservationDate,
			   a.ObservationDate as EndObservationDate,
			   a.[Close] as EndClose,
			   b.[Close] as StartClose,
			   cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			   cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) as [EndWeekTradeValue(M)],
			   y.MC,
			   y.CashPosition,
			   d.Nature,
			   i.Poster
			from StockData.StockStatsHistoryPlus as a
			inner join StockData.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.[Close] >= 2.0 * b.[Close]
			and a.[Close] > 0
			and b.[Close] > 0
			and a.DateSeqReverse = @pintNumPrevDay + 1
			and b.DateSeqReverse = @pintNumPrevDay + 90 + 1
			left join #TempCashVsMC as y
			on a.ASXCode = y.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join StockData.PriceHistoryWeekly as x
			on a.ObservationDate >= x.WeekOpenDate
			and a.ObservationDate <= x.WeekCloseDate
			and a.ASXCode = x.ASXCode
			where 1 = 1
			and a.[Close] > 0.03
			and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
			order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 

		end

		if @pvchSortBy = 'Price Increase 50% last 10 days'
		begin
			select 
			   a.[ASXCode],
			   b.ObservationDate as StartObservationDate,
			   a.ObservationDate as EndObservationDate,
			   a.[Close] as EndClose,
			   b.[Close] as StartClose,
			   cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			   cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) as [EndWeekTradeValue(M)],
			   y.MC,
			   y.CashPosition,
			   d.Nature,
			   i.Poster
			from StockData.StockStatsHistoryPlus as a
			inner join StockData.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.[Close] >= 1.5 * b.[Close]
			and a.[Close] > 0
			and b.[Close] > 0
			and a.DateSeqReverse = @pintNumPrevDay + 1
			and b.DateSeqReverse = @pintNumPrevDay + 10 + 1
			left join #TempCashVsMC as y
			on a.ASXCode = y.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join StockData.PriceHistoryWeekly as x
			on a.ObservationDate >= x.WeekOpenDate
			and a.ObservationDate <= x.WeekCloseDate
			and a.ASXCode = x.ASXCode
			where 1 = 1
			and a.[Close] > 0.03
			and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
			order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 
		end
		
		if @pvchSortBy = 'Price Increase 20% last 5 days'
		begin
			select 
			   a.[ASXCode],
			   b.ObservationDate as StartObservationDate,
			   a.ObservationDate as EndObservationDate,
			   a.[Close] as EndClose,
			   b.[Close] as StartClose,
			   cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			   cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) as [EndWeekTradeValue(M)],
			   y.MC,
			   y.CashPosition,
			   d.Nature,
			   i.Poster
			from StockData.StockStatsHistoryPlus as a
			inner join StockData.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.[Close] >= 1.2 * b.[Close]
			and a.[Close] > 0
			and b.[Close] > 0
			and a.DateSeqReverse = @pintNumPrevDay + 1
			and b.DateSeqReverse = @pintNumPrevDay + 5 + 1
			left join #TempCashVsMC as y
			on a.ASXCode = y.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join StockData.PriceHistoryWeekly as x
			on a.ObservationDate >= x.WeekOpenDate
			and a.ObservationDate <= x.WeekCloseDate
			and a.ASXCode = x.ASXCode
			where 1 = 1
			and a.[Close] > 0.03
			and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
			order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 

		end

		if @pvchSortBy = 'Price Increase 80% last 100 days and Retreat 20% last 20 days'
		begin
			select 
			   a.[ASXCode],
			   b.ObservationDate as StartObservationDate,
			   a.ObservationDate as EndObservationDate,
			   a.[Close] as EndClose,
			   b.[Close] as StartClose,
			   cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(10, 2)) as [PriceIncrease%],
			   cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) as [EndWeekTradeValue(M)],
			   y.MC,
			   y.CashPosition,
			   d.Nature,
			   i.Poster
			from StockData.StockStatsHistoryPlus as a
			inner join StockData.StockStatsHistoryPlus as b
			on a.ASXCode = b.ASXCode
			and a.[Close] >= 1.8 * b.[Close]
			and a.[Close] > 0
			and b.[Close] > 0
			and a.DateSeqReverse = @pintNumPrevDay + 1
			and b.DateSeqReverse = @pintNumPrevDay + 100 + 1
			inner join StockData.StockStatsHistoryPlus as c
			on a.ASXCode = c.ASXCode
			and a.[Close] <= 0.9 * c.[Close]
			and a.[Close] >= 0.6 * c.[Close]
			and a.[Close] > 0
			and c.[Close] > 0
			and a.DateSeqReverse = @pintNumPrevDay + 1
			and c.DateSeqReverse = @pintNumPrevDay + 20 + 1
			left join #TempCashVsMC as y
			on a.ASXCode = y.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			left join StockData.PriceHistoryWeekly as x
			on a.ObservationDate >= x.WeekOpenDate
			and a.ObservationDate <= x.WeekCloseDate
			and a.ASXCode = x.ASXCode
			where 1 = 1
			and exists
			(
				select 1
				from StockData.StockStatsHistoryPlus
				where DateSeqReverse between @pintNumPrevDay + 90 + 1 and @pintNumPrevDay + 75 + 1
				and [close] >= 1.8 * b.[Close]
			)
			and a.[Close] > 0.03
			and cast(x.Volume * x.[Close]/1000000.0 as decimal(10,2)) > 0.5
			order by cast(x.Volume * x.[Close]/1000000.0 as bigint) desc 

		end

		if @pvchSortBy = 'Change Rate'
		begin
			if object_id(N'Tempdb.dbo.#TempPriceSummaryHistory') is not null
				drop table #TempPriceSummaryHistory

			select distinct
				a.ASXCode,
				a.CurrentDate as ObservationDate,
				b.DateFrom,
				b.[Open],
				b.[Close],
				b.Volume,
				b.Value,
				b.VWap,
				cast(null as bit) as IsMinute0,
				cast(null as bit) as IsMinute5,
				cast(null as bit) as IsMinute10,
				cast(null as bit) as IsMinute15,
				cast(null as bit) as IsMinute30,
				cast(null as bit) as IsMinute60
			into #TempPriceSummaryHistory
			from #TempTodayTradeBuyvsSell as a
			inner join StockData.v_PriceSummaryHistory as b with(nolock)
			on a.ASXCode = b.ASXCode
			and a.CurrentDate = b.ObservationDate
			where b.Volume > 0
			and NumPrevDay = @pintNumPrevDay

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
			set a.IsMinute10 = 1
			from #TempPriceSummaryHistory as a
			inner join 
			(
				select a.ASXCode, a.ObservationDate, min(a.DateFrom) as DateFrom
				from #TempPriceSummaryHistory as a
				inner join #TempPriceSummaryHistory as b
				on a.ASXCode = b.ASXCode
				and a.ObservationDate = b.ObservationDate
				and b.IsMinute0 = 1
				and a.DateFrom > dateadd(minute, 10, b.DateFrom) 
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

			select top 500
				x.ASXCode,
				--cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.CurrentDate,
				[ChangePerc],
			    format(h.MedianTradeValue, 'N0') as MedianTradeValue,
				[BuyTradeValue],
				[SellTradeValue],
				[TradeVolume],
				[BuyVsSell],
				cast(c.FloatingShares*e.[Close]/1000000.0 as decimal(10, 2)) as MC,
				[CashPosition],
				--[BuyVsMC],
			    [AnnDescr],
				x.[Poster],
				case when c.FloatingShares > 0 then cast(min5.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end as ChangeRate5m,
				case when c.FloatingShares > 0 then cast(min10.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end as ChangeRate10m,
				case when c.FloatingShares > 0 then cast(min15.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end as ChangeRate15m,
				case when c.FloatingShares > 0 then cast(min30.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end as ChangeRate30m,
				case when c.FloatingShares > 0 then cast(avgvol.AvgVolume/(c.FloatingShares*1000.0) as decimal(20,2)) else null end as ChangeRate10d,
				format(cast(min5.[Value] as bigint), 'N0') as TradeValue5m,				
				format(cast(min10.[Value] as bigint), 'N0') as TradeValue10m,	
				format(cast(min15.[Value] as bigint), 'N0') as TradeValue15m,	
				format(cast(min30.[Value] as bigint), 'N0') as TradeValue30m,	
				min5.VWAP as VWAP5m,
				min10.VWAP as VWAP10m,
				min15.VWAP as VWAP15m,
				min30.VWAP as VWAP30m,
				min60.VWAP as VWAP60m,
				min60.[Close] as Close60m,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				ttsu.FriendlyNameList,
				--min60.DateFrom,
				x.VsMA5,
				x.VsMA10
			from #TempTodayTradeBuyvsSell as x
			left join 
			(
				select 
					ASXCode,
					FloatingShares
				from StockData.v_CompanyFloatingShare 
			) as c
			on x.ASXCode = c.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on x.ASXCode = f.ASXCode
			left join Transform.PosterList as i
			on x.ASXCode = i.ASXCode
			left join #TempPriceSummaryHistory as min5
			on x.ASXCode = min5.ASXCode
			and x.CurrentDate = min5.ObservationDate
			and min5.IsMinute5 = 1
			left join #TempPriceSummaryHistory as min10
			on x.ASXCode = min10.ASXCode
			and x.CurrentDate = min10.ObservationDate
			and min10.IsMinute10 = 1
			left join #TempPriceSummaryHistory as min15
			on x.ASXCode = min15.ASXCode
			and x.CurrentDate = min15.ObservationDate
			and min15.IsMinute15 = 1
			left join #TempPriceSummaryHistory as min30
			on x.ASXCode = min30.ASXCode
			and x.CurrentDate = min30.ObservationDate
			and min30.IsMinute30 = 1
			left join #TempPriceSummaryHistory as min60
			on x.ASXCode = min60.ASXCode
			and x.CurrentDate = min60.ObservationDate
			and min60.IsMinute60 = 1
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on x.ASXCode = h.ASXCode
			left join #TempAvgVolume as avgvol
			on x.ASXCode = avgvol.ASXCode
			left join [Transform].[BrokerReportList] as m
			on x.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.ObservationDate = @dtDate
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on x.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.ObservationDate = @dtDate
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on x.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = @dtDate
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on x.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = @dtDate
			and n2.NetBuySell = 'S'
			left join Transform.TTSymbolUser as ttsu
			on x.ASXCode = ttsu.ASXCode
			where 1 = 1
			--and min15.[Value] > min5.[Value]*1.3
			and min5.[Value] >  300000
			--and x.[MovingAverage5d] > x.[MovingAverage30d]
			--and x.[MovingAverage10d] > x.[MovingAverage30d]
			and isnull(case when c.FloatingShares > 0 then cast(min30.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end, 99) > 0.5
			order by coalesce(
								case when c.FloatingShares > 0 then cast(min30.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end,
								case when c.FloatingShares > 0 then cast(min15.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end,
								case when c.FloatingShares > 0 then cast(min10.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end,
								case when c.FloatingShares > 0 then cast(min5.[Volume]/(c.FloatingShares*1000.0) as decimal(20,2)) else null end,
								0
							) desc

		end

		if @pvchSortBy = 'High relative price strength stocks'
		begin

			select top 500
				x.ASXCode,
				x.ObservationDate as CurrentDate,
				cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) as ChangePerc,
			    x.RelativePriceStrength,
				format(x.MedianTradeValue, 'N0') as MedianTradeValue,
				c.[MC],
				f.AnnDescr,
				f.[SearchTerm]
			from 
			(
				select 
					a.ASXCode,
					a.ObservationDate,
					cast(a.RelativePriceStrength as decimal(10,2)) as RelativePriceStrength,
					b.MedianTradeValue,
					b.CleansedMarketCap
				from StockData.RelativePriceStrength as a
				left join [StockData].[MedianTradeValue] as b
				on a.ASXCode = b.ASXCode
				where DateSeq = 1
				and MedianTradeValue > 2000
				and RelativePriceStrength >  75			
			) as x
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
			and x.ObservationDate > c.DateFrom
			and x.ObservationDate <= isnull(c.DateTo, '2050-01-01')
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
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
				from StockData.Announcement as x with(nolock)
				where cast(AnnDateTime as date) = @dtDate			
			) as f
			on x.ASXCode = f.ASXCode
			and f.RowNumber = 1
			order by ChangePerc desc

		end

		if @pvchSortBy = 'Most price increased stocks'
		begin

			select top 500
				x.ASXCode,
				@dtDate as CurrentDate,
				cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) as ChangePerc,
			    x.RelativePriceStrength,
				format(x.MedianTradeValue, 'N0') as MedianTradeValue,
				c.[MC],
				f.AnnDescr,
				f.[SearchTerm]
			from 
			(
				select 
					b.ASXCode,
					b.MedianTradeValue,
					b.CleansedMarketCap,
					cast(a.RelativePriceStrength as decimal(10,2)) as RelativePriceStrength
				from [StockData].[MedianTradeValue] as b
				left join StockData.RelativePriceStrength as a
				on a.ASXCode = b.ASXCode
				where DateSeq = 1
				and MedianTradeValue > 500
			) as x
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
			and @dtDate > c.DateFrom
			and @dtDate <= isnull(c.DateTo, '2050-01-01')
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
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
				from StockData.Announcement as x with(nolock)
				where cast(AnnDateTime as date) = @dtDate			
			) as f
			on x.ASXCode = f.ASXCode
			and f.RowNumber = 1
			where cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) is not null
			order by ChangePerc desc

		end

		if @pvchSortBy = 'Most price decreased stocks'
		begin

			select top 500
				x.ASXCode,
				@dtDate as CurrentDate,
				cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) as ChangePerc,
			    x.RelativePriceStrength,
				format(x.MedianTradeValue, 'N0') as MedianTradeValue,
				c.[MC],
				f.AnnDescr,
				f.[SearchTerm]
			from 
			(
				select 
					b.ASXCode,
					b.MedianTradeValue,
					b.CleansedMarketCap,
					cast(a.RelativePriceStrength as decimal(10,2)) as RelativePriceStrength
				from [StockData].[MedianTradeValue] as b
				left join StockData.RelativePriceStrength as a
				on a.ASXCode = b.ASXCode
				where DateSeq = 1
				and MedianTradeValue > 500
			) as x
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
			and @dtDate > c.DateFrom
			and @dtDate <= isnull(c.DateTo, '2050-01-01')
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
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
				from StockData.Announcement as x with(nolock)
				where cast(AnnDateTime as date) = @dtDate			
			) as f
			on x.ASXCode = f.ASXCode
			and f.RowNumber = 1
			where cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) is not null
			order by ChangePerc asc

		end

		if @pvchSortBy = 'Most volume ratio'
		begin

			select top 500
				a.ASXCode,
				@dtDate as CurrentDate,
				cast(cast(a.Value/1000.0 as bigint)/b.MedianTradeValueDaily as decimal(20, 4)) as VolumeRatio, 
				cast(a.Value/1000.0 as bigint) as TodayValue, 
				b.MedianTradeValueDaily, 
				b.MedianTradeValue as MedianTradeValueWeekly, 
				cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) as ChangePerc,
			    x.RelativePriceStrength,
				format(x.MedianTradeValue, 'N0') as MedianTradeValue,
				c.[MC],
				f.AnnDescr,
				f.[SearchTerm]
			from #TempPriceSummary as a
			inner join StockData.MedianTradeValue as b
			on a.ASXCode = b.ASXCode
			and b.MedianTradeValueDaily > 1
			left join 
			(
				select 
					ASXCode,
					CleansedMarketCap as MC,
					DateFrom,
					DateTo
				from HC.StockOverview 
			) as c
			on a.ASXCode = c.ASXCode
			and @dtDate > c.DateFrom
			and @dtDate <= isnull(c.DateTo, '2050-01-01')
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
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
				from StockData.Announcement as x with(nolock)
				where cast(AnnDateTime as date) = @dtDate			
			) as f
			on a.ASXCode = f.ASXCode
			and f.RowNumber = 1
			left join
			(
				select 
					b.ASXCode,
					b.MedianTradeValue,
					b.CleansedMarketCap,
					cast(a.RelativePriceStrength as decimal(10,2)) as RelativePriceStrength
				from [StockData].[MedianTradeValue] as b
				left join StockData.RelativePriceStrength as a
				on a.ASXCode = b.ASXCode
				where DateSeq = 1
				and MedianTradeValue > 500
			) as x
			on a.ASXCode = x.ASXCode
			order by cast(a.Value/1000.0 as bigint)/b.MedianTradeValueDaily desc

		end

		if @pvchSortBy = 'Open Trade out of Free Float'
		begin

			--declare @dtDate as date = '2020-07-17'

			if object_id(N'Tempdb.dbo.#TempIntraDayData') is not null 
				drop table #TempIntraDayData

			select 
				*, 
				cast(null as decimal(10, 2)) as OpenClosePriceChange,
				cast(null as decimal(10, 2)) as EntryClosePriceChange,
				cast(null as decimal(10, 2)) as OpenTradeOutOfFloat, 
				cast(null as decimal(10, 2)) as FloatingShares, 
				cast(null as decimal(10, 2)) as FloatingSharesPerc, 
				cast(null as varchar(200)) as OpenAnnouncement, 
				cast(null as decimal(10, 2)) as MarketCap, 
				cast(null as decimal(10, 2)) as MedianTradeValueWeekly,
				cast(null as decimal(10, 2)) as MedianTradeValueDaily
			into #TempIntraDayData
			from 
			(
				select 
					*, 
					row_number() over (partition by ASXCode, ObservationDate order by TimeIntervalStart asc) as RowNumber, 
					row_number() over (partition by ASXCode, ObservationDate order by TimeIntervalStart desc) as RevRowNumber, 
					cast(null as decimal(20, 4)) as DayOpen,
					cast(null as decimal(20, 4)) as DayClose
				from [StockData].[PriceHistoryTimeFrame] with(nolock)
				where TimeFrame = '5M'
				and ObservationDate = @dtDate
			) as x
			where x.RowNumber = 1

			update a
			set a.DayOpen = [Open]
			from #TempIntraDayData as a

			update a
			set a.DayClose = b.[Close]
			from #TempIntraDayData as a
			inner join
			(
				select 
					*, 
					row_number() over (partition by ASXCode, ObservationDate order by TimeIntervalStart asc) as RowNumber, 
					row_number() over (partition by ASXCode, ObservationDate order by TimeIntervalStart desc) as RevRowNumber, 
					cast(null as decimal(20, 4)) as DayOpen,
					cast(null as decimal(20, 4)) as DayClose
				from [StockData].[PriceHistoryTimeFrame]
				where TimeFrame = '5M'	
				and ObservationDate = @dtDate
			) as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where b.RevRowNumber = 1

			update a
			set a.OpenClosePriceChange = (a.DayClose - a.DayOpen)*100.0/a.DayOpen,
				a.EntryClosePriceChange = (a.[DayClose] - a.[Close])*100.0/a.[Close]
			from #TempIntraDayData as a

			update a
			set 
				OpenTradeOutOfFloat = a.Volume*1.0/(b.FloatingShares*10000),
				FloatingShares = b.FloatingShares,
				FloatingSharesPerc = b.FloatingSharesPerc
			from #TempIntraDayData as a
			inner join StockData.v_CompanyFloatingShare as b
			on a.ASXCode = b.ASXCode

			update a
			set 
				OpenAnnouncement = b.AnnDescr
			from #TempIntraDayData as a
			inner join 
			(
				select ASXCode, AnnDescr, cast(AnnDateTime as date) as ObservationDate, row_number() over (partition by ASXCode, cast(AnnDateTime as date) order by AnnDateTime asc) as RowNumber
				from StockData.Announcement with(nolock)
				where cast(AnnDateTime as time) < '10:10:00'
			) as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where b.RowNumber = 1

			update a
			set 
				MedianTradeValueDaily = b.MedianTradeValueDaily,
				MedianTradeValueWeekly = b.MedianTradeValue
			from #TempIntraDayData as a
			inner join StockData.MedianTradeValue as b
			on a.ASXCode = b.ASXCode

			update a
			set 
				MarketCap = b.CleansedMarketCap
			from #TempIntraDayData as a
			inner join StockData.CompanyInfo as b
			on a.ASXCode = b.ASXCode

			select 
				a.ASXCode,
				@dtDate as CurrentDate,
				TimeFrame,
				TimeIntervalStart,
				[Open],
				[High],
				[Low],
				[Close],
				Volume,
				format(SaleValue, 'N0') as SaleValue,
				VWAP,
				DayOpen,
				OpenTradeOutOfFloat,
				mvrln.MatchVolumeOutOfFreeFloatList,
				FloatingShares,
				FloatingSharesPerc,
				OpenAnnouncement,
				MarketCap,
				MedianTradeValueWeekly,
				MedianTradeValueDaily
			from #TempIntraDayData as a
			left join #TempMatchVolumeRatioLastNDay as mvrln
			on a.ASXCode = mvrln.ASXCode
			where SaleValue > 80000
			order by OpenTradeOutOfFloat desc

		end

		if @pvchSortBy = 'Match Volume out of Free Float'
		begin
			--declare @dtDate as date = '2021-03-22'
			--declare @pintNumPrevDay as int = 0

			if object_id(N'Tempdb.dbo.#Temp_v_PriceSummary_Latest') is not null
				drop table #Temp_v_PriceSummary_Latest

			select *
			into #Temp_v_PriceSummary_Latest
			from [StockData].[v_PriceSummary_Latest] with(nolock)
			where ObservationDate >= Common.DateAddBusinessDay(-8, @dtDate)
			and ObservationDate < @dtDate
			and Volume > 0

			if object_id(N'Tempdb.dbo.#TempPriceChangeLastNDay') is not null
				drop table #TempPriceChangeLastNDay

			select distinct x.ASXCode, stuff((
				select top 5 ',' + cast([PriceChangeVsPrevClose] as varchar(20)) + '%'
				from #Temp_v_PriceSummary_Latest as a
				where x.ASXCode = a.ASXCode
				order by ObservationDate desc
				for xml path('')), 1, 1, ''
			) as [PriceChangeList]
			into #TempPriceChangeLastNDay
			from #Temp_v_PriceSummary_Latest as x
			where PriceChangeVsPrevClose is not null

			if object_id(N'Tempdb.dbo.#TempSumPriceChangeLastNDay') is not null
				drop table #TempSumPriceChangeLastNDay

			select ASXCode, sum([PriceChangeVsPrevClose]) as SumPriceChangeVsPrevClose
			into #TempSumPriceChangeLastNDay
			from
			(
				select ASXCode, [PriceChangeVsPrevClose]
				from
				(
					select ASXCode, [PriceChangeVsPrevClose], row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
					from #Temp_v_PriceSummary_Latest as a
				) as x
				where x.RowNumber <= 5
			) as y
			group by ASXCode

			if object_id(N'Tempdb.dbo.#TempPriceSummaryMatchVolume') is not null
				drop table #TempPriceSummaryMatchVolume

			select *
			into #TempPriceSummaryMatchVolume
			from [StockData].[v_PriceSummary_MatchVolume]
			where ObservationDate = @dtDate

			if object_id(N'Tempdb.dbo.#TempPriceSummaryIndicativePrice') is not null
				drop table #TempPriceSummaryIndicativePrice

			select *
			into #TempPriceSummaryIndicativePrice
			from
			(
				select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
				from StockData.v_PriceSummary with(nolock)
				where ObservationDate = @dtDate
				and MatchVolume > 0
				and Volume = 0
				and IndicativePrice > 0
			) as a
			where RowNumber = 1

			if object_id(N'Tempdb.dbo.#TempPriceSummaryHighOpen') is not null
				drop table #TempPriceSummaryHighOpen

			select distinct ASXCode, ObservationDate, [High], [Open]
			into #TempPriceSummaryHighOpen
			from StockData.v_PriceSummary with(nolock)
			where DateTo is null
			and LatestForTheDay = 1
			and ObservationDate = @dtDate

			if @pbitASXCodeOnly = 0
			begin
				select 
					g.AvgVolume,
					a.ASXCode, 
					a.DateFrom as ObservationDateTime,
					case when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 3 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 1.2
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 20 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.75 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 200 then 1.5
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.50 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 100 then 2.5
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 3 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 2.3
						 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 2.2
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 3.2
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 100 then 4.2
						 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 20 then 3.3
						 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 100 then 4.3	
						 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 5.2	
						 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.8 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 6.2	
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 200 then 7.2
						 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 7.2	
						 else 99
					end as Grade,
					c.AnnDateTime,
					a1.IndicativePrice,
					case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end as PriceChange,
					a.PrevClose,
					a.MatchVolume as MatchVolume,
					cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) as IndicativeMatchValue,
					cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as MatchVolumeOutOfFreeFloat,
					mvrln.MatchVolumeOutOfFreeFloatList,
					cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
					i.PriceChangeList as Last5PriceChange,
					j.SumPriceChangeVsPrevClose,
					cast(case when h.[Open] > 0 then (h.[High] - h.[Open])*100.0/h.[Open] else null end as decimal(20, 2)) as MaxPriceIncrease,
					c.AnnDescr, 
					ttsu.FriendlyNameList,
					d.CleansedMarketCap as MarketCap, 
					cast(e.MedianTradeValue as int) as MedianTradeValueWeekly, 
					cast(e.MedianTradeValueDaily as int) as MedianTradeValueDaily, 
					e.MedianPriceChangePerc,
					f.RelativePriceStrength,
					rp.ShortTermRetailParticipationRate,
					rp.MediumTermRetailParticipationRate
				from #TempPriceSummaryMatchVolume as a
				inner join #TempPriceSummaryIndicativePrice as a1
				on a.ASXCode = a1.ASXCode
				inner join StockData.v_CompanyFloatingShare as b
				on a.ASXCode = b.ASXCode
				left join 
				(
					select ASXCode, AnnDescr, AnnDateTime, cast(AnnDateTime as date) as ObservationDate, row_number() over (partition by ASXCode, cast(AnnDateTime as date) order by AnnDateTime asc) as RowNumber
					from StockData.Announcement with(nolock)
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
				left join #TempPriceChangeLastNDay as i
				on a.ASXCode = i.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on a.ASXCode = ttsu.ASXCode
				left join StockData.RetailParticipation as rp
				on a.ASXCode = rp.ASXCode
				left join #TempSumPriceChangeLastNDay as j
				on a.ASXCode = j.ASXCode
				left join #TempMatchVolumeRatioLastNDay as mvrln
				on a.ASXCode = mvrln.ASXCode
				where b.FloatingShares > 0
				--and a.ASXCode = 'FNP.AX'
				and a.MatchVolume > 0
				and (g.AvgVolume is null or g.AvgVolume > 0)
				and (g.AvgVolume is null or cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0)
				and (a1.IndicativePrice is null or cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) >= 50)
				--AND a.ASXCode = 'EM1.AX'
				and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2
				and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 5
				and a.PrevClose > 0.02
				order by Grade, cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) desc, a.MatchVolume*1.0/b.FloatingShares*10000 desc

			end
			else
			begin

				if object_id(N'Tempdb.dbo.#TempOutputMatchVolumeOutofFreeFloat') is not null
					drop table #TempOutputMatchVolumeOutofFreeFloat

				select 
				identity(int, 1, 1) as DisplayOrder,
				*
				into #TempOutputMatchVolumeOutofFreeFloat
				from
				(
					select 
						a.ASXCode, 
						a.DateFrom as ObservationDateTime,
						case when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 3 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 1.2
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 20 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.75 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 200 then 1.5
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.50 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 100 then 2.5
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 10 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 3 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 2.3
							 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 2.2
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 10 then 3.2
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 2 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 100 then 4.2
							 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 20 then 3.3
							 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 and d.CleansedMarketCap < 100 then 4.3	
							 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 5.2	
							 when c.AnnDateTime is null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.8 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 6.2	
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 200 then 7.2
							 when c.AnnDateTime is not null and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end > 3 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2))*1.0/cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2 and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 1.5 and cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) > 50 then 7.2	
							 else 99
						end as Grade,
						c.AnnDateTime,
						a1.IndicativePrice,
						case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end as PriceChange,
						a.MatchVolume as MatchVolume,
						cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) as IndicativeMatchValue,
						cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as MatchVolumeOutOfFreeFloat, 
						cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as DailyChangeRate, 
						i.PriceChangeList as Last5PriceChange,
						cast(case when h.[Open] > 0 then (h.[High] - h.[Open])*100.0/h.[Open] else null end as decimal(20, 2)) as MaxPriceIncrease,
						c.AnnDescr, 
						d.CleansedMarketCap as MarketCap, 
						cast(e.MedianTradeValue as int) as MedianTradeValueWeekly, 
						cast(e.MedianTradeValueDaily as int) as MedianTradeValueDaily, 
						e.MedianPriceChangePerc,
						f.RelativePriceStrength			
					from #TempPriceSummaryMatchVolume as a
					inner join #TempPriceSummaryIndicativePrice as a1
					on a.ASXCode = a1.ASXCode
					inner join StockData.v_CompanyFloatingShare as b
					on a.ASXCode = b.ASXCode
					left join 
					(
						select ASXCode, AnnDescr, AnnDateTime, cast(AnnDateTime as date) as ObservationDate, row_number() over (partition by ASXCode, cast(AnnDateTime as date) order by AnnDateTime asc) as RowNumber
						from StockData.Announcement with(nolock)
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
					left join #TempPriceChangeLastNDay as i
					on a.ASXCode = i.ASXCode
					where b.FloatingShares > 0
					--and a.ASXCode = 'FNP.AX'
					and a.MatchVolume > 0
					and (g.AvgVolume is null or g.AvgVolume > 0)
					and (g.AvgVolume is null or cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0)
					and (a1.IndicativePrice is null or cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) >= 50)
					--AND a.ASXCode = 'EM1.AX'
					and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2
					and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 5
					and a.PrevClose > 0.02
					
				) as x
				order by Grade

				select
					distinct
					ASXCode,
					DisplayOrder,
					cast(ObservationDateTime as date) as ObservationDate,
					OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + @pvchSortBy as ReportProc
				from #TempOutputMatchVolumeOutofFreeFloat

			end
		end

		if @pvchSortBy = 'Match Volume out of Free Float - All Stocks'
		begin

			--declare @dtDate as date = '2020-12-31'
			--declare @pintNumPrevDay as int = 0

			if object_id(N'Tempdb.dbo.#TempPriceSummaryMatchVolume2') is not null
				drop table #TempPriceSummaryMatchVolume2

			select *
			into #TempPriceSummaryMatchVolume2
			from
			(
				select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
				from StockData.v_PriceSummary with(nolock)
				where ObservationDate = @dtDate
				and MatchVolume > 0
				and Volume = 0
			) as a
			where RowNumber = 1

			if object_id(N'Tempdb.dbo.#TempPriceSummaryIndicativePrice2') is not null
				drop table #TempPriceSummaryIndicativePrice2

			select *
			into #TempPriceSummaryIndicativePrice2
			from
			(
				select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
				from StockData.v_PriceSummary with(nolock)
				where ObservationDate = @dtDate
				and MatchVolume > 0
				and Volume = 0
				and IndicativePrice > 0
			) as a
			where RowNumber = 1

			if object_id(N'Tempdb.dbo.#TempPriceSummaryHighOpen2') is not null
				drop table #TempPriceSummaryHighOpen2

			select ASXCode, ObservationDate, [High], [Open]
			into #TempPriceSummaryHighOpen2
			from StockData.v_PriceSummary with(nolock)
			where DateTo is null
			and LatestForTheDay = 1
			and ObservationDate = @dtDate

			if object_id(N'Tempdb.dbo.#TempAvgVolume2') is not null
				drop table #TempAvgVolume2

			select ASXCode, avg(Volume) as AvgVolume
			into #TempAvgVolume2
			from StockData.PriceHistory
			where ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -2, getdate()) as date)
			and ObservationDate < cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
			group by ASXCode

			select 
				a.ASXCode, 
				a.DateFrom as ObservationDateTime,
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
			from #TempPriceSummaryMatchVolume2 as a
			inner join #TempPriceSummaryIndicativePrice2 as a1
			on a.ASXCode = a1.ASXCode
			inner join StockData.v_CompanyFloatingShare as b
			on a.ASXCode = b.ASXCode
			left join 
			(
				select ASXCode, AnnDescr, AnnDateTime, cast(AnnDateTime as date) as ObservationDate, row_number() over (partition by ASXCode, cast(AnnDateTime as date) order by AnnDateTime asc) as RowNumber
				from StockData.Announcement with(nolock)
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
			left join #TempAvgVolume2 as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummaryHighOpen2 as h
			on a.ASXCode = h.ASXCode
			and a.ObservationDate = h.ObservationDate
			where 1 = 1
			--and b.FloatingShares > 0
			--and a.MatchVolume > 0
			--and (g.AvgVolume is null or g.AvgVolume > 0)
			--and (g.AvgVolume is null or cast(g.AvgVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0)
			--and (a1.IndicativePrice is null or cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) >= 50)
			--AND a.ASXCode = 'EM1.AX'
			--and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.3
			order by a.ASXCode

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
