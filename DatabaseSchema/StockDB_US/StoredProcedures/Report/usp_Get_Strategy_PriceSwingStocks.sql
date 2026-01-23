-- Stored procedure: [Report].[usp_Get_Strategy_PriceSwingStocks]


CREATE PROCEDURE [Report].[usp_Get_Strategy_PriceSwingStocks]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0
AS
/******************************************************************************
File: usp_Get_Strategy_PriceSwingStocks.sql
Stored Procedure Name: usp_Get_Strategy_PriceSwingStocks
Overview
-----------------
usp_Get_Strategy_PriceSwingStocks

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
Date:		2020-07-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_PriceSwingStocks'
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
		--declare @pintNumPrevDay as int = 4
		declare @dtObservationDate as date = dateadd(day, -1 * @pintNumPrevDay, cast(getdate() as date))	

		if object_id(N'Tempdb.dbo.#TempIntraDayData') is not null 
			drop table #TempIntraDayData

		select 
			*, 
			row_number() over (partition by ASXCode order by TimeIntervalStart asc) as RowNumber, 
			row_number() over (partition by ASXCode order by TimeIntervalStart desc) as RevRowNumber, 
			cast(null as decimal(20, 4)) as DayOpen,
			cast(null as decimal(20, 4)) as DayClose
		into #TempIntraDayData
		from [StockData].[PriceHistoryTimeFrame]
		where TimeFrame = '1M'
		and ObservationDate = @dtObservationDate

		update a
		set a.DayOpen = b.[Open]
		from #TempIntraDayData as a
		inner join #TempIntraDayData as b
		on a.ASXCode = b.ASXCode
		and b.RowNumber = 1

		update a
		set a.DayClose = b.[Open]
		from #TempIntraDayData as a
		inner join #TempIntraDayData as b
		on a.ASXCode = b.ASXCode
		and b.RevRowNumber = 1

		select 
			z.ObservationDate StartObservationDate,
			'Price Swing Stocks' as ReportType,
			z.ASXCode,
			z.ObservationDate as EndObservationDate,
			z.DayOpen,
			z.DayClose,
			z.PriceLowTime,
			z.PriceLow,
			z.RetestOpenTime,
			z.RetestOpenPrice,
			z.PriceSwing,
			mt.CleansedMarketCap, 
			mt.MedianTradeValue, 
			mt.MedianTradeValueDaily, 
			mt.MedianPriceChangePerc,
			rps.PriceChange, 
			cast(rps.RelativePriceStrength as decimal(10, 2)) as RelativePriceStrength
		from 
		(
			select *, row_number() over (partition by ASXCode order by RetestOpenTime) as PriceSwingRank
			from
			(
				select x.ObservationDate, x.ASXCode, x.DayOpen, x.DayClose, x.TimeIntervalStart as PriceLowTime, x.[Low] as PriceLow, y.TimeIntervalStart as RetestOpenTime, y.[Close] as RetestOpenPrice, cast((y.[Close] - x.[Low])*100.0/x.[Low] as decimal(10, 2)) as PriceSwing
				from 
				(
					select *, row_number() over (partition by ASXCode order by [Low] asc) as IntraDayRank
					from #TempIntraDayData as a
					where [Low] < DayOpen*(1-0.03) 
					and [Low] > 0
					and cast(TimeIntervalStart as time) < cast('11:00:00' as time)
					--and ASXCode = 'OPY.AX'
				) as x
				inner join
				(
					select *, row_number() over (partition by ASXCode order by [TimeIntervalStart] asc) as IntraDayRank
					from #TempIntraDayData as a
					where [Close] > DayOpen
					and cast(TimeIntervalStart as time) < cast('15:00:00' as time)
					and cast(TimeIntervalStart as time) > cast('11:30:00' as time)
					--and ASXCode = 'OPY.AX'
				) as y
				on x.ASXCode = y.ASXCode
				and x.TimeIntervalStart < y.TimeIntervalStart
				and x.IntraDayRank = 1
			) as PriceSwing
		) as z
		left join StockData.MedianTradeValue as mt
		on z.ASXCode = mt.ASXCode
		left join StockData.RelativePriceStrength as rps
		on z.ASXCode = rps.ASXCode
		and z.ObservationDate = rps.ObservationDate
		where z.PriceSwingRank = 1
		order by PriceSwing desc 

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
