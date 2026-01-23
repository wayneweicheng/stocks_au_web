-- Stored procedure: [StockData].[usp_MoneyFlowReport_DEV]





CREATE PROCEDURE [StockData].[usp_MoneyFlowReport_DEV]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode varchar(20),
@pvchBrokerCode varchar(50) = 'All',
@pbitIsMobile as bit = 0,
@intNumPrevDay int = 0, 
@pvchObservationDate date = '2050-12-12',
@pbitBasicBrokerMode as bit = 1
AS
/******************************************************************************
File: usp_MoneyFlowReport.sql
Stored Procedure Name: usp_MoneyFlowReport
Overview
-----------------

Input ParametersW
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
Date:		2016-03-23
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MoneyFlowReport'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--declare @pvchStockCode as varchar(10) = 'MSFT.US'
		--declare @pvchBrokerCode as varchar(50) = 'All'
		
		--declare @pbitIsMobile as bit = 0
		--declare @pvchObservationDate as varchar(20) = '2050-12-12'

		declare @numDaysToShow as int = 0
		if @pbitIsMobile = 1
			select @numDaysToShow = 60
		else
			select @numDaysToShow = 120

		declare @dtEnqDate as date 
		if @pvchObservationDate = '2050-12-12'
		begin
			select @dtEnqDate = dateadd(day, 0, cast(getdate() as date))
		end
		else
		begin
			select @dtEnqDate = cast(@pvchObservationDate as date)	
		end

		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		SELECT [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,VWAP*Volume as [Value]
			  ,VWAP
			  ,[CreateDate]
			  ,[ModifyDate]
		into #TempPriceHistory
		from [StockData].[PriceHistory] with(nolock)
		where ASXCode = @pvchStockCode
		and ObservationDate <= @dtEnqDate

		if object_id(N'Tempdb.dbo.#TempPriceHistoryNet') is not null
			drop table #TempPriceHistoryNet

		SELECT [ASXCode]
			  ,[ObservationDate]
			  ,[NetVolume]
			  ,[NetValue]
			  ,[CreateDate]
		into #TempPriceHistoryNet
		from Transform.PriceHistoryNetVolume with(nolock)
		where ASXCode = @pvchStockCode
		and ObservationDate <= @dtEnqDate

		insert into #TempPriceHistory
		(
			   [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,VWAP
			  ,[CreateDate]
			  ,[ModifyDate]
		)
		select
			   [ASXCode]
			  ,ObservationDate as [ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,VWAP
			  ,DateFrom as [CreateDate]
			  ,DateFrom as [ModifyDate]
		from StockData.PriceSummaryToday with(nolock)
		where ObservationDate > (select max(ObservationDate) from #TempPriceHistory)
		and DateTo is null
		and ASXCode = @pvchStockCode
		and ObservationDate <= @dtEnqDate

		insert into #TempPriceHistory
		(
			   [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,VWAP
			  ,[CreateDate]
			  ,[ModifyDate]
		)
		select
			   [ASXCode]
			  ,ObservationDate as [ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,VWAP
			  ,DateFrom as [CreateDate]
			  ,DateFrom as [ModifyDate]
		from StockData.PriceSummary with(nolock)
		where ObservationDate > (select max(ObservationDate) from #TempPriceHistory)
		and DateTo is null
		and ASXCode = @pvchStockCode
		and ObservationDate <= @dtEnqDate

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *, row_number() over (partition by ASXCode order by cast(ObservationDate as date) desc) as RowNumber, cast(null as decimal(20, 5)) as PriceChangePerc
		into #TempPriceSummary
		from #TempPriceHistory

		update a
		set PriceChangePerc = case when b.[Close] > 0 then (a.[Close] - b.[Close])*1.0/b.[Close] end
		from #TempPriceSummary as a
		inner join #TempPriceSummary as b
		on a.RowNumber + 1 = b.RowNumber
		and a.ASXCode = b.ASXCode

		if object_id(N'Tempdb.dbo.#TempResult') is not null
			drop table #TempResult

		select
			a.ASXCode as ASXCode,
			a.ObservationDate as ObservationDate,
			cast(a.ObservationDate as varchar(100)) as MarketDate,
			cast(sum(a.Volume*a.VWAP) as bigint) as MoneyFlowAmount,
			cast(null as bigint) as CumulativeMoneyFlowAmount,
			format(avg(b.PriceChangePerc), 'P2') as PriceChangePerc,
			format(avg(a.[Open]), 'N4') as [Open],
			format(avg(a.[High]), 'N4') as [High],
			format(avg(a.[Low]), 'N4') as [Low],
			format(avg(a.[Close]), 'N4') as [Close],
			format(avg(case when a.[VWAP] = 0 then a.[Close] else a.[VWAP] end), 'N4') as [VWAP],
			format(avg(a.[Volume]), 'N0') as [Volume],
			format(avg(a.[Value]), 'N0') as [Value],
			row_number() over (partition by a.ASXCode order by a.ObservationDate desc) as RowNumber,
			cast(null as int) as ReverseRowNumber,
			cast(null as decimal(20, 10)) as NormRatio,
			cast(null as decimal(20, 4)) as XAOPrice,
			avg(a.[Close]) as DecClose
		into #TempResult				
		from #TempPriceHistory as a
		left join #TempPriceSummary as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		where (a.ASXCode = @pvchStockCode or @pvchStockCode is null)
		group by a.ASXCode, a.ObservationDate
		order by a.ASXCode, a.ObservationDate desc

		--update x
		--set x.CumulativeMoneyFlowAmount = y.CumulativeMoneyFlowAmount
		--from #TempResult as x
		--inner join
		--(
		--select a.ASXCode, a.RowNumber, sum(b.MoneyFlowAmount) as CumulativeMoneyFlowAmount
		--from #TempResult as a
		--inner join #TempResult as b
		--on a.RowNumber <= b.RowNumber
		--and a.ASXCode = b.ASXCode
		--group by a.ASXCode, a.RowNumber
		--) as y
		--on x.ASXCode = y.ASXCode
		--and x.RowNumber = y.RowNumber

		delete a
		from #TempResult as a
		where RowNumber > @numDaysToShow

		delete a
		from #TempPriceHistoryNet as a
		left join #TempResult as b
		on a.ObservationDate = b.ObservationDate
		where b.ASXCode is null

		update a
		set ReverseRowNumber = b.RowNumber
		from #TempResult as a
		inner join 
		(
			select 
				ObservationDate,
				row_number() over (order by ObservationDate asc) as RowNumber
			from #TempResult
		) as b
		on a.ObservationDate = b.ObservationDate

		--declare @pvchBrokerCode as varchar(50) = null
		--declare @pvchStockCode as varchar(10) = 'FFX.AX'

		if @pbitBasicBrokerMode = 0
		begin
			if object_id(N'Tempdb.dbo.#TempBrokerRetailNet') is not null
				drop table #TempBrokerRetailNet

			select
				ASXCode,
				ObservationDate, 
				case when b.BrokerScore >= 1.2 then 'StrongBroker' 
					 when b.BrokerScore >= 0.6 and b.BrokerScore < 1.2 then 'WeakBroker'
					 when b.BrokerScore >= 0 and b.BrokerScore < 0.6 then 'FlipperBroker'
					 when b.BrokerCode not in ('ComSec') and b.BrokerScore < 0 then 'OtherRetail'
					 when b.BrokerCode in ('ComSec') and b.BrokerScore < 0 then 'ComSec'
				end as BrokerRetailNet,
				sum(NetValue) as NetValue
			into #TempBrokerRetailNet
			from StockData.BrokerReport as a with(nolock)
			inner join LookupRef.BrokerName as b
			on a.BrokerCode = b.BrokerCode
			where a.ObservationDate > dateadd(day, -180, @dtEnqDate)
			and (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			and a.ASXCode = @pvchStockCode
			group by 
				ASXCode,
				ObservationDate, 
				case when b.BrokerScore >= 1.2 then 'StrongBroker' 
					 when b.BrokerScore >= 0.6 and b.BrokerScore < 1.2 then 'WeakBroker'
					 when b.BrokerScore >= 0 and b.BrokerScore < 0.6 then 'FlipperBroker'
					 when b.BrokerCode not in ('ComSec') and b.BrokerScore < 0 then 'OtherRetail'
					 when b.BrokerCode in ('ComSec') and b.BrokerScore < 0 then 'ComSec'
				end

			select 
				a.ASXCode,
				MarketDate,
				cast(MoneyFlowAmount/1000.0 as decimal(20, 3)) as MoneyFlowAmount,
				--cast(MoneyFlowAmountIn/1000.0 as decimal(20, 3)) as MoneyFlowAmountIn,
				--cast(MoneyFlowAmountOut/1000.0 as decimal(20, 3)) as MoneyFlowAmountOut,
				cast(CumulativeMoneyFlowAmount/1000.0 as decimal(20, 3)) as CumulativeMoneyFlowAmount,
				cast(isnull(b.NetValue/1000.0, 0) as int) as StrongBrokerNet,
				cast(isnull(c.NetValue/1000.0, 0) as int) as WeakBrokerNet,
				cast(isnull(d.NetValue/1000.0, 0) as int) as OtherRetailNet,
				cast(isnull(e.NetValue/1000.0, 0) as int) as FlipperBrokerNet,
				cast(isnull(f.NetValue/1000.0, 0) as int) as ComSecNet,
				PriceChangePerc,
				--InPerc,
				--OutPerc,
				--InNumTrades,
				--OutNumTrades,			
				--InAvgSize,
				--OutAvgSize,
				[Open],
				[High],
				[Low],
				[Close],
				VWAP,
				[Volume],
				[Value],
				cast(g.NetVolume/1000.0 as int) as NetVolume,
				RowNumber
			from #TempResult as a
			left join #TempBrokerRetailNet as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.BrokerRetailNet = 'StrongBroker'
			left join #TempBrokerRetailNet as c
			on a.ASXCode = c.ASXCode
			and a.ObservationDate = c.ObservationDate
			and c.BrokerRetailNet = 'WeakBroker'
			left join #TempBrokerRetailNet as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			and d.BrokerRetailNet = 'OtherRetail'
			left join #TempBrokerRetailNet as e
			on a.ASXCode = e.ASXCode
			and a.ObservationDate = e.ObservationDate
			and e.BrokerRetailNet = 'FlipperBroker'
			left join #TempBrokerRetailNet as f
			on a.ASXCode = f.ASXCode
			and a.ObservationDate = f.ObservationDate
			and f.BrokerRetailNet = 'ComSec'
			left join #TempPriceHistoryNet as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			where RowNumber <= @numDaysToShow
			order by a.ASXCode, RowNumber desc

		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempBrokerRetailNetBasic') is not null
				drop table #TempBrokerRetailNetBasic

			select
				ASXCode,
				ObservationDate, 
				case when b.BrokerScore >= 0.6 then 'StrongBroker'
					 when b.BrokerScore >= 0 and b.BrokerScore < 0.6 then 'FlipperBroker'
					 when b.BrokerScore < 0 then 'ComSec'
				end as BrokerRetailNet,
				sum(NetValue) as NetValue
			into #TempBrokerRetailNetBasic
			from StockData.BrokerReport as a with(nolock)
			inner join LookupRef.BrokerName as b
			on a.BrokerCode = b.BrokerCode
			where a.ObservationDate > dateadd(day, -180, getdate())
			and (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
			and a.ASXCode = @pvchStockCode
			group by 
				ASXCode,
				ObservationDate, 
				case when b.BrokerScore >= 0.6 then 'StrongBroker' 
					 when b.BrokerScore >= 0 and b.BrokerScore < 0.6 then 'FlipperBroker'
					 when b.BrokerScore < 0 then 'ComSec'
				end

			select 
				a.ASXCode,
				MarketDate,
				cast(MoneyFlowAmount/1000.0 as decimal(20, 3)) as MoneyFlowAmount,
				--cast(MoneyFlowAmountIn/1000.0 as decimal(20, 3)) as MoneyFlowAmountIn,
				--cast(MoneyFlowAmountOut/1000.0 as decimal(20, 3)) as MoneyFlowAmountOut,
				cast(CumulativeMoneyFlowAmount/1000.0 as decimal(20, 3)) as CumulativeMoneyFlowAmount,
				cast(isnull(b.NetValue/1000.0, 0) as int) as StrongBrokerNet,
				cast(isnull(c.NetValue/1000.0, 0) as int) as WeakBrokerNet,
				cast(isnull(d.NetValue/1000.0, 0) as int) as OtherRetailNet,
				cast(isnull(e.NetValue/1000.0, 0) as int) as FlipperBrokerNet,
				cast(isnull(f.NetValue/1000.0, 0) as int) as ComSecNet,
				PriceChangePerc,
				--InPerc,
				--OutPerc,
				--InNumTrades,
				--OutNumTrades,			
				--InAvgSize,
				--OutAvgSize,
				[Open],
				[High],
				[Low],
				[Close],
				VWAP,
				[Volume],
				[Value],
				cast(g.NetVolume/1000.0 as int) as NetVolume,
				RowNumber
			from #TempResult as a
			left join #TempBrokerRetailNetBasic as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			and b.BrokerRetailNet = 'StrongBroker'
			left join #TempBrokerRetailNetBasic as c
			on a.ASXCode = c.ASXCode
			and a.ObservationDate = c.ObservationDate
			and c.BrokerRetailNet = 'WeakBroker'
			left join #TempBrokerRetailNetBasic as d
			on a.ASXCode = d.ASXCode
			and a.ObservationDate = d.ObservationDate
			and d.BrokerRetailNet = 'OtherRetail'
			left join #TempBrokerRetailNetBasic as e
			on a.ASXCode = e.ASXCode
			and a.ObservationDate = e.ObservationDate
			and e.BrokerRetailNet = 'FlipperBroker'
			left join #TempBrokerRetailNetBasic as f
			on a.ASXCode = f.ASXCode
			and a.ObservationDate = f.ObservationDate
			and f.BrokerRetailNet = 'ComSec'
			left join #TempPriceHistoryNet as g
			on a.ASXCode = g.ASXCode
			and a.ObservationDate = g.ObservationDate
			where RowNumber <= @numDaysToShow
			order by a.ASXCode, RowNumber desc

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