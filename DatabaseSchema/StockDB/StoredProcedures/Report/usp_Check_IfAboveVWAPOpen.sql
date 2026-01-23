-- Stored procedure: [Report].[usp_Check_IfAboveVWAPOpen]


CREATE PROCEDURE [Report].[usp_Check_IfAboveVWAPOpen]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchObservationDate as varchar(50) = null,
@pintCustomIntegerValue as int = 0,
@pbitIncludePositiveOnly as bit = 0
AS
/******************************************************************************
File: usp_Check_IfAboveVWAPOpen.sql
Stored Procedure Name: usp_Check_IfAboveVWAPOpen
Overview
-----------------
usp_Check_IfAboveVWAPOpen

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
Date:		2022-05-31
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Check_IfAboveVWAPOpen'
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
		--declare @pvchASXCode as varchar(10) = 'CXO.AX'
		--declare @pvchObservationDate as varchar(50) = '2022-06-10 13:57:00'
		--declare @pintCustomIntegerValue as int = 0
		--declare @pbitDebug as bit = 0
		--declare @pbitIncludePositiveOnly as bit = 0
		
		declare @dtObservationDate as datetime

		if @pvchObservationDate is null
			select @dtObservationDate = cast(getdate() as datetime)
		else
			select @dtObservationDate = cast(@pvchObservationDate as datetime)

		--select @dtObservationDate

		if object_id(N'Tempdb.dbo.#TempStockTickerDetailsParsed') is not null
			drop table #TempStockTickerDetailsParsed

		select 
			*, 
			case when [open] > 0 and vwap > 0 and [bid] >= [open] and bid >= vwap then 1 else 0 end as AboveVWAPOpen, 
			row_number() over (order by CurrentTime desc) as RowNumber,
			cast(0 as bit) as SignalStart
		into #TempStockTickerDetailsParsed
		from StockData.StockTickerDetailsParsed
		where ObservationDate = cast(@dtObservationDate as date)
		and CurrentTime <= @dtObservationDate
		and ASXCode = @pvchASXCode
		and auctionVolume = 0
		and bid < ask

		declare @decOrderPrice as decimal(20, 4)

		select @decOrderPrice = case when @pintCustomIntegerValue = 0 then bid
									 when @pintCustomIntegerValue = 1 then ask
									 else [last]
								end
		from
		(
			select bid, ask, [last], row_number() over (order by CurrentTime desc) as RowNumber
			from #TempStockTickerDetailsParsed
		) as x
		where x.RowNumber = 1

		if @pbitDebug = 1
		begin
			select @dtObservationDate as ObservationDate, 'Y' as ReturnValue, @decOrderPrice as OrderPrice
			return
		end

		--update a
		--set AboveVWAPOpen = 1
		--from #TempStockTickerDetailsParsed as a
		--where StockTickerDetailsParsed > 1464

		--update a
		--set AboveVWAPOpen = 0
		--from #TempStockTickerDetailsParsed as a
		--where StockTickerDetailsParsed in (1512, 1538)

		--update a
		--set AboveVWAPOpen = 1
		--from #TempStockTickerDetailsParsed as a
		--where StockTickerDetailsParsed in (908, 910, 917, 919)

		update a
		set SignalStart = 1
		from #TempStockTickerDetailsParsed as a
		inner join
		(
			select StockTickerDetailsParsed, row_number() over (order by CurrentTime asc) as RowNumber
			from #TempStockTickerDetailsParsed as a
			where AboveVWAPOpen = 1
			and not exists
			(
				select 1
				from #TempStockTickerDetailsParsed 
				where CurrentTime > a.CurrentTime
				and AboveVWAPOpen = 0
			)
		) as b
		on a.StockTickerDetailsParsed = b.StockTickerDetailsParsed
		where b.RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempNumObs') is not null
			drop table #TempNumObs

		create table #TempNumObs
		(
			AboveVWAPOpen bit,
			NumObservations int
		)

		insert into #TempNumObs
		(
			AboveVWAPOpen,
			NumObservations
		)
		select
			0 as AboveVWAPOpen,
			0 as NumObservations
		union
		select
			1 as AboveVWAPOpen,
			0 as NumObservations

		update a
		set a.NumObservations = b.NumObservations
		from #TempNumObs as a
		inner join
		(
			select 
				AboveVWAPOpen, 
				count(*) as NumObservations
			from #TempStockTickerDetailsParsed
			where volume > 0
			and [open] > 0
			and CurrentTime >= (select dateadd(minute, -30, CurrentTime) from #TempStockTickerDetailsParsed where SignalStart = 1)
			and cast(CurrentTime as time) > cast('10:10:00.500' as time)
			and CurrentTime < (select CurrentTime from #TempStockTickerDetailsParsed where SignalStart = 1)
			group by AboveVWAPOpen
		) as b
		on a.AboveVWAPOpen = b.AboveVWAPOpen

		--select * from #TempNumObs
		--select * from #TempStockTickerDetailsParsed

		if 1 = 1
		--and exists(
		--	select 1
		--	from #TempNumObs as a
		--	inner join #TempNumObs as b
		--	on 1 = 1
		--	where a.AboveVWAPOpen = 1
		--	and b.AboveVWAPOpen = 0
		--	and b.NumObservations > (a.NumObservations + b.NumObservations)*0.95
		--)
		and exists(
			select 1
			from #TempStockTickerDetailsParsed
			where SignalStart = 1
			and datediff(second, CurrentTime, @dtObservationDate) > 0
		)
		and exists(
			select 1
			from #TempStockTickerDetailsParsed
			where SignalStart = 1
			and datediff(second, CurrentTime, @dtObservationDate) < 60
		)
		and exists(
			select 1
			from #TempStockTickerDetailsParsed
			where SignalStart = 1
			and cast(CurrentTime as time) > cast('10:18:00.500' as time)
			and cast(CurrentTime as time) < cast('15:05:00.500' as time)
		)
		begin
			select @dtObservationDate as ObservationDate, 'Y' as ReturnValue, @decOrderPrice as OrderPrice
			return 
		end

		if @pbitIncludePositiveOnly = 0
		begin
			select @dtObservationDate as ObservationDate, 'N' as ReturnValue, null as OrderPrice
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
