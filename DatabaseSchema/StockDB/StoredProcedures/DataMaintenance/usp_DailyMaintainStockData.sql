-- Stored procedure: [DataMaintenance].[usp_DailyMaintainStockData]





CREATE PROCEDURE [DataMaintenance].[usp_DailyMaintainStockData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_DailyMaintainStockData.sql
Stored Procedure Name: usp_DailyMaintainStockData
Overview
-----------------
usp_DailyMaintainStockData

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
Date:		2017-06-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_DailyMaintainStockData'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		update a
		set AnnContent = replace(
				replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(AnnContent,'[^a-zA-Z0-9\.\,\+\''\s\%\|]',' '))), 
					'  ', 
					' '
					), 
					char(160), ''
				),
			IsCleansed = 1
		from StockData.Announcement as a
		where isnull(IsCleansed, 0) = 0

		if object_id(N'Tempdb.dbo.#TempAvgValue') is not null
			drop table #TempAvgValue

		select ASXCode, avg([Volume]*[Close]) as AvgValue90d
		into #TempAvgValue
		from StockData.PriceHistory
		where 1 = 1
		--and ASXCode in ('AB1.AX')
		and datediff(day, ObservationDate, getdate()) <= 90
		group by ASXCode

		update a
		set BuySellInd = null
		from StockData.PriceSummaryToday as a
		inner join #TempAvgValue as b
		on a.ASXCode = b.ASXCode
		where [ValueDelta] >  b.AvgValue90d
		and cast(DateFrom as time) > cast('10:10:15' as time)
		and ValueDelta > 500000
		and a.BuySellInd in ('B', 'S') 

		update a
		set BuySellInd = null
		from StockData.PriceSummary as a
		inner join #TempAvgValue as b
		on a.ASXCode = b.ASXCode
		where [ValueDelta] >  b.AvgValue90d
		and cast(DateFrom as time) > cast('10:10:15' as time)
		and ValueDelta > 500000
		and a.BuySellInd in ('B', 'S') 

		exec [StockData].[usp_RefeshAppendix3B]

		exec [StockData].[usp_RefreshStockStatsHistoryPlus]

		--exec [StockData].[usp_RefeshStockSectorList]

		exec [StockData].[usp_RefeshDirectorInterest]

		--exec HC.usp_GetPosterStock

		--exec HC.usp_GetCommonStockPlus

		--UPDATE StockData.MoneyFlowInOutHistory
		truncate table Working.MoneyFlowInOutHistory

		declare @dtObservationDate as date = cast(getdate() as date)

		insert into [Working].[MoneyFlowInOutHistory]
		exec [StockData].[usp_MoneyFlowReportAllStock]
		@pdtObservationDate = @dtObservationDate,
		@pintLookbackDays = 90

		delete a
		from StockData.MoneyFlowInOutHistory as a
		inner join [Working].[MoneyFlowInOutHistory] as b
		on a.ASXCode = b.ASXCode
		and a.MarketDate = b.MarketDate

		insert into StockData.MoneyFlowInOutHistory
		select *
		from Working.MoneyFlowInOutHistory as a
		where not exists
		(
			select 1
			from StockData.MoneyFlowInOutHistory
			where ASXCode = a.ASXCode
			and MarketDate = a.MarketDate
		)

		insert into [Archive].[StockKeyTokenHistory]
		(
			[StockKeyTokenID],
			[Token],
			[ASXCode],
			[CreateDate],
			ArchiveDate
		)
		select
			[StockKeyTokenID],
			[Token],
			[ASXCode],
			[CreateDate],
			cast(getdate() as date) as ArchiveDate
		from [LookupRef].[StockKeyToken] as a
		where not exists
		(
			select 1
			from [Archive].[StockKeyTokenHistory]
			where ArchiveDate = cast(getdate() as date)
		)

		exec [Report].[usp_GetSectorPerformanceAlert]

		exec [DataMaintenance].[usp_RefreshMedianTradeValue]
		@pintNumPrevDay = 0

		if object_id(N'Tempdb.dbo.#TempRetailParticipation1') is not null
			drop table #TempRetailParticipation1

		select 
			x.ASXCode, 
			cast(x.TotalVolume*100.0/y.TotalVolume as decimal(10, 2)) as RetailParticipationRate,
			cast(z.TotalVolume*100.0/y.TotalVolume as decimal(10, 2)) as BroadRetailParticipationRate
		into #TempRetailParticipation1
		from
		(
			select ASXCode, sum(TotalVolume) as TotalVolume
			from StockData.BrokerReport
			--where ObservationDate > cast(Common.DateAddBusinessDay(-1 * 60, getdate()) as date)
			where ObservationDate > cast(dateadd(day, -1 * 60, getdate()) as date)
			and BrokerCode in ('ComSec', 'CMCMar', 'WeaSec')
			and TotalValue > 0
			group by ASXCode
		) as x
		inner join
		(
			select ASXCode, sum(TotalVolume) as TotalVolume
			from StockData.BrokerReport
			where ObservationDate > cast(dateadd(day, -1 * 60, getdate()) as date)
			and BrokerCode in ('ComSec', 'CMCMar', 'WeaSec', 'AusInv', 'OpenMa')
			and TotalValue > 0
			group by ASXCode
		) as z
		on x.ASXCode = z.ASXCode
		inner join
		(
			select ASXCode, sum(TotalVolume) as TotalVolume
			from StockData.BrokerReport
			where ObservationDate > cast(dateadd(day, -1 * 60, getdate()) as date)
			and TotalValue > 0
			group by ASXCode
		) as y
		on x.ASXCode = y.ASXCode

		if object_id(N'Tempdb.dbo.#TempRetailParticipation2') is not null
			drop table #TempRetailParticipation2

		select 
			x.ASXCode, 
			cast(x.TotalVolume*100.0/y.TotalVolume as decimal(10, 2)) as RetailParticipationRate,
			cast(z.TotalVolume*100.0/y.TotalVolume as decimal(10, 2)) as BroadRetailParticipationRate
		into #TempRetailParticipation2
		from
		(
			select ASXCode, sum(TotalVolume) as TotalVolume
			from StockData.BrokerReport
			where ObservationDate > cast(dateadd(day, -1 * 15, getdate()) as date)
			and BrokerCode in ('ComSec', 'CMCMar', 'WeaSec')
			and TotalValue > 0
			group by ASXCode
		) as x
		inner join
		(
			select ASXCode, sum(TotalVolume) as TotalVolume
			from StockData.BrokerReport
			where ObservationDate > cast(dateadd(day, -1 * 15, getdate()) as date)
			and BrokerCode in ('ComSec', 'CMCMar', 'WeaSec', 'AusInv', 'OpenMa')
			and TotalValue > 0
			group by ASXCode
		) as z
		on x.ASXCode = z.ASXCode
		inner join
		(
			select ASXCode, sum(TotalVolume) as TotalVolume
			from StockData.BrokerReport
			where ObservationDate > cast(dateadd(day, -1 * 15, getdate()) as date)
			and TotalValue > 0
			group by ASXCode
		) as y
		on x.ASXCode = y.ASXCode

		delete a
		from StockData.RetailParticipation as a

		dbcc checkident('StockData.RetailParticipation', reseed, 1);

		insert into StockData.RetailParticipation
		(
		   [ASXCode]
		  ,[MediumTermRetailParticipationRate]
		  ,[MediumTermBroadRetailParticipationRate]
		  ,[ShortTermRetailParticipationRate]
		  ,[ShortTermBroadRetailParticipationRate]
		)
		select
			a.ASXCode,
			a.RetailParticipationRate as MediumTermRetailParticipationRate,
			a.BroadRetailParticipationRate as MediumTermBroadRetailParticipationRate,
			b.RetailParticipationRate as ShortTermRetailParticipationRate,
			b.BroadRetailParticipationRate as ShortTermBroadRetailParticipationRate
		from #TempRetailParticipation1 as a
		inner join #TempRetailParticipation2 b
		on a.ASXCode = b.ASXCode

		--Updates the RelativePriceStrength
		if object_id(N'Working.Stock12MonthPriceChange') is not null
			drop table Working.Stock12MonthPriceChange

		select 
			a.ASXCode,
			a.ObservationDate,
			cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(8, 2)) as PriceChange
		into Working.Stock12MonthPriceChange
		from StockData.StockStatsHistoryPlus as a
		inner join StockData.StockStatsHistoryPlus as b
		on a.ASXCode = b.ASXCode
		and a.DateSeqReverse + 252 = b.DateSeqReverse
		where b.[Close] > 0

		delete a
		from Working.Stock12MonthPriceChange as a
		where PriceChange > 600

		delete a
		from StockData.RelativePriceStrength as a

		dbcc checkident('StockData.RelativePriceStrength', reseed, 1);

		insert into StockData.RelativePriceStrength
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[PriceChange]
		  ,[PriceChangeRank]
		  ,[RelativePriceStrength]
		  ,[DateSeq]
		)
		select a.*, (1 - a.PriceChangeRank*1.0/b.NumObservations)*100.0 as RelativePriceStrength, cast(null as int) as DateSeq
		from
		(
			select 
				*,
				rank() over (partition by ObservationDate order by PriceChange desc) as PriceChangeRank
			from Working.Stock12MonthPriceChange
		) as a
		inner join
		(
			select ObservationDate, count(*) as NumObservations
			from Working.Stock12MonthPriceChange 
			group by ObservationDate
		) as b
		on a.ObservationDate = b.ObservationDate

		update a
		set a.DateSeq = b.RowNumber
		from StockData.RelativePriceStrength as a
		inner join 
		(
			select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from StockData.RelativePriceStrength
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		delete a
		from StockData.MaxVolumePrice as a

		dbcc checkident('StockData.MaxVolumePrice', reseed, 1);

		insert into StockData.MaxVolumePrice
		(
			[AdjVolumeRank],
			[AdjVolume],
			[ASXCode],
			[ObservationDate],
			[Close],
			[Open],
			[Low],
			[High],
			[Volume],
			[Value],
			[Trades],
			[CreateDate],
			[ModifyDate]
		)
		select
			[AdjVolumeRank],
			[AdjVolume],
			[ASXCode],
			[ObservationDate],
			[Close],
			[Open],
			[Low],
			[High],
			[Volume],
			[Value],
			[Trades],
			[CreateDate],
			[ModifyDate]
		from
		(
			select 
				rank() over (partition by ASXCode order by 
				Volume * 
				case when datediff(day, ObservationDate, getdate()) < 20 then 1.2 
					 when datediff(day, ObservationDate, getdate()) between 20 and 40 then 1.0
					 when datediff(day, ObservationDate, getdate()) between 40 and 60 then 0.85	
					 when datediff(day, ObservationDate, getdate()) between 60 and 90 then 0.70	
				end desc) AdjVolumeRank, 
				Volume * 
				case when datediff(day, ObservationDate, getdate()) < 20 then 1.2 
					 when datediff(day, ObservationDate, getdate()) between 20 and 40 then 1.0
					 when datediff(day, ObservationDate, getdate()) between 40 and 60 then 0.85	
					 when datediff(day, ObservationDate, getdate()) between 60 and 90 then 0.70	
				end as AdjVolume,
				*
			from StockData.PriceHistory as a
			where datediff(day, ObservationDate, getdate()) < 90
			and not exists
			(
				select 1
				from StockData.PriceHistoryTimeFrame
				where TimeFrame = '1M'
				and ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
				and Volume > 0.1 * a.Volume
				and cast(TimeIntervalStart as time) > '10:10:00'
				and cast(TimeIntervalStart as time) < '16:00:00'	
			)
		) as x
		where x.AdjVolumeRank <= 3

		update a
		set [CleansedMarketCap] = cast(a.SharesOnIssue*b.[Close]*1.0/1000000 as decimal(20,2))
		from [StockData].[CompanyInfo] as a
		inner join StockData.PriceHistoryCurrent as b
		on a.ASXCode = b.ASXCode

		insert into StockData.PriceSummary
		(
			   [ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,[Prev1Volume]
			  ,[Prev1Value]
			  ,[VolumeDelta]
			  ,[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,[LatestForTheDay]
			  ,[ObservationDate]
			  ,[MatchVolume]
			  ,[SeqNumber]
		)
		select
			   [ASXCode]
			  ,null as [Bid]
			  ,null as [Offer]
			  ,null as [Open]
			  ,null as [High]
			  ,null as [Low]
			  ,PrevClose as [Close]
			  ,0 as [Volume]
			  ,0 as [Value]
			  ,0 as [Trades]
			  ,0 as [VWAP]
			  ,dateadd(second, -3600, DateFrom) as [DateFrom]
			  ,DateFrom as [DateTo]
			  ,null as [LastVerifiedDate]
			  ,0 as [bids]
			  ,0 as [bidsTotalVolume]
			  ,0 as [offers]
			  ,0 as [offersTotalVolume]
			  ,[Close] as [IndicativePrice]
			  ,100 as [SurplusVolume]
			  ,PrevClose as [PrevClose]
			  ,null as [SysLastSaleDate]
			  ,null as [SysCreateDate]
			  ,null as [Prev1PriceSummaryID]
			  ,null as [Prev1Bid]
			  ,null as [Prev1Offer]
			  ,null as [Prev1Volume]
			  ,null as [Prev1Value]
			  ,null as [VolumeDelta]
			  ,null as [ValueDelta]
			  ,null as [TimeIntervalInSec]
			  ,null as [BuySellInd]
			  ,null as [Prev1Close]
			  ,0 as [LatestForTheDay]
			  ,[ObservationDate]
			  ,1000 as [MatchVolume]
			  ,0 as[SeqNumber]
		from 
		(
			select
				   a.[ASXCode]
				  ,PriceBid as [Bid]
				  ,PriceAsk as [Offer]
				  ,Price as [Open]
				  ,Price as [High]
				  ,Price as [Low]
				  ,Price as [Close]
				  ,sum(a.Quantity) over (partition by a.ASXCode order by SaleDateTime) as [Volume]
				  ,sum(a.SaleValue) over (partition by a. ASXCode order by SaleDateTime) as [Value]
				  ,null as [Trades]
				  ,cast(case when sum(a.Quantity) over (partition by a.ASXCode order by SaleDateTime) > 0 then sum(SaleValue) over (partition by a.ASXCode order by SaleDateTime)*1.0/sum(Quantity) over (partition by a.ASXCode order by SaleDateTime) else null end as decimal(20, 4)) as [VWAP]
				  ,SaleDateTime as [DateFrom]
				  ,lead(SaleDateTime) over (partition by a.ASXCode order by SaleDateTime) as [DateTo]
				  ,getdate() as [LastVerifiedDate]
				  ,0 as [bids]
				  ,0 as [bidsTotalVolume]
				  ,0 as [offers]
				  ,0 as [offersTotalVolume]
				  ,0 as [IndicativePrice]
				  ,0 as [SurplusVolume]
				  ,b.PrevClose as [PrevClose]
				  ,SaleDateTime as [SysLastSaleDate]
				  ,SaleDateTime as [SysCreateDate]
				  ,null as [Prev1PriceSummaryID]
				  ,lead(PriceBid) over (partition by a.ASXCode order by SaleDateTime) as [Prev1Bid]
				  ,lead(PriceAsk) over (partition by a.ASXCode order by SaleDateTime) as [Prev1Offer]
				  ,null as [Prev1Volume]
				  ,null as [Prev1Value]
				  ,null as [VolumeDelta]
				  ,null as [ValueDelta]
				  ,null as [TimeIntervalInSec]
				  ,DerivedBuySellInd as [BuySellInd]
				  ,lead(Price) over (partition by a.ASXCode order by SaleDateTime) as [Prev1Close]
				  ,null as [LatestForTheDay]
				  ,a.ObservationDate as [ObservationDate]
				  ,null as [MatchVolume]
				  ,row_number() over (partition by a.ASXCode order by SaleDateTime) as [SeqNumber]
				  ,row_number() over (partition by a.ASXCode order by SaleDateTime desc) as [ReverseSeqNumber]
			from StockData.v_StockTickSaleVsBidAskASX_All as a
			left join StockData.v_PriceHistory as b
			on a.ObservationDate = b.ObservationDate
			and a.ASXCode = b.ASXCode
			where 1 = 1 
			and a.ObservationDate >= dateadd(day, -7, getdate())
			--and a.ObservationDate = '2023-08-11'
			--and a.ASXCode = 'C1X.AX'
			and Price > 0
			and not exists
			(
				select 1
				from StockData.PriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)
			and exists
			(
				select *
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and ASXCode = a.ASXCode
			)
		) as x
		where x.SeqNumber = 1
		union all
		select
			   [ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,case when ReverseSeqNumber = 1 then null else DateTo end as [DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,lead(Volume) over (partition by ASXCode order by DateFrom desc) as [Prev1Volume]
			  ,lead([Value]) over (partition by ASXCode order by DateFrom desc) as [Prev1Value]
			  ,[Volume] - lead([Volume]) over (partition by ASXCode order by DateFrom desc) as [VolumeDelta]
			  ,[Value] - lead([Value]) over (partition by ASXCode order by DateFrom desc)[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,case when ReverseSeqNumber = 1 then 1 else 0 end as [LatestForTheDay]
			  ,[ObservationDate]
			  ,[MatchVolume]
			  ,[SeqNumber]
		from
		(
			select
				   a.[ASXCode]
				  ,PriceBid as [Bid]
				  ,PriceAsk as [Offer]
				  ,Price as [Open]
				  ,Price as [High]
				  ,Price as [Low]
				  ,Price as [Close]
				  ,sum(a.Quantity) over (partition by a.ASXCode order by SaleDateTime) as [Volume]
				  ,sum(a.SaleValue) over (partition by a. ASXCode order by SaleDateTime) as [Value]
				  ,null as [Trades]
				  ,cast(case when sum(a.Quantity) over (partition by a.ASXCode order by SaleDateTime) > 0 then sum(SaleValue) over (partition by a.ASXCode order by SaleDateTime)*1.0/sum(Quantity) over (partition by a.ASXCode order by SaleDateTime) else null end as decimal(20, 4)) as [VWAP]
				  ,SaleDateTime as [DateFrom]
				  ,lead(SaleDateTime) over (partition by a.ASXCode order by SaleDateTime) as [DateTo]
				  ,getdate() as [LastVerifiedDate]
				  ,0 as [bids]
				  ,0 as [bidsTotalVolume]
				  ,0 as [offers]
				  ,0 as [offersTotalVolume]
				  ,0 as [IndicativePrice]
				  ,0 as [SurplusVolume]
				  ,b.PrevClose as [PrevClose]
				  ,SaleDateTime as [SysLastSaleDate]
				  ,SaleDateTime as [SysCreateDate]
				  ,null as [Prev1PriceSummaryID]
				  ,lead(PriceBid) over (partition by a.ASXCode order by SaleDateTime) as [Prev1Bid]
				  ,lead(PriceAsk) over (partition by a.ASXCode order by SaleDateTime) as [Prev1Offer]
				  ,null as [Prev1Volume]
				  ,null as [Prev1Value]
				  ,null as [VolumeDelta]
				  ,null as [ValueDelta]
				  ,null as [TimeIntervalInSec]
				  ,DerivedBuySellInd as [BuySellInd]
				  ,lead(Price) over (partition by a.ASXCode order by SaleDateTime) as [Prev1Close]
				  ,null as [LatestForTheDay]
				  ,a.ObservationDate as [ObservationDate]
				  ,null as [MatchVolume]
				  ,row_number() over (partition by a.ASXCode order by SaleDateTime) as [SeqNumber]
				  ,row_number() over (partition by a.ASXCode order by SaleDateTime desc) as [ReverseSeqNumber]
			from StockData.v_StockTickSaleVsBidAskASX_All as a
			left join StockData.v_PriceHistory as b
			on a.ObservationDate = b.ObservationDate
			and a.ASXCode = b.ASXCode
			where 1 = 1 
			and a.ObservationDate >= dateadd(day, -7, getdate())
			--and a.ASXCode = 'C1X.AX'
			and Price > 0
			and not exists
			(
				select 1
				from StockData.PriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)
			and exists
			(
				select *
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and ASXCode = a.ASXCode
			)
		) as x

		if object_id(N'Transform.PriceSummaryLatest') is not null
			drop table Transform.PriceSummaryLatest

		SELECT [PriceSummaryID]
			  ,[ASXCode]
			  ,[Bid]
			  ,[Offer]
			  ,[Open]
			  ,[High]
			  ,[Low]
			  ,[Close]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[VWAP]
			  ,[DateFrom]
			  ,[DateTo]
			  ,[LastVerifiedDate]
			  ,[bids]
			  ,[bidsTotalVolume]
			  ,[offers]
			  ,[offersTotalVolume]
			  ,[IndicativePrice]
			  ,[SurplusVolume]
			  ,[MatchVolume]
			  ,[PrevClose]
			  ,[SysLastSaleDate]
			  ,[SysCreateDate]
			  ,[Prev1PriceSummaryID]
			  ,[Prev1Bid]
			  ,[Prev1Offer]
			  ,[Prev1Volume]
			  ,[Prev1Value]
			  ,[VolumeDelta]
			  ,[ValueDelta]
			  ,[TimeIntervalInSec]
			  ,[BuySellInd]
			  ,[Prev1Close]
			  ,[LatestForTheDay]
			  ,[ObservationDate]
			  ,case when [PrevClose] > 0 then cast(([Close] - [PrevClose])*100.0/[PrevClose] as decimal(10, 2)) else null end as PriceChangeVsPrevClose
			  ,case when [Open] > 0 then cast(([Close] - [Open])*100.0/[Open] as decimal(10, 2)) else null end as PriceChangeVsOpen
			  ,([High] - [Low]) as Spread
		into Transform.PriceSummaryLatest
		FROM [StockData].[PriceSummary] with(nolock)
		where DateTo is null
		and LatestForTheDay = 1
		
		create clustered index idx_transformpricesummarylatest_obdateasxcode on Transform.PriceSummaryLatest(ObservationDate, ASXCode)

		if object_id(N'Transform.PriceSummaryMatchVolume') is not null
			drop table Transform.PriceSummaryMatchVolume
		
		select *
		into Transform.PriceSummaryMatchVolume
		from
		(
			select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
			from StockData.v_PriceSummary with(nolock)
			where 1 = 1
			and MatchVolume > 0
			and [Open] = 0
		) as a
		where RowNumber = 1

		create clustered index idx_transformpricesummarymatchvolume_obdateasxcode on Transform.PriceSummaryMatchVolume(ObservationDate, ASXCode)
		
		if object_id(N'Transform.PriceHistoryFutureGainLoss') is not null
			drop table Transform.PriceHistoryFutureGainLoss

		select *, 
			cast(0 as int) as HighestIn30D,
			cast(0 as int) as HighestIn60D,
			row_number() over (partition by ASXCode order by ObservationDate asc) as SeqNo
		into Transform.PriceHistoryFutureGainLoss
		from StockData.v_PriceHistory
		where ObservationDate > dateadd(day, -200, getdate())

		update a
		set HighestIn30D = 1
		from Transform.PriceHistoryFutureGainLoss as a
		inner join 
		(
			select
				a.ASXCode, 
				a.SeqNo,
				max(b.[Close]) as MaxClose
			from Transform.PriceHistoryFutureGainLoss as a
			inner join Transform.PriceHistoryFutureGainLoss as b
			on a.ASXCode = b.ASXCode
			and a.SeqNo < b.SeqNo + 30
			and a.SeqNo >= b.SeqNo
			group by a.ASXCode, a.SeqNo
		) as b
		on a.ASXCode = b.ASXCode
		and a.SeqNo = b.SeqNo + 1
		and a.[Close] > b.MaxClose
		and a.SeqNo > 30

		update a
		set HighestIn60D = 1
		from Transform.PriceHistoryFutureGainLoss as a
		inner join 
		(
			select
				a.ASXCode, 
				a.SeqNo,
				max(b.[Close]) as MaxClose
			from Transform.PriceHistoryFutureGainLoss as a
			inner join Transform.PriceHistoryFutureGainLoss as b
			on a.ASXCode = b.ASXCode
			and a.SeqNo < b.SeqNo + 60
			and a.SeqNo >= b.SeqNo
			group by a.ASXCode, a.SeqNo
		) as b
		on a.ASXCode = b.ASXCode
		and a.SeqNo = b.SeqNo + 1
		and a.[Close] > b.MaxClose
		and a.SeqNo > 60

		update a
		set HighestIn30D = 0
		from Transform.PriceHistoryFutureGainLoss as a
		where exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and SeqNo < a.SeqNo 
			and SeqNo >= a.SeqNo - 10
			and HighestIn30D = 1
		)
		and HighestIn30D = 1

		update a
		set HighestIn60D = 0
		from Transform.PriceHistoryFutureGainLoss as a
		where exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and SeqNo < a.SeqNo 
			and SeqNo >= a.SeqNo - 10
			and HighestIn60D = 1
		)
		and HighestIn60D = 1

		exec [Transform].[usp_RefreshPriceHistoryIntraDay]
		@pvchTimeInterval = '1M'

		exec [Transform].[usp_RefreshPriceHistoryIntraDay]
		@pvchTimeInterval = '5M'

		exec [Transform].[usp_RefreshPriceHistoryIntraDay]
		@pvchTimeInterval = '1H'

		exec [Transform].[usp_RefreshTransformPriceHistory]

		exec [Transform].[usp_RefreshPriceHistoryWeekly]

		exec [Transform].[usp_RefreshPriceHistoryMonthly]

		exec [StockData].[usp_RefreshStockStatsHistoryPlusWeekly]
		
		exec [StockData].[usp_RefreshStockStatsHistoryPlusMonthly]

		exec [StockData].[usp_RefreshWeeklyMonthlyPriceAction]

		exec [DataMaintenance].[usp_RefreshTop20Performance]

		exec [DataMaintenance].[usp_RefreshDirectorBuySignificantHolderChange]

		exec [DataMaintenance].[usp_RefreshDirectorSubscribeSPP]

		exec [DataMaintenance].[usp_RefreshGoldInterception]

		exec [DataMaintenance].[usp_AddNewASXCode]

		exec [DataMaintenance].[usp_RefreshTransformMCAndCashPosition]

		exec [Transform].[usp_RefresTransformStockPreMarketMatchVolume]

		exec [Transform].[usp_RefreshMarketLevelAnalysis]

		--exec [DataMaintenance].[usp_RefreshTransformPriceHistoryNetVolume]

		exec [DataMaintenance].[usp_MediumFrequencyMaintainStockData]

		exec [DataMaintenance].[usp_RefreshAnnouncementSearch]

		exec [DataMaintenance].[usp_RefreshBuyCloseSellOpen]

		exec [DataMaintenance].[usp_RefreshTransformMostTradedSmallCap]

		----Keep this one to the end
		--exec [DataMaintenance].[usp_StoreStockDataReport]

		--exec [DataMaintenance].[usp_RefreshTransformTickSaleVsBidAsk]

		exec [DataMaintenance].[usp_ArchiveStockData]

		exec [DataMaintenance].[usp_ArchivePriceSummary]

		exec [DataMaintenance].[usp_RefreshTransformMarketCLVTrend]


	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
