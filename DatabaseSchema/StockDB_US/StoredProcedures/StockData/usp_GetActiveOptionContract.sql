-- Stored procedure: [StockData].[usp_GetActiveOptionContract]


CREATE PROCEDURE [StockData].[usp_GetActiveOptionContract]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetActiveOptionContract.sql
Stored Procedure Name: usp_GetActiveOptionContract
Overview
-----------------
usp_GetActiveOptionContract

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
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetActiveOptionContract'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here
		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote') is not null
			drop table #TempOptionDelayedQuote

		select a.*
		into #TempOptionDelayedQuote
		from StockData.v_OptionDelayedQuote as a
		inner join 
		(
			select ASXCode, max(ObservationDate) as ObservationDate
			from StockData.v_OptionDelayedQuote
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')

		declare @dtNextExpiryDate as date			
		declare @dtESTTimeNow as datetime
		select @dtESTTimeNow = CONVERT(DATETIME, GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')
		--select @dtESTTimeNow = CONVERT(DATETIME, cast('2023-10-27 06:30:00' as datetime) AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')
		--select @dtESTTimeNow = CONVERT(DATETIME, dateadd(day, -1, GETDATE()) AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')

		if cast(@dtESTTimeNow as time) > '07:35:00' and cast(@dtESTTimeNow as time) < '16:35:00'
		begin
			select @dtESTTimeNow = cast(Common.DateAddBusinessDay(-1, getdate()) as date)
			
			select @dtNextExpiryDate = min(ExpiryDate) 
			from #TempOptionDelayedQuote
			where ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US') 
			and ExpiryDate > cast(@dtESTTimeNow as date)

			if object_id(N'Tempdb.dbo.#TempTodayExpiryOption') is not null
				drop table #TempTodayExpiryOption

			select
				identity(int, 1, 1) as UniqueKey,
				HashKey,
				IsLastContract,
				Underlying,
				OptionSymbol, 
				NumTrade,
				ExpiryDate,
				ExpiryDateRank,
				Expiry,
				Strike,
				PorC,
				TradeValue,
				ObservationDate,
				'Intraday' as Mode
			into #TempTodayExpiryOption
			from
			(
				select 
					checksum(OptionSymbol) as HashKey,
					0 as IsLastContract,
					Underlying,
					OptionSymbol, 
					count(*) as NumTrade,
					ExpiryDate,
					0 as ExpiryDateRank,
					Expiry,
					Strike,
					PorC,
					sum(Size*Price) as TradeValue,
					cast(@dtESTTimeNow as date) as ObservationDate,
					'Intraday' as Mode
				from StockData.v_OptionTrade
				where ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')
				and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
				and ExpiryDate = @dtNextExpiryDate
				--and OptionSymbol = 'SPY230210C00412000'
				group by OptionSymbol, Underlying, ExpiryDate, Expiry, Strike, PorC
			) as x

			insert into #TempTodayExpiryOption
			(
				HashKey,
				IsLastContract,
				Underlying,
				OptionSymbol, 
				NumTrade,
				ExpiryDate,
				ExpiryDateRank,
				Expiry,
				Strike,
				PorC,
				TradeValue,
				ObservationDate,
				Mode
			)
			select 
				checksum(OptionSymbol) as HashKey,
				0 as IsLastContract,
				'SPX' as Underlying,
				OptionSymbol, 
				count(*) as NumTrade,
				ExpiryDate,
				0 as ExpiryDateRank,
				Expiry as Expiry,
				Strike,
				PorC,
				sum(Volume*isnull(LastTradePrice, Bid)) as TradeValue,
				cast(@dtESTTimeNow as date) as ObservationDate,
				'Intraday' as Mode
			from #TempOptionDelayedQuote as a
			where ASXCode = 'SPX.US' 
			and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
			and ExpiryDate = @dtNextExpiryDate
			--and OptionSymbol = 'SPY230210C00412000'
			--and Volume > 20
			and not exists
			(
				select 1
				from #TempTodayExpiryOption
				where OptionSymbol = a.OptionSymbol
			)
			group by OptionSymbol, ExpiryDate, Strike, PorC, Expiry

			insert into #TempTodayExpiryOption
			(
				HashKey,
				IsLastContract,
				Underlying,
				OptionSymbol, 
				NumTrade,
				ExpiryDate,
				ExpiryDateRank,
				Expiry,
				Strike,
				PorC,
				TradeValue,
				ObservationDate,
				Mode
			)
			select 
				checksum(OptionSymbol) as HashKey,
				0 as IsLastContract,
				'SPXW' as Underlying,
				OptionSymbol, 
				count(*) as NumTrade,
				ExpiryDate,
				0 as ExpiryDateRank,
				Expiry as Expiry,
				Strike,
				PorC,
				sum(Volume*isnull(LastTradePrice, Bid)) as TradeValue,
				cast(@dtESTTimeNow as date) as ObservationDate,
				'Intraday' as Mode
			from #TempOptionDelayedQuote as a
			where ASXCode = 'SPXW.US' 
			and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
			and ExpiryDate = @dtNextExpiryDate
			--and OptionSymbol = 'SPY230210C00412000'
			--and Volume > 20
			and not exists
			(
				select 1
				from #TempTodayExpiryOption
				where OptionSymbol = a.OptionSymbol
			)
			group by OptionSymbol, ExpiryDate, Strike, PorC, Expiry
			union
			select 
				checksum(OptionSymbol) as HashKey,
				0 as IsLastContract,
				left(ASXCode, 3) as Underlying,
				OptionSymbol, 
				count(*) as NumTrade,
				ExpiryDate,
				0 as ExpiryDateRank,
				Expiry as Expiry,
				Strike,
				PorC,
				sum(Volume*isnull(LastTradePrice, Bid)) as TradeValue,
				cast(@dtESTTimeNow as date) as ObservationDate,
				'Intraday' as Mode
			from #TempOptionDelayedQuote as a
			where ASXCode in ('SPY.US', 'QQQ.US')
			and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
			and ExpiryDate = @dtNextExpiryDate
			--and Volume > 100
			and not exists
			(
				select 1
				from #TempTodayExpiryOption
				where OptionSymbol = a.OptionSymbol
			)
			group by OptionSymbol, ExpiryDate, Strike, PorC, ASXCode, Expiry

			select a.*
			from #TempTodayExpiryOption as a
			inner join #TempOptionDelayedQuote as b
			on a.OptionSymbol = b.OptionSymbol
			where 1 = 1 
			and 
			(
				TradeValue*100 >= 5000
			)
			and b.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US')
			order by 
				ExpiryDate asc, 
				--case when Underlying = 'SPY' then 10
				--	 when Underlying = 'SPXW' then 20
				--	 when Underlying = 'SPX' then 30
				--	 when Underlying = 'QQQ' then 40
				--	 else 99
				--end asc,			
				TradeValue desc		
		end
		else
		begin
			--declare @dtNextExpiryDate as date			
			--declare @dtESTTimeNow as datetime
			--select @dtESTTimeNow = CONVERT(DATETIME, GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')
			----select @dtESTTimeNow = CONVERT(DATETIME, dateadd(day, -1, GETDATE()) AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')

			select @dtESTTimeNow = cast(Common.DateAddBusinessDay(-1, getdate()) as date)
			
			select @dtNextExpiryDate = min(ExpiryDate) 
			from #TempOptionDelayedQuote
			where ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US') 
			and ExpiryDate > cast(@dtESTTimeNow as date)

			if object_id(N'Tempdb.dbo.#TempTodayExpiryOption2') is not null
				drop table #TempTodayExpiryOption2

			select
				identity(int, 1, 1) as UniqueKey,
				HashKey,
				IsLastContract,
				Underlying,
				OptionSymbol, 
				NumTrade,
				ExpiryDate,
				ExpiryDateRank,
				Expiry,
				Strike,
				PorC,
				TradeValue,
				ObservationDate,
				'Intraday' as Mode
			into #TempTodayExpiryOption2
			from
			(
				select 
					checksum(OptionSymbol) as HashKey,
					0 as IsLastContract,
					Underlying,
					OptionSymbol, 
					count(*) as NumTrade,
					ExpiryDate,
					0 as ExpiryDateRank,
					Expiry,
					Strike,
					PorC,
					sum(Size*Price) as TradeValue,
					cast(@dtESTTimeNow as date) as ObservationDate,
					'Intraday' as Mode
				from StockData.v_OptionTrade
				where ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')
				and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
				and ExpiryDate >= @dtNextExpiryDate
				and ExpiryDate <= dateadd(day, case when ASXCode = 'SPX.US' then 60 else 16 end, cast(@dtNextExpiryDate as date))
				--and OptionSymbol = 'SPY230210C00412000'
				group by OptionSymbol, Underlying, ExpiryDate, Expiry, Strike, PorC
			) as x

			insert into #TempTodayExpiryOption2
			(
				HashKey,
				IsLastContract,
				Underlying,
				OptionSymbol, 
				NumTrade,
				ExpiryDate,
				ExpiryDateRank,
				Expiry,
				Strike,
				PorC,
				TradeValue,
				ObservationDate,
				Mode
			)
			select 
				checksum(OptionSymbol) as HashKey,
				0 as IsLastContract,
				'SPX' as Underlying,
				OptionSymbol, 
				count(*) as NumTrade,
				ExpiryDate,
				0 as ExpiryDateRank,
				Expiry as Expiry,
				Strike,
				PorC,
				sum(Volume*isnull(LastTradePrice, Bid)) as TradeValue,
				cast(@dtESTTimeNow as date) as ObservationDate,
				'Intraday' as Mode
			from #TempOptionDelayedQuote as a
			where ASXCode = 'SPX.US' 
			and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
			and ExpiryDate >= @dtNextExpiryDate
			and ExpiryDate <= dateadd(day, 60, cast(@dtNextExpiryDate as date))
			--and OptionSymbol = 'SPY230210C00412000'
			--and Volume > 20
			and not exists
			(
				select 1
				from #TempTodayExpiryOption2
				where OptionSymbol = a.OptionSymbol
			)
			group by OptionSymbol, ExpiryDate, Strike, PorC, Expiry

			insert into #TempTodayExpiryOption2
			(
				HashKey,
				IsLastContract,
				Underlying,
				OptionSymbol, 
				NumTrade,
				ExpiryDate,
				ExpiryDateRank,
				Expiry,
				Strike,
				PorC,
				TradeValue,
				ObservationDate,
				Mode
			)
			select 
				checksum(OptionSymbol) as HashKey,
				0 as IsLastContract,
				'SPXW' as Underlying,
				OptionSymbol, 
				count(*) as NumTrade,
				ExpiryDate,
				0 as ExpiryDateRank,
				Expiry as Expiry,
				Strike,
				PorC,
				sum(Volume*isnull(LastTradePrice, Bid)) as TradeValue,
				cast(@dtESTTimeNow as date) as ObservationDate,
				'Intraday' as Mode
			from #TempOptionDelayedQuote as a
			where ASXCode = 'SPXW.US' 
			and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
			and ExpiryDate >= @dtNextExpiryDate
			and ExpiryDate <= dateadd(day, 16, cast(@dtNextExpiryDate as date))
			--and OptionSymbol = 'SPY230210C00412000'
			--and Volume > 20
			and not exists
			(
				select 1
				from #TempTodayExpiryOption2
				where OptionSymbol = a.OptionSymbol
			)
			group by OptionSymbol, ExpiryDate, Strike, PorC, Expiry
			union
			select 
				checksum(OptionSymbol) as HashKey,
				0 as IsLastContract,
				left(ASXCode, 3) as Underlying,
				OptionSymbol, 
				count(*) as NumTrade,
				ExpiryDate,
				0 as ExpiryDateRank,
				Expiry as Expiry,
				Strike,
				PorC,
				sum(Volume*isnull(LastTradePrice, Bid)) as TradeValue,
				cast(@dtESTTimeNow as date) as ObservationDate,
				'Intraday' as Mode
			from #TempOptionDelayedQuote as a
			where ASXCode in ('SPY.US', 'QQQ.US')
			and ObservationDate >= dateadd(day, -6, cast(@dtESTTimeNow as date))
			and ExpiryDate >= @dtNextExpiryDate
			and ExpiryDate <= dateadd(day, 16, cast(@dtNextExpiryDate as date))
			--and Volume > 100
			and not exists
			(
				select 1
				from #TempTodayExpiryOption2
				where OptionSymbol = a.OptionSymbol
			)
			group by OptionSymbol, ExpiryDate, Strike, PorC, ASXCode, Expiry

			update a
			set a.ExpiryDateRank = b.ExpiryDateRank
			from #TempTodayExpiryOption2 as a
			inner join
			(
				select Underlying, ExpiryDate, row_number() over (partition by Underlying order by ExpiryDate asc) as ExpiryDateRank
				from #TempTodayExpiryOption2
				group by Underlying, ExpiryDate
			) as b
			on a.Underlying = b.Underlying
			and a.ExpiryDate = b.ExpiryDate
			
			select a.*
			from #TempTodayExpiryOption2 as a
			inner join #TempOptionDelayedQuote as b
			on a.OptionSymbol = b.OptionSymbol
			where 1 = 1 
			and 
			(
				TradeValue*100 >= 5000
			)
			--and b.ASXCode = 'SPX.US'
			order by 
				ExpiryDateRank asc, 
				--case when Underlying = 'SPY' then 10
				--	 when Underlying = 'SPXW' then 20
				--	 when Underlying = 'SPX' then 30
				--	 when Underlying = 'QQQ' then 40
				--	 else 99
				--end asc,			
				TradeValue desc
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
