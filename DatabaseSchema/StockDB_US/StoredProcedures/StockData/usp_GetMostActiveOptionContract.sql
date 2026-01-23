-- Stored procedure: [StockData].[usp_GetMostActiveOptionContract]



CREATE PROCEDURE [StockData].[usp_GetMostActiveOptionContract]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintProcessID as int = 0
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
exec [StockData].[usp_GetMostActiveOptionContract]
@pintProcessID = 1

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMostActiveOptionContract'
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
		declare @dtESTTimeNow as datetime
		select @dtESTTimeNow = CONVERT(DATETIME, GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')
		--select @dtESTTimeNow = CONVERT(DATETIME, dateadd(day, -1, GETDATE()) AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')

		--if cast(@dtESTTimeNow as time) > '09:35:00' and cast(@dtESTTimeNow as time) < '17:05:00'
		--if cast(@dtESTTimeNow as time) > '09:25:00' and cast(@dtESTTimeNow as time) < '23:05:00'
		--declare @pintProcessID as int = 0

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

		-- declare @dtESTTimeNow as datetime
		-- select @dtESTTimeNow = CONVERT(DATETIME, GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')

		select @dtESTTimeNow = cast(Common.DateAddBusinessDay(-1, getdate()) as date)
			
		declare @dtNextExpiryDate as date
		select @dtNextExpiryDate = min(ExpiryDate) 
		from StockData.v_OptionDelayedQuote
		--where ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'SPX.US')
		where ASXCode in ('SPXW.US') 		
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
			and ObservationDate >= Common.DateAddBusinessDay(-3, cast(@dtESTTimeNow as date))
			and ExpiryDate >= @dtNextExpiryDate
			and ExpiryDate <= dateadd(day, case when ASXCode = 'SPX.US' then 60 else 8 end, @dtNextExpiryDate)
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
			Expiry,
			Strike,
			PorC,
			sum(Volume*Bid) as TradeValue,
			cast(@dtESTTimeNow as date) as ObservationDate,
			'Intraday' as Mode
		from StockData.v_OptionDelayedQuote as a
		where ASXCode = 'SPX.US' 
		and ObservationDate >= Common.DateAddBusinessDay(-3, cast(@dtESTTimeNow as date))
		and ExpiryDate >= @dtNextExpiryDate
		and ExpiryDate <= dateadd(day, 60, @dtNextExpiryDate)
		--and OptionSymbol = 'SPY230210C00412000'
		and Volume > 20
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
			'SPXW' as Underlying,
			OptionSymbol, 
			count(*) as NumTrade,
			ExpiryDate,
			0 as ExpiryDateRank,
			Expiry,
			Strike,
			PorC,
			sum(Volume*Bid) as TradeValue,
			cast(@dtESTTimeNow as date) as ObservationDate,
			'Intraday' as Mode
		from StockData.v_OptionDelayedQuote as a
		where ASXCode = 'SPXW.US' 
		and ObservationDate >= Common.DateAddBusinessDay(-3, cast(@dtESTTimeNow as date))
		and ExpiryDate >= @dtNextExpiryDate
		and ExpiryDate <= dateadd(day, 8, @dtNextExpiryDate)
		--and OptionSymbol = 'SPY230210C00412000'
		and Volume > 20
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
			Expiry,
			Strike,
			PorC,
			sum(Volume*Bid) as TradeValue,
			cast(@dtESTTimeNow as date) as ObservationDate,
			'Intraday' as Mode
		from StockData.v_OptionDelayedQuote as a
		where ASXCode in ('SPY.US', 'QQQ.US')
		and ObservationDate >= Common.DateAddBusinessDay(-3, cast(@dtESTTimeNow as date))
		and ExpiryDate >= @dtNextExpiryDate
		and ExpiryDate <= dateadd(day, 8, @dtNextExpiryDate)
		--and Volume > 100
		and not exists
		(
			select 1
			from #TempTodayExpiryOption
			where OptionSymbol = a.OptionSymbol
		)
		group by OptionSymbol, ExpiryDate, Strike, PorC, Expiry, ASXCode

		if object_id(N'Tempdb.dbo.#TempOptionSymbol') is not null
			drop table #TempOptionSymbol

		select distinct OptionSymbol
		into #TempOptionSymbol
		FROM StockData.v_OptionTrade WITH(Nolock)
		-- WHERE ASXCode in ('SPY.US', 'SPXW.US', 'QQQ.US', 'SPX.US')
		WHERE ASXCode in ('SPY.US', 'SPXW.US', 'SPX.US', 'QQQ.US')            
		and ObservationDate = cast(@dtESTTimeNow as date)
		and 
		(
			--(
			--	(ASXCode in ('SPXW.US', 'SPX.US') and Size*Price >= 100)
			--	or
			--	(ASXCode in ('SPY.US') and (Size*Price >= 100 or Size*Price < 20))
			--)
   --         --and 
   --         --isnull(QueryBidNum, 0) <= 3
   --         and 
            isnull(BuySellIndicator, '') not in ('B', 'S')
		)

		select @dtESTTimeNow = CONVERT(DATETIME, GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')

		if cast(@dtESTTimeNow as time) > '07:35:00' and cast(@dtESTTimeNow as time) < '16:35:00'
		begin
			select a.*
			from #TempTodayExpiryOption as a
			inner join #TempOptionDelayedQuote as b
			on a.OptionSymbol = b.OptionSymbol
			inner join
			(
				select Underlying, min(ExpiryDate) as ExpiryDate
				from #TempTodayExpiryOption
				group by Underlying
			) as c
			on a.Underlying = c.Underlying
			and a.ExpiryDate = c.ExpiryDate
			where 1 = 1 
			-- and 
			-- (
				-- c.Underlying is not null
				-- or
				-- (
				-- 	NumTrade > 10
				-- 	or
				-- 	TradeValue > 30000
				-- )
			-- )
			and exists
			(
				select 1
				from #TempOptionSymbol
				where OptionSymbol = a.OptionSymbol
			)
			-- and abs(b.Delta) > 0.02
			--and a.Underlying in ('SPX', 'SPY', 'SPXW', 'QQQ')
			and a.Underlying in ('SPXW')
			and abs(HashKey)%3 = @pintProcessID
			and a.TradeValue > 3000
			order by case when c.Underlying is not null then 1 else 0 end desc,
						case when TradeValue > 20000 then 0 else 1 end asc,
						case when a.Underlying in ('SPY') then 1
							when a.Underlying in ('SPXW') then 2
							when a.Underlying in ('SPX') then 3
						end asc,
						c.ExpiryDate asc, 
						TradeValue desc
		end
		else
		begin
			select top 30 a.*
			from #TempTodayExpiryOption as a
			inner join #TempOptionDelayedQuote as b
			on a.OptionSymbol = b.OptionSymbol
			left join
			(
				select Underlying, min(ExpiryDate) as ExpiryDate
				from #TempTodayExpiryOption
				group by Underlying
			) as c
			on a.Underlying = c.Underlying
			and a.ExpiryDate = c.ExpiryDate
			where 1 = 1 
			-- and 
			-- (
				-- c.Underlying is not null
				-- or
				-- (
				-- 	NumTrade > 10
				-- 	or
				-- 	TradeValue > 30000
				-- )
			-- )
			and TradeValue > 5000
			and exists
			(
				select 1
				from #TempOptionSymbol
				where OptionSymbol = a.OptionSymbol
			)
			-- and abs(b.Delta) > 0.02
			--and a.Underlying in ('SPX', 'SPY', 'SPXW', 'QQQ')
			and a.Underlying in ('SPXW', 'QQQ')
			and abs(HashKey)%3 = @pintProcessID
			and a.TradeValue > case when a.Underlying = 'SPXW' then 3000 else 1000 end
			order by case when c.Underlying is not null then 1 else 0 end desc,
						case when TradeValue > 20000 then 0 
							 when TradeValue > 10000 then 1 
							 else 99
						end asc,
						case when a.Underlying in ('SPY') then 1
							when a.Underlying in ('SPXW') then 2
							when a.Underlying in ('SPX') then 3
							when a.Underlying in ('QQQ') then 4
						end asc,
						c.ExpiryDate asc, 
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
