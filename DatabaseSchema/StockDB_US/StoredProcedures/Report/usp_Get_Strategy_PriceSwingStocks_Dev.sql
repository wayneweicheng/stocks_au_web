-- Stored procedure: [Report].[usp_Get_Strategy_PriceSwingStocks_Dev]


CREATE PROCEDURE [Report].[usp_Get_Strategy_PriceSwingStocks_Dev]
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
		--declare @pintNumPrevDay as int = 1
		declare @dtObservationDate as date = dateadd(day, -1 * @pintNumPrevDay, cast(getdate() as date))	

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null 
			drop table #TempPriceSummary

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDate
		and Volume > 0

		update a
		set a.PreviousDay_Close = a.PrevClose 
		from #TempPriceSummary as a

		if object_id(N'Tempdb.dbo.#TempSwingPrice') is not null 
			drop table #TempSwingPrice
		
		select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom) as SeqNumber
		into #TempSwingPrice
		from
		(
			select 
				a.ASXCode,
				a.[Open],
				a.PreviousDay_Close,
				a.[Close],
				a.DateFrom,
				a.ObservationDate,
				b.[Close] as SwingClose,
				b.DateFrom as SwingDateFrom,
				row_number() over (partition by a.ASXCode, a.DateFrom order by b.DateFrom asc) as SwingRank
			from #TempPriceSummary as a
			inner join #TempPriceSummary as b
			on a.ASXCode = b.ASXCode
			and cast(a.DateFrom as time) <= '10:15:00'
			and cast(b.DateFrom as time) >= '10:20:00'
			and a.RowNumber < b.RowNumber
			and b.[Close] > a.[Open]
			and a.[Close] < a.[Open]*0.99
			and b.[Close]>  b.VWAP
		) as x
		where SwingRank = 1

		select distinct
			z.ObservationDate StartObservationDate,
			'Price Swing Stocks' as ReportType,
			z.ASXCode,
			z.ObservationDate as EndObservationDate,
			z.ASXCode,
			z.[Open] as DayOpen,
			z.PreviousDay_Close,
			z.[Close] as MarketOpenLow,
			z.DateFrom as MarketOpenLowDateTime,
			z.SwingClose,
			z.SwingDateFrom,
			mt.CleansedMarketCap, 
			mt.MedianTradeValue, 
			mt.MedianTradeValueDaily, 
			mt.MedianPriceChangePerc,
			rps.PriceChange as [1YearPriceChange],
			cast(rps.RelativePriceStrength as decimal(10, 2)) as RelativePriceStrength
		from 
		(
			select *
			from #TempSwingPrice
			where SeqNumber = 1
		) as z
		left join StockData.MedianTradeValue as mt
		on z.ASXCode = mt.ASXCode
		left join StockData.RelativePriceStrength as rps
		on z.ASXCode = rps.ASXCode
		and z.ObservationDate = rps.ObservationDate
		where 1 = 1
		order by mt.MedianTradeValueDaily desc 

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
