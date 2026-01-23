-- Stored procedure: [StockData].[usp_RefreshBuySellIndicatorPlus]



CREATE PROCEDURE [StockData].[usp_RefreshBuySellIndicatorPlus]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintPrevNumDay as int = 1
AS
/******************************************************************************
File: usp_RefreshBuySellIndicatorPls.sql
Stored Procedure Name: usp_RefreshBuySellIndicatorPls
Overview
-----------------
usp_RefreshBuySellIndicatorPls

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockData].[usp_RefreshBuySellIndicatorPlus]
@pintPrevNumDay = 2

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBuySellIndicatorPlus'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--update a
		--set ActBuySellInd = null
		--from StockData.CourseOfSale as a
		--where ActBuySellInd is not null
		--declare @pintPrevNumDay as int = 1
		declare @dtObservationDate as date = Common.DateAddBusinessDay(-1*@pintPrevNumDay, getdate()) 
		--select @dtObservationDate = '2023-02-07'

		if object_id(N'Tempdb.dbo.#TempOptionBidAskFull') is not null
			drop table #TempOptionBidAskFull

		if object_id(N'Tempdb.dbo.#TempOptionBidAskFullRank') is not null
			drop table #TempOptionBidAskFullRank

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

		if object_id(N'Tempdb.dbo.#TempOptionBidAskPlus') is not null
			drop table #TempOptionBidAskPlus

		select *
		into #TempOptionBidAskFull
		from
		(
			select 
				*
			from StockData.OptionBidAsk with(nolock)
			--where OptionSymbol = 'SPY230208C00415000'
		) as x
		where 1 = 1
		and ObservationDateLocal = @dtObservationDate
		order by ObservationTime

		select 
			*,
			row_number() over (partition by OptionSymbol, ObservationTime order by OptionBidAskID) as RowNumber 	
		into #TempOptionBidAskFullRank
		from #TempOptionBidAskFull

		select *
		into #TempOptionBidAsk
		from #TempOptionBidAskFullRank as x
		where RowNumber = 1
		order by ObservationTime

		select *, 
			lead(SizeBid, 1) over (partition by OptionSymbol order by ObservationTime asc) as NextSizeBid,
			lead(SizeAsk, 1) over (partition by OptionSymbol order by ObservationTime asc) as NextSizeAsk,  
			lead(PriceBid, 1) over (partition by OptionSymbol order by ObservationTime asc) as NextPriceBid,
			lead(PriceAsk, 1) over (partition by OptionSymbol order by ObservationTime asc) as NextPriceAsk,
			lead(ObservationTime, 1) over (partition by OptionSymbol order by ObservationTime asc) as NextObservationTime
		into #TempOptionBidAskPlus
		from #TempOptionBidAsk
		where 1 = 1
		order by ObservationTime

		update a
		set UpDown = null
		from #TempOptionBidAskPlus as a

		update a
		set UpDown = 
					 case when (isnull(NextPriceBid, PriceBid) - PriceBid) + (isnull(NextPriceAsk, PriceAsk) - PriceAsk) > 0 then 'U'
						  when (isnull(NextPriceBid, PriceBid) - PriceBid) + (isnull(NextPriceAsk, PriceAsk) - PriceAsk) < 0 then 'D'
					 end
		from #TempOptionBidAskPlus as a
		where datediff(second, ObservationTime, NextObservationTime) <= 8

		update a
		set UpDown = 
					 case when PriceBid = NextPriceBid and PriceAsk = NextPriceAsk and NextSizeAsk - SizeAsk < NextSizeBid - SizeBid then 'U'
						  when PriceBid = NextPriceBid and PriceAsk = NextPriceAsk and NextSizeAsk - SizeAsk > NextSizeBid - SizeBid then 'D'
					 end
		from #TempOptionBidAskPlus as a
		where a.UpDown is null
		and datediff(second, ObservationTime, NextObservationTime) <= 8

		update a
		set a.UpDown = b.UpDown
		from [StockData].[OptionBidAsk] as a with(nolock)
		inner join #TempOptionBidAskPlus as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ObservationTime = b.ObservationTime
		and a.ObservationDateLocal = @dtObservationDate
		and a.UpDown is null

		if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
			drop table #TempOptionTrade

		select *
		into #TempOptionTrade
		from StockData.OptionTrade as a with(nolock)
		where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')
		and ObservationDateLocal = @dtObservationDate

		update a
		set a.BuySellIndicator = null
		from #TempOptionTrade as a

		if object_id(N'Tempdb.dbo.#TempResult') is not null
			drop table #TempResult

		create table #TempResult
		(
			UniqueKey int identity(1, 1) not null,
			OptionTradeID bigint,
			BuySell varchar(1),
			RuleID int,
			OptionBidAskID bigint
		)

		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		) 
		select distinct
			a.OptionTradeID, 
			'S' as BuySell,
			10 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskFull as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and a.SaleTime = b.ObservationTime
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and a.Price = b.PriceBid and a.Size <= b.SizeBid
		
		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct
			a.OptionTradeID, 
			'B' as BuySell,
			10 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskFull as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and a.SaleTime = b.ObservationTime
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and a.Price = b.PriceAsk and a.Size <= b.SizeAsk
		
		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct 
			a.OptionTradeID, 
			'S' as BuySell,
			20 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskFull as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and a.SaleTime = b.ObservationTime
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and a.Price = b.PriceBid and a.Size > b.SizeBid
		
		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct 
			a.OptionTradeID, 
			'B' as BuySell,
			20 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskFull as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and a.SaleTime = b.ObservationTime
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and a.Price = b.PriceAsk and a.Size > b.SizeAsk	
		
		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct
			a.OptionTradeID, 
			'S' as BuySell,
			30 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskPlus as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and datepart(hour, a.SaleTime) = datepart(hour, b.ObservationTime)
		and datepart(minute, a.SaleTime) = datepart(minute, b.ObservationTime)
		and a.SaleTime >= b.ObservationTime
		and a.SaleTime < b.NextObservationTime
		and datediff(second, b.ObservationTime, a.SaleTime) <= datediff(second, a.SaleTime, b.NextObservationTime)
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and datediff(second, b.ObservationTime, b.NextObservationTime) <= 10
		and a.Price <= b.PriceBid

		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct
			a.OptionTradeID, 
			'B' as BuySell,
			30 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskPlus as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and datepart(hour, a.SaleTime) = datepart(hour, b.ObservationTime)
		and datepart(minute, a.SaleTime) = datepart(minute, b.ObservationTime)
		and a.SaleTime >= b.ObservationTime
		and a.SaleTime < b.NextObservationTime
		and datediff(second, b.ObservationTime, a.SaleTime) <= datediff(second, a.SaleTime, b.NextObservationTime)
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and datediff(second, b.ObservationTime, b.NextObservationTime) <= 10
		and a.Price >= b.PriceAsk

		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct
			a.OptionTradeID, 
			'B' as BuySell,
			100 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskPlus as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and datepart(hour, a.SaleTime) = datepart(hour, b.ObservationTime)
		and datepart(minute, a.SaleTime) = datepart(minute, b.ObservationTime)
		and a.SaleTime >= b.ObservationTime
		and a.SaleTime < b.NextObservationTime
		and datediff(second, b.ObservationTime, a.SaleTime) <= 5
		and datediff(second, a.SaleTime, b.NextObservationTime) <= 5
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and b.UpDown = 'U' 

		insert into #TempResult
		(
			OptionTradeID,
			BuySell,
			RuleID,
			OptionBidAskID
		)
		select distinct
			a.OptionTradeID, 
			'S' as BuySell,
			100 as RuleID,
			b.OptionBidAskID
		from #TempOptionTrade as a
		inner join #TempOptionBidAskPlus as b
		on a.OptionSymbol = b.OptionSymbol
		and a.ASXCode = b.ASXCode
		and datepart(hour, a.SaleTime) = datepart(hour, b.ObservationTime)
		and datepart(minute, a.SaleTime) = datepart(minute, b.ObservationTime)
		and a.SaleTime >= b.ObservationTime
		and a.SaleTime < b.NextObservationTime
		and datediff(second, b.ObservationTime, a.SaleTime) <= 5
		and datediff(second, a.SaleTime, b.NextObservationTime) <= 5
		where a.BuySellIndicator is null
		and b.PriceBid < b.PriceAsk
		and b.UpDown = 'D' 

		if object_id(N'Tempdb.dbo.#TempResultRank') is not null
			drop table #TempResultRank

		select 
			*,
			row_number() over (partition by OptionTradeID order by MinRuleID asc, NumMatch desc, BuySell asc) as RowNumber
		into #TempResultRank
		from
		(
			select OptionTradeID, BuySell, count(OptionBidAskID) as NumMatch, min(RuleID) as MinRuleID
			from #TempResult
			group by OptionTradeID, BuySell
		) as x

		update a
		set a.BuySellIndicator = b.BuySell
		from #TempOptionTrade as a
		inner join #TempResultRank as b
		on a.OptionTradeID = b.OptionTradeID
		and b.RowNumber = 1
		and b.MinRuleID < 100

		update a
		set a.BuySellIndicator = case when b.UpDown = 'U' then 'B' when b.UpDown = 'D' then 'S' end
		from #TempOptionTrade as a
		inner join #TempOptionBidAskPlus as b
		on a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')
		and b.UpDown in ('U', 'D')
		and a.BuySellIndicator is null

		update a
		set a.BuySellIndicator = b.BuySell
		from #TempOptionTrade as a
		inner join #TempResultRank as b
		on a.OptionTradeID = b.OptionTradeID
		and b.RowNumber = 1
		and b.MinRuleID >= 100
		
		update a
		set LongShortIndicator = 
			case when (a.PorC = 'C' and a.BuySellIndicator = 'B') or (a.PorC = 'P' and a.BuySellIndicator = 'S') then 'Long'
					when (a.PorC = 'C' and a.BuySellIndicator = 'S') or (a.PorC = 'P' and a.BuySellIndicator = 'B') then 'Short'
					else 'Unknown'
			end
		from #TempOptionTrade as a
		where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')

		update a
		set a.LongShortIndicator = b.LongShortIndicator,
			a.BuySellIndicator = b.BuySellIndicator
		from StockData.OptionTrade as a with(nolock)
		inner join #TempOptionTrade as b
		on a.OptionTradeID = b.OptionTradeID
		where a.ASXCode in ('SPXW.US', 'SPY.US', 'QQQ.US', 'TLT.US', 'SPX.US')
		and a.ObservationDateLocal = @dtObservationDate
		
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
