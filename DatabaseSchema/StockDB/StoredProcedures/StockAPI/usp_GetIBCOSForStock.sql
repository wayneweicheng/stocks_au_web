-- Stored procedure: [StockAPI].[usp_GetIBCOSForStock]


CREATE PROCEDURE [StockAPI].[usp_GetIBCOSForStock]
@pbitDebug AS BIT = 0,
@pdtObservationDate as date = null,
@pbitBackSeriesMode as bit = 0,
@pbitGetAllStocks as bit = 0,
@pintProcessID as int = null,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetIBCOSForStock.sql
Stored Procedure Name: usp_GetIBCOSForStock
Overview
-----------------
usp_GetIBCOSForStock

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockAPI].[usp_GetIBCOSForStock]
@pdtObservationDate = '2023-10-09',
@pbitBackSeriesMode = 0,
@pbitGetAllStocks = 0,
@pintProcessID = 1

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2022-07-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetIBCOSForStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
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
		--declare @pdtObservationDate as date = getdate()

		if @pdtObservationDate is null
			select @pdtObservationDate = cast(getdate() as date)

		if @pintProcessID = -1
			select @pintProcessID = null

		declare @dtMinus2Days as date
		select @dtMinus2Days = Common.DateAddBusinessDay_Plus(-2,@pdtObservationDate)

		if @pbitBackSeriesMode = 1
		begin
			if @pbitGetAllStocks = 0
			begin
				--declare @pdtObservationDate as date = '2024-11-25'

				select 
					a.[ASXCode],
					substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					isnull(b.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastDateTime
				from 
				(
					--select ASXCode 
					--from Transform.MostTradedSmallCap with(nolock)
					--union
					select ASXCode 
					from StockData.MonitorStock as a with(nolock)
					where MonitorTypeID in ('M', 'X')
					and isnull(PriorityLevel, 999) <= 199
					--and datediff(minute, CreateDate, getdate()) < 30
					--union
					--select ASXCode
					--from StockData.BuyCloseSellOpen with(nolock)
				) as a 
				left join 
				(
					select ASXCode, dateadd(second, 1, max(SaleDateTime)) as SaleDateTime
					from StockData.StockCOSSaleTime
					where ObservationDate = @pdtObservationDate
					group by ASXCode
				) as b
				on a.ASXCode = b.ASXCode
				where cast(isnull(b.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as time) < '16:10:00'
				order by a.ASXCode
			end
			else
			begin
				--declare @pdtObservationDate as date
				--declare @pintProcessID as int
				--if @pdtObservationDate is null
				--	select @pdtObservationDate = cast(getdate() as date)

				--if @pintProcessID = -1
				--	select @pintProcessID = null

				--declare @dtMinus2Days as date
				--select @dtMinus2Days = Common.DateAddBusinessDay_Plus(-2,@pdtObservationDate)
				
				select 
					a.[ASXCode],
					substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					isnull(b.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastDateTime
				from 
				(
					select distinct ASXCode --, AvgValue, AvgTrades
					from
					(
						select ASXCode, ObservationDate, avg(Volume*VWAP) as AvgValue, avg(Trades) as AvgTrades
						from Transform.PriceHistorySecondarySMART
						where ObservationDate >= dateadd(day, -20, getdate())
						group by ASXCode, ObservationDate
						having 1 = 1 
						and avg(Volume*VWAP) > 30000
						and avg(Volume*VWAP) < 5000000
						and avg(Trades) > 8
						and avg([Close]) > 0.02
						and avg([Close]) < 5.0
					) as a
					union
					select distinct ASXCode
					from StockData.v_MarketScan_Latest as a with(nolock)
					where 1 = 1
					--and ObservationDate = @pdtObservationDate
					and ObservationDate >= @dtMinus2Days
					and PriceChange > 5
					and TradeValue > 200
					and ClosePrice > 0.02 
					and ClosePrice < 5
					union
					select 
						ASXCode
					from Transform.PriceHistory
					where 1 = 1
					and ObservationDate >= @dtMinus2Days
					and PriceChangeVsPrevClose > 5
					and PriceChangeVsOpen > 0
					and [Value] > 200000
					and [Close] > 0.02 
					and [Close] < 5
				) as a 
				left join 
				(
					select ASXCode, dateadd(second, 1, max(SaleDateTime)) as SaleDateTime
					from StockData.StockCOSSaleTime
					where ObservationDate = @pdtObservationDate
					group by ASXCode
				) as b
				on a.ASXCode = b.ASXCode
				order by a.ASXCode
			end
		end
		else
		begin	
			if (datepart(hour, getdate()) between 16 and 23)
			begin
				--declare @pdtObservationDate as date = '2024-11-26'
				--declare @pintProcessID as int = 0

				if object_id(N'Tempdb.dbo.#TempASXCode') is not null
					drop table #TempASXCode

				select 
					identity(int, 1, 1) as UniqueKey,
					a.[ASXCode],
					substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					isnull(b.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastSaleDateTime,
					isnull(c.BidAskDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastBidAskDateTime,
					checksum(a.ASXCode + cast(b.SaleDateTime as varchar(100))) as HashKey
				into #TempASXCode
				from 
				(
					select distinct ASXCode --, AvgValue, AvgTrades
					from
					(
						select ASXCode, ObservationDate, avg(Volume*VWAP) as AvgValue, avg(Trades) as AvgTrades
						from Transform.PriceHistorySecondarySMART
						where ObservationDate >= dateadd(day, -20, getdate())
						group by ASXCode, ObservationDate
						having 1 = 1 
						and avg(Volume*VWAP) > 30000
						and avg(Volume*VWAP) < 5000000
						and avg(Trades) > 8
						and avg([Close]) > 0.02
						and avg([Close]) < 5.0
					) as a
					union
					select distinct ASXCode
					from StockData.v_MarketScan_Latest as a with(nolock)
					where 1 = 1
					--and ObservationDate = @pdtObservationDate
					and ObservationDate >= @dtMinus2Days
					and PriceChange > 5
					and TradeValue > 200
					and ClosePrice > 0.02 
					and ClosePrice < 5
					union
					select 
						ASXCode
					from Transform.PriceHistory
					where 1 = 1
					and ObservationDate >= @dtMinus2Days
					and PriceChangeVsPrevClose > 5
					and PriceChangeVsOpen > 0
					and [Value] > 200000
					and [Close] > 0.02 
					and [Close] < 5
				) as a 
				left join 
				(
					select ASXCode, dateadd(second, 1, max(SaleDateTime)) as SaleDateTime
					from StockData.StockCOSSaleTime
					where ObservationDate = @pdtObservationDate
					group by ASXCode
				) as b
				on a.ASXCode = b.ASXCode
				left join 
				(
					select ASXCode, dateadd(second, 1, max(ObservationTime)) as BidAskDateTime
					from StockData.StockBidAsk
					where ObservationDate = @pdtObservationDate
					group by ASXCode
				) as c
				on a.ASXCode = c.ASXCode
				where 1 = 1
				and cast(isnull(b.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as time) <= '16:09:59'
				order by a.ASXCode

				select *
				from #TempASXCode
				where (abs(UniqueKey)%5 = @pintProcessID or @pintProcessID is null)
			end
			else
			begin
				--declare @pdtObservationDate as date = getdate()
				--declare @pintProcessID as int = null

				if object_id(N'Tempdb.dbo.#TempASXCode2') is not null
					drop table #TempASXCode2
				
				--declare @pdtObservationDate as date = getdate()
				select 
					identity(int, 1, 1) as UniqueKey,
					a.[ASXCode],
					substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					isnull(b.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastSaleDateTime,
					isnull(c.BidAskDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastBidAskDateTime,
					checksum(a.ASXCode + cast(b.SaleDateTime as varchar(100))) as HashKey
				into #TempASXCode2
				from 
				(
					--declare @pdtObservationDate as date = '2023-11-14'
					select ASXCode 
					from StockData.MonitorStock as a with(nolock)
					where MonitorTypeID in ('M', 'X')
					and isnull(PriorityLevel, 999) <= 199
					union
					select distinct ASXCode
					from StockAPI.PushNotification as a with(nolock)
					where Title like '%30mins alert triggered%'
					and cast(CreateDate as date) >= Common.DateAddBusinessDay(-3, getdate())
					union
					select distinct ASXCode
					from StockData.v_MarketScan_Latest as a with(nolock)
					where 1 = 1
					--and ObservationDate = @pdtObservationDate
					and ObservationDate >= @dtMinus2Days
					and PriceChange > 5
					and TradeValue > 200
					and ClosePrice > 0.02 
					and ClosePrice < 5
					union
					select 
						ASXCode
					from Transform.PriceHistory
					where 1 = 1
					and ObservationDate >= cast(Common.DateAddBusinessDay(-1 * (0 + 2), getdate()) as date)
					and ObservationDate <= cast(Common.DateAddBusinessDay(-1 * (0 + 1), getdate()) as date)
					and PriceChangeVsPrevClose > 5
					and PriceChangeVsOpen > 0
					and [Value] > 200000
					and [Close] > 0.02
					and [Close] < 5
				) as a 
				left join 
				(
					select ASXCode, dateadd(second, 1, max(SaleDateTime)) as SaleDateTime
					from StockData.CourseOfSaleSecondaryToday
					where ObservationDate = @pdtObservationDate
					group by ASXCode
				) as b
				on a.ASXCode = b.ASXCode
				left join 
				(
					select ASXCode, dateadd(second, 1, max(ObservationTime)) as BidAskDateTime
					from StockData.StockBidAsk
					where ObservationDate = @pdtObservationDate
					group by ASXCode
				) as c
				on a.ASXCode = c.ASXCode
				where a.ASXCode not in ('14D.AX')
				order by a.ASXCode

				select *
				from #TempASXCode2
				where (abs(UniqueKey)%5 = @pintProcessID or @pintProcessID is null)
				--and ASXCode in ('MEK.AX')
				order by ASXCode
			end
			
		end

		return

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

	--	IF @@TRANCOUNT > 0
	--	BEGIN
	--		ROLLBACK TRANSACTION
	--	END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
