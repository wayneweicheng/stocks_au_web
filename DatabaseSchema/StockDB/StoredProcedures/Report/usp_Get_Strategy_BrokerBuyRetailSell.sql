-- Stored procedure: [Report].[usp_Get_Strategy_BrokerBuyRetailSell]


CREATE PROCEDURE [Report].[usp_Get_Strategy_BrokerBuyRetailSell]
@pbitDebug AS BIT = 0,
@pintNumPrevDay as int, 
@pintNoOfDays as int = 1,
@pbitASXCodeOnly as bit = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_Get_Strategy_BrokerBuy.sql
Stored Procedure Name: usp_Get_Strategy_BrokerBuyRetailSell
Overview
-----------------
usp_Get_Strategy_BrokerBuyRetailSell

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
Date:		2020-02-22
Author:		WAYNE CHENG
Description: usp_Get_Strategy_BrokerBuyRetailSell
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_BrokerBuyRetailSell'
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
		--declare @pintNoOfDays as int = 5
		--declare @pbitASXCodeOnly as bit = 0
		
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

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
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		--declare @pintNumPrevDay as int = 0
		--declare @pintNoOfDays as int = 2

		if object_id(N'Tempdb.dbo.#TempExclusionObservationDate') is not null
			drop table #TempExclusionObservationDate

		select ObservationDate
		into #TempExclusionObservationDate
		from StockData.BrokerReport
		where dateadd(day, -10, getdate()) < ObservationDate 
		group by ObservationDate
		having count(*) < 12000

		declare @dtMaxDate as date
		if exists
		(
			select 1
			from #TempExclusionObservationDate
		)
		begin
			select @dtMaxDate = max(ObservationDate)
			from StockData.BrokerReport
			where ObservationDate not in
			(
				select ObservationDate 
				from #TempExclusionObservationDate 
			)
		end
		else
		begin
			select @dtMaxDate = max(ObservationDate)
			from StockData.BrokerReport
		end

		declare @dtMaxBRDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, @dtMaxDate) as date)
		declare @dtStartBRDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - (@pintNoOfDays - 1), @dtMaxDate) as date)

		if object_id(N'Tempdb.dbo.#TempBrokerData') is not null
			drop table #TempBrokerData

		select x.*
		into #TempBrokerData
		from
		(
			select 
				BrokerCode,
				ASXCode,
				avg(BuyPrice) as BuyPrice,
				avg(SellPrice) as SellPrice,
				sum(NetValue) as NetValue,
				sum(NetVolume) as NetVolume,
				@dtMaxBRDate as ObservationDate,
				row_number() over (partition by ASXCode order by sum(NetVolume) desc) as RowNumber
			from StockData.BrokerReport
			where ObservationDate >= @dtStartBRDate
			and ObservationDate <= @dtMaxBRDate
			and BuyPrice > 0
			group by 
				BrokerCode,
				ASXCode
		) as x
		inner join LookupRef.BrokerName as y
		on x.BrokerCode = y.BrokerCode
		where x.RowNumber in (1, 2)
		--and BrokerCode in ('ArgSec', 'BelPot', 'EurSec', 'Macqua', 'PerShn', 'Morsec', 'HarLim', 'InsAus', 'MorgFn', 'EurHar', 'UBSAus', 'FinExe', 'CreSui', 'J.Pmor')
		and y.BrokerScore >= 0.8

		--declare @dtMaxBRDate as date = '2020-02-18'

		if object_id(N'Tempdb.dbo.#TempBrokerDataSell') is not null
			drop table #TempBrokerDataSell

		select *
		into #TempBrokerDataSell
		from
		(
			select 
				BrokerCode,
				ASXCode,
				avg(nullif(BuyPrice, 0)) as BuyPrice,
				avg(nullif(SellPrice, 0)) as SellPrice,
				sum(NetValue) as NetValue,
				sum(NetVolume) as NetVolume,
				@dtMaxBRDate as ObservationDate,
				row_number() over (partition by ASXCode order by sum(NetVolume) asc) as RowNumber
			from StockData.BrokerReport
			where ObservationDate >= @dtStartBRDate
			and ObservationDate <= @dtMaxBRDate
			--and BuyPrice > 0
			group by 
				BrokerCode,
				ASXCode
		) as x
		where x.RowNumber in (1, 2, 3, 4)
		--and BrokerCode in (
		--	select BrokerCode
		--	from LookupRef.BrokerName
		--	where BrokerScore <= 0
		--)

		if object_id(N'Tempdb.dbo.#TempBrokerDataSell2') is not null
			drop table #TempBrokerDataSell2

		select *
		into #TempBrokerDataSell2
		from
		(
			select 
				case when BrokerCode in ('WeaSec', 'CMCMar', 'ComSec') then 'Retail' else BrokerCode end as BrokerCode,
				ASXCode,
				avg(nullif(BuyPrice, 0)) as BuyPrice,
				avg(nullif(SellPrice, 0)) as SellPrice,
				sum(NetVolume) as NetVolume,
				sum(NetValue) as NetValue,
				row_number() over (partition by ASXCode order by sum(NetVolume) asc) as RowNumber
			from #TempBrokerDataSell
			group by 
				case when BrokerCode in ('WeaSec', 'CMCMar', 'ComSec') then 'Retail' else BrokerCode end,
				ASXCode
		) as x
		where x.RowNumber in (1)
		and x.BrokerCode = 'Retail'

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[PrevClose] decimal(20, 4),
			ObservationDate date
		)

		if @pintNumPrevDay = 0
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, a.ObservationDate
			from StockData.PriceSummaryToday as a
			where ObservationDate = @dtObservationDate
			and DateTo is null

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			from StockData.PriceSummary as a
			where ObservationDate = @dtObservationDate
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
				[PrevClose],
				ObservationDate
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			from StockData.PriceSummary as a
			where ObservationDate = @dtObservationDate
			and a.LatestForTheDay = 1

			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose],
				ObservationDate
			from StockData.StockStatsHistoryPlus as a
			where ObservationDate = @dtObservationDate
			and not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and ObservationDate = a.ObservationDate
			)			
			
		end

		if @pbitASXCodeOnly = 0
		begin

			if object_id(N'Tempdb.dbo.#TempRetailSell') is not null
				drop table #TempRetailSell

			select distinct
				'BrokerBuyRetailSell' as ReportType,			
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				--cast(j.MedianTradeValue/c.MC as decimal(10, 2)) as MedianTradeValueVsMC,
				b.ASXCode,
				@dtObservationDate as ObservationDate,
				ttsu.FriendlyNameList,
				a.[Close],
				c.MC,
				c.CashPosition,
				cast(b.BuyPrice/100.0 as decimal(20, 3)) as BrokerBuyPrice,
				@dtStartBRDate as BRStartDate,
				@dtMaxBRDate as BREndDate,
				b.BrokerCode as BuyBroker,
				b.RowNumber as BuyBrokerRank,
				b.NetValue as BuyBrokerNetValue,
				b.NetVolume as BuyBrokerNetVolume,
				d.BrokerCode as SellBroker,
				d.RowNumber as SellBrokerRank,
				d.NetValue as SellBrokerNetValue,
				d.NetVolume as SellBrokerNetVolume,
				m.BrokerCode as ObservationDateBuyBroker,
				n.BrokerCode as ObservationDateSellBroker,
				m2.BrokerCode as RecentBuyBroker,
				n2.BrokerCode as RecentSellBroker,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d
			into #TempRetailSell
			from #TempBrokerData as b
			inner join #TempBrokerDataSell2 as d
			on b.ASXCode = d.ASXCode
			and d.SellPrice > 0
			and b.BuyPrice > 0
			left join #TempPriceSummary as a
			on a.ASXCode = b.ASXCode
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
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
			left join 
			(
				select ASXCode, MedianTradeValue, MedianTradeValueDaily, MedianPriceChangePerc 
				from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			left join LookupRef.BrokerName as bn
			on b.BrokerCode = bn.BrokerCode
			where 1 = 1
			--and
			--(case when TrendMovingAverage60d = '' then 'Up' else TrendMovingAverage60d end = 'Up')
			--and 
			--(case when TrendMovingAverage200d = '' then 'Up' else TrendMovingAverage200d end = 'Up')
			and b.BuyPrice < 10000
			and b.NetValue > 50000
			and 
			(
				cast(j.MedianTradeValue/c.MC as decimal(10, 2)) > 10
				or
				j.MedianTradeValue > 1000
			)
			and j.MedianPriceChangePerc > 1.5

			select distinct
				x.ReportType,
				x.MedianTradeValue,
				x.ASXCode,
				x.ObservationDate,
				x.[Close],
				x.MC,
				x.CashPosition,
				avg(x.BrokerBuyPrice) as BrokerBuyPrice,
				x.BRStartDate,
					stuff((
				select ',' + [BuyBroker]
				from #TempRetailSell as a
				where x.ASXCode = a.ASXCode
				order by BuyBrokerRank desc
				for xml path('')), 1, 1, ''
				) as [BuyBroker],
				sum(x.BuyBrokerNetValue) as BuyBrokerNetValue,
				sum(x.BuyBrokerNetVolume) as BuyBrokerNetVolume,
				SellBroker,
				SellBrokerNetValue,
				SellBrokerNetVolume,
				ObservationDateBuyBroker,
				ObservationDateSellBroker,
				RecentBuyBroker,
				RecentSellBroker,
				TrendMovingAverage60d,
				TrendMovingAverage200d
			from #TempRetailSell as x
			group by 
				x.ReportType,
				x.MedianTradeValue,
				x.ASXCode,
				x.ObservationDate,
				x.[Close],
				x.MC,
				x.CashPosition,
				x.BRStartDate,
				SellBroker,
				SellBrokerNetValue,
				SellBrokerNetVolume,
				ObservationDateBuyBroker,
				ObservationDateSellBroker,
				RecentBuyBroker,
				RecentSellBroker,
				TrendMovingAverage60d,
				TrendMovingAverage200d
			order by sum(x.BuyBrokerNetValue) desc;
		end
		else
		begin

			if object_id(N'Tempdb.dbo.#TempOutput') is not null
				drop table #TempOutput

			select 
				identity(int, 1, 1) as DisplayOrder,
				'BrokerBuyRetailSell' as ReportType,			
				format(j.MedianTradeValue, 'N0') as MedianTradeValue,
				b.ASXCode,
				@dtObservationDate as ObservationDate,
				ttsu.FriendlyNameList,
				a.[Close],
				c.MC,
				c.CashPosition,
				b.BuyPrice as BrokerBuyPrice,
				@dtStartBRDate as BRStartDate,
				@dtMaxBRDate as BREndDate,
				b.BrokerCode as BuyBroker,
				b.RowNumber as BuyBrokerRank,
				format(b.NetValue, 'N0') as BuyBrokerNetValue,
				format(b.NetVolume, 'N0') as BuyBrokerNetVolume,
				d.BrokerCode as SellBroker,
				d.RowNumber as SellBrokerRank,
				format(d.NetValue, 'N0') as SellBrokerNetValue,
				format(d.NetVolume, 'N0') as SellBrokerNetVolume,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d
			into #TempOutput
			from #TempBrokerData as b
			inner join #TempBrokerDataSell2 as d
			on b.ASXCode = d.ASXCode
			and d.SellPrice > 0
			and b.BuyPrice > 0
			left join #TempPriceSummary as a
			on a.ASXCode = b.ASXCode
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue, MedianTradeValueDaily, MedianPriceChangePerc 
				from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where 1 = 1
			--and
			--(case when TrendMovingAverage60d = '' then 'Up' else TrendMovingAverage60d end = 'Up')
			--and 
			--(case when TrendMovingAverage200d = '' then 'Up' else TrendMovingAverage200d end = 'Up')
			and b.BuyPrice < 10000
			and b.NetValue > 100000
			and j.MedianPriceChangePerc > 1.5

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
