-- Stored procedure: [Report].[usp_Get_BrokerBuySuggestion]



CREATE PROCEDURE [Report].[usp_Get_BrokerBuySuggestion]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSortBy as varchar(50) = 'NetValuevsMC',
@pintNumPrevDay as int = 0,
@pintProLevel as smallint = 10,
@pintRetailLevel as smallint = 20,
@pvchBrokerCode as varchar(50) = 'All' 
AS
/******************************************************************************
File: usp_Get_BrokerBuySuggestion.sql
Stored Procedure Name: usp_Get_BrokerBuySuggestion
Overview
-----------------
usp_Get_BrokerBuySuggestion

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
Date:		2018-11-19
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_BrokerBuySuggestion'
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
		if @pvchBrokerCode != 'All'
		begin
			select @pintProLevel = 99
			select @pintRetailLevel = 200	
		end

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

		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate)
		from StockData.BrokerReport
		where ObservationDate not in
		(
			select ObservationDate
			from StockData.BrokerReport
			where dateadd(day, -10, getdate()) < ObservationDate 
			group by ObservationDate
			having count(*) < 12000
		)

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, @dtMaxDate) as date)
		
		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate >= @dtDate
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
		
		if @pvchSortBy = 'NetVolumevsTradeVolume'
		begin
			--declare @pintProLevel as int = 10
			--declare @pintRetailLevel as int = 20
			--declare @dtDate as date = '2019-03-14'
			--declare @pvchBrokerCode as varchar(10) = 'All'

			select top 500 
				a.ASXCode,
				b.MC, 
				b.CashPosition, 
				cast(sum(NetVolume*c.BrokerScore) as decimal(20, 4)) as VolumeIndex,
				sum(TotalVolume) as VolumeTotal,
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end), 'N0') as NetValue,
				cast(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end)/(b.MC*10000) as decimal(20, 4)) as NetValuevsMC,
				format(sum(NetVolume), 'N0') as NetVolume,
				case when sum(d.Volume) = 0 then null 
					 else cast(sum(NetVolume*c.BrokerScore)*100.0/sum(d.Volume) as decimal(20, 4)) 
				end as NetVolumevsTradeVolume,
			    format(avg(h.MedianTradeValue), 'N0') as MedianTradeValue,
				i.BrokerCode as TopBuyBroker,
				j.BrokerCode as TopSellBroker,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature,
				min(a.ObservationDate) as DateStart,
				max(a.ObservationDate) as DateEnd
			from StockData.BrokerReport as a
			inner join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			left join StockData.PriceHistory as d	
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			inner join LookupRef.BrokerName as c
			on a.BrokerCode = c.BrokerCode
			--and (c.BrokerLevel <= @pintProLevel or c.BrokerLevel >= @pintRetailLevel)
			and a.ObservationDate >= @dtDate
			left join Transform.PosterList as f
			on a.ASXCode = f.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join StockData.v_PriceSummary as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			and g.LatestForTheDay = 1
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempBrokerReportList as i
			on a.ASXCode = i.ASXCode
			left join #TempBrokerReportListNeg as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			where (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			group by 
				a.ASXCode,
				b.MC, 
				b.CashPosition,
				i.BrokerCode,
				j.BrokerCode,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature
			having
				sum(a.BuyValue) > 100000
			order by 
				case when sum(d.Volume) = 0 then null 
					 else cast(sum(NetVolume*c.BrokerScore)*100.0/sum(d.Volume) as decimal(20, 4)) 
				end desc
		end

		if @pvchSortBy = 'NetValuevsMC'
		begin
			select top 500 
				a.ASXCode,
				b.MC, 
				b.CashPosition, 
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end), 'N0') as NetValue,
				cast(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end)/(b.MC*10000) as decimal(20, 4)) as NetValuevsMC,
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end), 'N0') as NetVolume,
				case when sum(coalesce(g.[Volume], d.[Volume], 0)) = 0 then null else cast(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end)*100.0/sum(coalesce(g.[Volume], d.[Volume], 0)) as decimal(20, 4)) end as NetVolumevsTradeVolume,
			    format(avg(h.MedianTradeValue), 'N0') as MedianTradeValue,
				i.BrokerCode as TopBuyBroker,
				j.BrokerCode as TopSellBroker,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
			    f.Poster,
				e.Nature,
				min(a.ObservationDate) as DateStart,
				max(a.ObservationDate) as DateEnd
			from StockData.BrokerReport as a
			inner join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			left join StockData.PriceHistory as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			inner join LookupRef.BrokerName as c
			on a.BrokerCode = c.BrokerCode
			and (c.BrokerLevel <= @pintProLevel or c.BrokerLevel >= @pintRetailLevel)
			and a.ObservationDate >= @dtDate
			left join Transform.PosterList as f
			on a.ASXCode = f.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join StockData.v_PriceSummary as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			and g.LatestForTheDay = 1
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempBrokerReportList as i
			on a.ASXCode = i.ASXCode
			left join #TempBrokerReportListNeg as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			where (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			group by 
				a.ASXCode,
				b.MC, 
				b.CashPosition,
				i.BrokerCode,
				j.BrokerCode,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature
			order by cast(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end)/(b.MC*10000) as decimal(20, 4)) desc
		end

		if @pvchSortBy = 'MarketCap'
		begin
			select top 500 
				a.ASXCode,
				b.MC, 
				b.CashPosition, 
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end), 'N0') as NetValue,
				cast(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end)/(b.MC*10000) as decimal(20, 4)) as NetValuevsMC,
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end), 'N0') as NetVolume,
				case when sum(coalesce(g.[Volume], d.[Volume], 0)) = 0 then null else cast(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end)*100.0/sum(coalesce(g.[Volume], d.[Volume], 0)) as decimal(20, 4)) end as NetVolumevsTradeVolume,
			    format(avg(h.MedianTradeValue), 'N0') as MedianTradeValue,
				i.BrokerCode as TopBuyBroker,
				j.BrokerCode as TopSellBroker,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
			    f.Poster,
				e.Nature,
				min(a.ObservationDate) as DateStart,
				max(a.ObservationDate) as DateEnd
			from StockData.BrokerReport as a
			inner join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			inner join StockData.PriceHistory as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			inner join LookupRef.BrokerName as c
			on a.BrokerCode = c.BrokerCode
			and (c.BrokerLevel <= @pintProLevel or c.BrokerLevel >= @pintRetailLevel)
			and a.ObservationDate >= @dtDate
			left join Transform.PosterList as f
			on a.ASXCode = f.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join StockData.v_PriceSummary as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			and g.LatestForTheDay = 1
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempBrokerReportList as i
			on a.ASXCode = i.ASXCode
			left join #TempBrokerReportListNeg as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			where (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			group by 
				a.ASXCode,
				b.MC, 
				b.CashPosition,
				i.BrokerCode,
				j.BrokerCode,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature
			order by b.MC asc
		end

		if @pvchSortBy = 'NetValue'
		begin
			select top 500 
				a.ASXCode,
				b.MC, 
				b.CashPosition, 
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end), 'N0') as NetValue,
				cast(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end)/(b.MC*10000) as decimal(20, 4)) as NetValuevsMC,
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end), 'N0') as NetVolume,
				case when sum(coalesce(g.[Volume], d.[Volume], 0)) = 0 then null else cast(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end)*100.0/sum(coalesce(g.[Volume], d.[Volume], 0)) as decimal(20, 4)) end as NetVolumevsTradeVolume,
				format(avg(h.MedianTradeValue), 'N0') as MedianTradeValue,
				i.BrokerCode as TopBuyBroker,
				j.BrokerCode as TopSellBroker,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature,
				min(a.ObservationDate) as DateStart,
				max(a.ObservationDate) as DateEnd
			from StockData.BrokerReport as a
			inner join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			inner join StockData.PriceHistory as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			inner join LookupRef.BrokerName as c
			on a.BrokerCode = c.BrokerCode
			and (c.BrokerLevel <= @pintProLevel or c.BrokerLevel >= @pintRetailLevel)
			and a.ObservationDate >= @dtDate
			left join Transform.PosterList as f
			on a.ASXCode = f.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join StockData.v_PriceSummary as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			and g.LatestForTheDay = 1
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempBrokerReportList as i
			on a.ASXCode = i.ASXCode
			left join #TempBrokerReportListNeg as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			where (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			group by 
				a.ASXCode,
				b.MC, 
				b.CashPosition,
				i.BrokerCode,
				j.BrokerCode,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature
			order by sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end) desc
		end

		if @pvchSortBy = 'ASXCode'
		begin
			select top 500 
				a.ASXCode,
				b.MC, 
				b.CashPosition, 
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end), 'N0') as NetValue,
				cast(sum(case when c.BrokerLevel <= @pintProLevel then NetValue else -1*NetValue end)/(b.MC*10000) as decimal(20, 4)) as NetValuevsMC,
				format(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end), 'N0') as NetVolume,
				case when sum(coalesce(g.[Volume], d.[Volume], 0)) = 0 then null else cast(sum(case when c.BrokerLevel <= @pintProLevel then NetVolume else -1*NetVolume end)*100.0/sum(coalesce(g.[Volume], d.[Volume], 0)) as decimal(20, 4)) end as NetVolumevsTradeVolume,
			    format(avg(h.MedianTradeValue), 'N0') as MedianTradeValue,
				i.BrokerCode as TopBuyBroker,
				j.BrokerCode as TopSellBroker,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
			    f.Poster,
				e.Nature,
				min(a.ObservationDate) as DateStart,
				max(a.ObservationDate) as DateEnd
			from StockData.BrokerReport as a
			inner join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			inner join StockData.PriceHistory as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			inner join LookupRef.BrokerName as c
			on a.BrokerCode = c.BrokerCode
			and (c.BrokerLevel <= @pintProLevel or c.BrokerLevel >= @pintRetailLevel)
			and a.ObservationDate >= @dtDate
			left join Transform.PosterList as f
			on a.ASXCode = f.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join StockData.v_PriceSummary as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			and g.LatestForTheDay = 1
			left join 
			(
				select ASXCode, MedianTradeValue from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempBrokerReportList as i
			on a.ASXCode = i.ASXCode
			left join #TempBrokerReportListNeg as j
			on a.ASXCode = j.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as l
			on a.ASXCode = l.ASXCode
			where (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			group by 
				a.ASXCode,
				b.MC, 
				b.CashPosition,
				i.BrokerCode,
				j.BrokerCode,
				l.TrendMovingAverage60d,
				l.TrendMovingAverage200d,
				f.Poster,
				e.Nature
			order by a.ASXCode asc
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
