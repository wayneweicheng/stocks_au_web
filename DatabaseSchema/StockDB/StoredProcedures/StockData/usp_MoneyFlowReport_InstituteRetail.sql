-- Stored procedure: [StockData].[usp_MoneyFlowReport_InstituteRetail]





create PROCEDURE [StockData].[usp_MoneyFlowReport_InstituteRetail]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode varchar(20),
@pvchBrokerCode varchar(50) = 'All',
@pbitIsMobile as bit = 0
AS
/******************************************************************************
File: usp_MoneyFlowReport_InstituteRetail.sql
Stored Procedure Name: usp_MoneyFlowReport_InstituteRetail
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MoneyFlowReport_InstituteRetail'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;
		--declare @pvchStockCode as varchar(10) = 'PLS.AX'
		--declare @pvchBrokerCode as varchar(50) = 'All'
		declare @numDaysToShow as int = 0
		if @pbitIsMobile = 1
			select @numDaysToShow = 60
		else
			select @numDaysToShow = 120

		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		SELECT [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,cast(case when Volume > 0 then Value/Volume else [Close] end as decimal(20, 4)) as VWAP
			  ,[CreateDate]
			  ,[ModifyDate]
		into #TempPriceHistory
		from [StockData].[PriceHistory] with(nolock)
		where ASXCode = @pvchStockCode

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

		if object_id(N'Tempdb.dbo.#TempUnknownCOS') is not null
			drop table #TempUnknownCOS

		select ASXCode, cast(SaleDateTime as date) as ObservationDate, sum(case when ActBuySellInd is null then 1 else 0 end)*100.0/count(*) as UnknownPerc
		into #TempUnknownCOS
		from StockData.CourseOfSale
		where ASXCode = @pvchStockCode
		group by ASXCode, cast(SaleDateTime as date)
		having sum(case when ActBuySellInd is null then 1 else 0 end)*100.0/count(*) > 25

		if object_id(N'Tempdb.dbo.#TempCOS') is not null
			drop table #TempCOS

		select *
		into #TempCOS
		from StockData.CourseOfSale as a
		where (a.ASXCode = @pvchStockCode or @pvchStockCode is null)
		and ActBuySellInd in ('B', 'S')
		and datediff(day, a.SaleDateTime, getdate()) <= 180
		and not exists
		(
			select 1
			from #TempUnknownCOS
			where ASXCode = @pvchStockCode
			and cast(a.SaleDateTime as date) = ObservationDate
		)

		set identity_insert #TempCOS on
		insert into #TempCOS
		(
		   [CourseOfSaleID]
		  ,[SaleDateTime]
		  ,[Price]
		  ,[Quantity]
		  ,[ASXCode]
		  ,[CreateDate]
		  ,[ActBuySellInd]
		)
		select
	       0 as [CourseOfSaleID]
		  ,DateFrom as [SaleDateTime]
		  ,[Close] as [Price]
		  ,VolumeDelta as [Quantity]
		  ,[ASXCode]
		  ,DateFrom as [CreateDate]
		  ,BuySellInd as [ActBuySellInd]
		from StockData.PriceSummary as a with(nolock)
		where VolumeDelta > 0
		and ASXCode = @pvchStockCode
		and not exists
		(
			select 1
			from #TempCOS
			where ASXCode = a.ASXCode
			and cast(SaleDateTime as date) = cast(a.DateFrom as date)
		)
		set identity_insert #TempCOS off

		set identity_insert #TempCOS on
		insert into #TempCOS
		(
		   [CourseOfSaleID]
		  ,[SaleDateTime]
		  ,[Price]
		  ,[Quantity]
		  ,[ASXCode]
		  ,[CreateDate]
		  ,[ActBuySellInd]
		)
		select
	       0 as [CourseOfSaleID]
		  ,DateFrom as [SaleDateTime]
		  ,[Close] as [Price]
		  ,VolumeDelta as [Quantity]
		  ,[ASXCode]
		  ,DateFrom as [CreateDate]
		  ,BuySellInd as [ActBuySellInd]
		from StockData.PriceSummaryToday as a with(nolock)
		where VolumeDelta > 0
		and ASXCode = @pvchStockCode
		and not exists
		(
			select 1
			from #TempCOS
			where ASXCode = a.ASXCode
			and cast(SaleDateTime as date) = cast(a.DateFrom as date)
		)
		set identity_insert #TempCOS off

		if object_id(N'Tempdb.dbo.#TempResult') is not null
			drop table #TempResult

		select
			a.ASXCode as ASXCode,
			cast(SaleDateTime as date) as ObservationDate,
			cast(cast(SaleDateTime as date) as varchar(100)) as MarketDate,
			cast(sum(case when ActBuySellInd = 'B' then Quantity*Price when ActBuySellInd = 'S' then -1 * Quantity*Price end) as bigint) as MoneyFlowAmount,
			cast(sum(case when ActBuySellInd = 'B' then Quantity*Price else 0 end) as bigint) as MoneyFlowAmountIn,
			cast(sum(case when ActBuySellInd = 'S' then Quantity*Price else 0 end) as bigint) as MoneyFlowAmountOut,
			cast(null as bigint) as CumulativeMoneyFlowAmount,
			format(avg(b.PriceChangePerc), 'P2') as PriceChangePerc,
			format(isnull(sum(case when ActBuySellInd = 'B' then Quantity*Price end)*1.0/sum(Quantity*Price), 0), 'P2') as InPerc,
			format(isnull(sum(case when ActBuySellInd = 'S' then Quantity*Price end)*1.0/sum(Quantity*Price), 0), 'P2') as OutPerc,
			sum(case when ActBuySellInd = 'B' and Quantity*Price > 1000 then 1 end) as InNumTrades,
			sum(case when ActBuySellInd = 'S' and Quantity*Price > 1000 then 1 end) as OutNumTrades,			
			format(sum(case when ActBuySellInd = 'B' and Quantity*Price > 1000 then Quantity*Price end)*1.0/sum(case when ActBuySellInd = 'B' and Quantity*Price > 1000 then 1 end), 'N0') as InAvgSize,
			format(sum(case when ActBuySellInd = 'S' and Quantity*Price > 1000 then Quantity*Price end)*1.0/sum(case when ActBuySellInd = 'S' and Quantity*Price > 1000 then 1 end), 'N0') as OutAvgSize,
			format(avg([Open]), 'N4') as [Open],
			format(avg([High]), 'N4') as [High],
			format(avg([Low]), 'N4') as [Low],
			format(avg([Close]), 'N4') as [Close],
			format(avg([VWAP]), 'N4') as [VWAP],
			format(avg([Volume]), 'N0') as [Volume],
			format(avg([Value]), 'N0') as [Value],
			row_number() over (partition by a.ASXCode order by cast(SaleDateTime as date) desc) as RowNumber,
			cast(null as int) as ReverseRowNumber,
			cast(null as decimal(20, 10)) as NormRatio,
			cast(null as decimal(20, 4)) as XAOPrice,
			avg([Close]) as DecClose
		into #TempResult				
		from #TempCOS as a
		left join #TempPriceSummary as b
		on a.ASXCode = b.ASXCode
		and cast(a.SaleDateTime as date) = cast(b.ObservationDate as date)
		where (a.ASXCode = @pvchStockCode or @pvchStockCode is null)
		and ActBuySellInd in ('B', 'S')
		group by a.ASXCode, cast(SaleDateTime as date)
		order by a.ASXCode, cast(SaleDateTime as date) desc

		update x
		set x.CumulativeMoneyFlowAmount = y.CumulativeMoneyFlowAmount
		from #TempResult as x
		inner join
		(
		select a.ASXCode, a.RowNumber, sum(b.MoneyFlowAmount) as CumulativeMoneyFlowAmount
		from #TempResult as a
		inner join #TempResult as b
		on a.RowNumber <= b.RowNumber
		and a.ASXCode = b.ASXCode
		group by a.ASXCode, a.RowNumber
		) as y
		on x.ASXCode = y.ASXCode
		and x.RowNumber = y.RowNumber

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

		if object_id(N'Tempdb.dbo.#TempInstituteRetailNet') is not null
			drop table #TempInstituteRetailNet

		select
			ASXCode,
			ObservationDate, 
			case when b.BrokerScore >= 0.6 then 'Institute' 
				 when b.BrokerScore < 0 then 'Retail'
			end as InstituteRetailNet,
			sum(NetValue) as NetValue
		into #TempInstituteRetailNet
		from StockData.BrokerReport as a with(nolock)
		inner join LookupRef.BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where a.ObservationDate > dateadd(day, -180, getdate())
		and (@pvchBrokerCode = 'All' or a.BrokerCode = @pvchBrokerCode)
		and a.ASXCode = @pvchStockCode
		group by 
			ASXCode,
			ObservationDate, 
			case when b.BrokerScore >= 0.6 then 'Institute' 
				 when b.BrokerScore < 0 then 'Retail'
			end

		select 
			a.ASXCode,
			MarketDate,
			cast(MoneyFlowAmount/1000.0 as decimal(20, 3)) as MoneyFlowAmount,
			cast(MoneyFlowAmountIn/1000.0 as decimal(20, 3)) as MoneyFlowAmountIn,
			cast(MoneyFlowAmountOut/1000.0 as decimal(20, 3)) as MoneyFlowAmountOut,
			cast(CumulativeMoneyFlowAmount/1000.0 as decimal(20, 3)) as CumulativeMoneyFlowAmount,
			cast(isnull(b.NetValue/1000.0, 0) as int) as InstituteNet,
			cast(isnull(c.NetValue/1000.0, 0) as int) as RetailNet,
			PriceChangePerc,
			InPerc,
			OutPerc,
			InNumTrades,
			OutNumTrades,			
			InAvgSize,
			OutAvgSize,
			[Open],
			[High],
			[Low],
			[Close],
			[VWAP],
			[Volume],
			[Value],
			cast(g.NetVolume/1000.0 as int) as NetVolume,
			RowNumber
		from #TempResult as a
		left join #TempInstituteRetailNet as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and b.InstituteRetailNet = 'Institute'
		left join #TempInstituteRetailNet as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and c.InstituteRetailNet = 'Retail'
		left join #TempPriceHistoryNet as g
		on a.ASXCode = g.ASXCode
		and a.ObservationDate = g.ObservationDate
		where RowNumber <= @numDaysToShow
		order by a.ASXCode, RowNumber desc

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