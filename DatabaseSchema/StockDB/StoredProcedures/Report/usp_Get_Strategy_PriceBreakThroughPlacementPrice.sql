-- Stored procedure: [Report].[usp_Get_Strategy_PriceBreakThroughPlacementPrice]


CREATE PROCEDURE [Report].[usp_Get_Strategy_PriceBreakThroughPlacementPrice]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_PriceBreakThroughPlacementPrice.sql
Stored Procedure Name: usp_Get_Strategy_PriceBreakThroughPlacementPrice
Overview
-----------------
usp_Get_Strategy_PriceBreakThroughPlacementPrice

Input Parameters
----------------
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
Date:		2021-02-27
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_PriceBreakThroughPlacementPrice'
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
		--declare @pintNumPrevDay as int = 6

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 1, getdate()) as date)
		declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -30, getdate()) as date)

		--select @dtObservationDate
		--select @dtObservationDatePrev1 
		--select @dtObservationDatePrevN 

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null 
			drop table #TempPriceSummary

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDate
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempPriceSummaryPrev1') is not null 
			drop table #TempPriceSummaryPrev1

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummaryPrev1
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDatePrev1
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempPriceSummaryPrevN') is not null 
			drop table #TempPriceSummaryPrevN

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummaryPrevN
		from StockData.v_PriceSummary
		where ObservationDate >= @dtObservationDatePrevN
		and ObservationDate <= @dtObservationDate
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate >= Common.DateAddBusinessDay(-8, @dtObservationDate)
		and ObservationDate <= @dtObservationDate
		group by ASXCode, b.DisplayBrokerCode

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

		if @pbitASXCodeOnly = 0
		begin
			select 
				'PriceBreakThroughPlacementPrice' as ReportType,			
				b.PlacementDate, 
				a.ASXCode, 
				a.ObservationDate, 
				b.OfferPrice, 
				a.[close], 
				cast(cast((a.[close] - b.OfferPrice)*100.0/b.OfferPrice as decimal(10, 2)) as varchar(20)) + '%' as PercAbovePlacementPrice,
				c.[Close] as PreviousClose, 
				a.Volume, 
				c.[Close]*a.Volume as TradeValue, 
				d.MovingAverage5dVol,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				ttsu.FriendlyNameList
			from #TempPriceSummaryPrevN as a
			inner join StockData.v_PlaceHistory_Latest as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate > dateadd(day, 20, b.PlacementDate)
			and a.[Close] > b.OfferPrice
			inner join #TempPriceSummaryPrev1 as c
			on a.ASXCode = c.ASXCode
			and c.[Close] <= b.OfferPrice
			inner join [StockData].[v_StockStatsHistoryPlusCurrent] as d
			on a.ASXCode = d.ASXCode
			and not exists
			(
				select 1
				from #TempPriceSummaryPrevN
				where ASXCode = a.ASXCode
				and ObservationDate < a.ObservationDate
				and ObservationDate >= dateadd(day, -5, a.ObservationDate)
				and [Close] > b.OfferPrice
			)
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			left join #TempBrokerReportListLastNDay as m2
			on a.ASXCode = m2.ASXCode
			left join #TempBrokerReportListNegLastNDay as n2
			on a.ASXCode = n2.ASXCode
			where a.Volume > d.MovingAverage5dVol
			and a.ObservationDate > cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 10, getdate()) as date)
			and b.OfferPrice > 0
			order by a.ObservationDate desc;
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
					a.ASXCode, 
					a.ObservationDate, 
					b.PlacementDate, 
					b.OfferPrice, 
					a.[close], 
					cast(cast((a.[close] - b.OfferPrice)*100.0/b.OfferPrice as decimal(10, 2)) as varchar(20)) + '%' as PercAbovePlacementPrice,
					c.[Close] as PreviousClose, 
					a.Volume, 
					c.[Close]*a.Volume as TradeValue, 
					d.MovingAverage5dVol
				from #TempPriceSummaryPrevN as a
				inner join StockData.v_PlaceHistory_Latest as b
				on a.ASXCode = b.ASXCode
				and a.ObservationDate > dateadd(day, 20, b.PlacementDate)
				and a.[Close] > b.OfferPrice
				inner join #TempPriceSummaryPrev1 as c
				on a.ASXCode = c.ASXCode
				and c.[Close] <= b.OfferPrice
				inner join [StockData].[v_StockStatsHistoryPlusCurrent] as d
				on a.ASXCode = d.ASXCode
				and not exists
				(
					select 1
					from #TempPriceSummaryPrevN
					where ASXCode = a.ASXCode
					and ObservationDate < a.ObservationDate
					and ObservationDate >= dateadd(day, -5, a.ObservationDate)
					and [Close] > b.OfferPrice
				)
				where a.Volume > d.MovingAverage5dVol
				and a.ObservationDate > cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 10, getdate()) as date)
				and b.OfferPrice > 0
			) as x
			order by ObservationDate desc;
			
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