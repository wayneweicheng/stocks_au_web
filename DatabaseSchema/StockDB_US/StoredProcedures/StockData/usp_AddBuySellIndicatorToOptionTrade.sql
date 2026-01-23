-- Stored procedure: [StockData].[usp_AddBuySellIndicatorToOptionTrade]



CREATE PROCEDURE [StockData].[usp_AddBuySellIndicatorToOptionTrade]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddOptionTrade.sql
Stored Procedure Name: usp_AddOptionTrade
Overview
-----------------
usp_AddOptionTrade

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
Date:		2022-07-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOptionTrade'
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
		--begin transaction
		if object_id(N'Tempdb.dbo.#TempOptionBuySellIndicator') is not null
			drop table #TempOptionBuySellIndicator

		select a.SignificantOptionTradeID, a.OptionSymbol,
				case when a.Price = b.PriceBid then 'S' 
					else case when a.Price = b.PriceAsk then 'B'
								else null
							end
				end as BuySellIndicator
		into #TempOptionBuySellIndicator
		from StockData.SignificantOptionTrade as a with(nolock)
		inner join StockData.OptionBidAsk as b with(nolock)
		on a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and a.BuySellIndicator is null
		and a.SaleTime > Common.DateAddBusinessDay(-3, getdate())

		update a
		set BuySellIndicator = 'B'
		from StockData.SignificantOptionTrade as a
		where exists
		(
			select 1
			from #TempOptionBuySellIndicator 
			where SignificantOptionTradeID = a.SignificantOptionTradeID 
			and BuySellIndicator = 'B'
		)
		and not exists
		(
			select 1
			from #TempOptionBuySellIndicator 
			where SignificantOptionTradeID = a.SignificantOptionTradeID 
			and BuySellIndicator = 'S'
		)
		and a.BuySellIndicator is null;

		update a
		set BuySellIndicator = 'S'
		from StockData.SignificantOptionTrade as a
		where exists
		(
			select 1
			from #TempOptionBuySellIndicator 
			where SignificantOptionTradeID = a.SignificantOptionTradeID 
			and BuySellIndicator =  'S'
		)
		and not exists
		(
			select 1
			from #TempOptionBuySellIndicator 
			where SignificantOptionTradeID = a.SignificantOptionTradeID 
			and BuySellIndicator =  'B'
		)
		and a.BuySellIndicator is null;

		if object_id(N'Tempdb.dbo.#TempOptionBuySellIndicatorAvg') is not null
			drop table #TempOptionBuySellIndicatorAvg

		select OptionSymbol, ObservationTime, avg(PriceBid) as PriceBid, avg(PriceAsk) as PriceAsk
		into #TempOptionBuySellIndicatorAvg
		from StockData.OptionBidAsk as b with(nolock)
		group by OptionSymbol, ObservationTime

		update a
		set BuySellIndicator = 'B'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicatorAvg as b
		on a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and b.PriceAsk <= a.Price
		and a.BuySellIndicator is null;

		update a
		set BuySellIndicator = 'S'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicatorAvg as b
		on a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and b.PriceBid >= a.Price
		and a.BuySellIndicator is null;

		update a
		set BuySellIndicator = 'B'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicatorAvg as b
		on a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and 2*(b.PriceAsk - a.Price) < (a.Price - b.PriceBid)
		and b.PriceAsk > a.Price
		and a.Price > b.PriceBid
		and a.BuySellIndicator is null;

		update a
		set BuySellIndicator = 'S'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicatorAvg as b
		on a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and 2*(a.Price - b.PriceBid) < (b.PriceAsk - a.Price)
		and b.PriceAsk > a.Price
		and a.Price > b.PriceBid
		and a.BuySellIndicator is null;

		declare @dtDate as date = Common.DateAddBusinessDay(-4, getdate())

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

		select *
		into #TempOptionBidAsk
		from StockData.OptionBidAsk as b
		where b.ObservationTime > @dtDate 

		if object_id(N'Tempdb.dbo.#TempOptionBuySellIndicator2') is not null
			drop table #TempOptionBuySellIndicator2

		select identity(int, 1, 1) as UniqueKey, x.*
		into #TempOptionBuySellIndicator2
		from
		(
			select distinct a.OptionSymbol, b.OptionBidAskID, b.PriceAsk, b.PriceBid, b.SizeBid, b.SizeAsk, b.ObservationTime, b.CreateDateTime
			from StockData.SignificantOptionTrade as a with(nolock)
			inner join #TempOptionBidAsk as b with(nolock)
			on a.OptionSymbol = b.OptionSymbol
			and b.ObservationTime > dateadd(second, -60, a.SaleTime)
			and b.ObservationTime < dateadd(second, 60, a.SaleTime)
			--and a.SignificantOptionTradeID = 1233
		) as x
		order by x.ObservationTime, x.OptionBidAskID

		if object_id(N'Tempdb.dbo.#TempOptionBuySellIndicator3') is not null
			drop table #TempOptionBuySellIndicator3

		select 
			*, 
			lead(OptionBidAskID) over (partition by OptionSymbol order by OptionBidAskID) as NextOptionBidAskID,
			lead(ObservationTime) over (partition by OptionSymbol order by OptionBidAskID) as NextObservationTime,
			lead(PriceBid) over (partition by OptionSymbol order by OptionBidAskID) as NextPriceBid,
			lead(PriceAsk) over (partition by OptionSymbol order by OptionBidAskID) as NextPriceAsk,
			cast(null as int) as BidGoDown,
			cast(null as int) as BidGoUp,
			cast(null as int) as AskGoDown,
			cast(null as int) as AskGoUp
		into #TempOptionBuySellIndicator3
		from #TempOptionBuySellIndicator2
		--where OptionSymbol = 'VLO   220722C00110000'
		order by UniqueKey

		update a
		set BidGoDown = 1
		from #TempOptionBuySellIndicator3 as a
		where PriceBid > NextPriceBid
		and datediff(second, ObservationTime, NextObservationTime) < 5

		update a
		set AskGoDown = 1
		from #TempOptionBuySellIndicator3 as a
		where PriceAsk > NextPriceAsk
		and datediff(second, ObservationTime, NextObservationTime) < 5

		update a
		set BidGoUp = 1
		from #TempOptionBuySellIndicator3 as a
		where PriceBid < NextPriceBid
		and datediff(second, ObservationTime, NextObservationTime) < 5

		update a
		set AskGoUp = 1
		from #TempOptionBuySellIndicator3 as a
		where PriceAsk < NextPriceAsk
		and datediff(second, ObservationTime, NextObservationTime) < 5

		if object_id(N'Tempdb.dbo.#TempOptionBuySellIndicator4') is not null
			drop table #TempOptionBuySellIndicator4

		select OptionSymbol, ObservationTime, sum(isnull(BidGoDown, 0) + isnull(AskGoDown, 0)) as DownCount, sum(isnull(BidGoUp, 0) + isnull(AskGoUp, 0)) as UpCount
		into #TempOptionBuySellIndicator4
		from #TempOptionBuySellIndicator3 
		group by OptionSymbol, ObservationTime

		update a
		set BuySellIndicator = 'S'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicator4 as b
		on  a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and b.DownCount > b.UpCount
		and a.BuySellIndicator is null

		update a
		set BuySellIndicator = 'B'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicator4 as b
		on  a.OptionSymbol = b.OptionSymbol
		and a.SaleTime = b.ObservationTime
		and b.DownCount < b.UpCount
		and a.BuySellIndicator is null

		update a
		set BuySellIndicator = 'S'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicator4 as b
		on  a.OptionSymbol = b.OptionSymbol
		and dateadd(second, 1, a.SaleTime) = b.ObservationTime
		and b.DownCount > b.UpCount
		and a.BuySellIndicator is null

		update a
		set BuySellIndicator = 'B'
		from StockData.SignificantOptionTrade as a
		inner join #TempOptionBuySellIndicator4 as b
		on  a.OptionSymbol = b.OptionSymbol
		and dateadd(second, 1, a.SaleTime) = b.ObservationTime
		and b.DownCount < b.UpCount
		and a.BuySellIndicator is null

		update a
		set LongShortIndicator = 
			case when (b.PorC = 'C' and a.BuySellIndicator = 'B') or (b.PorC = 'P' and a.BuySellIndicator = 'S') then 'Long'
				 when (b.PorC = 'C' and a.BuySellIndicator = 'S') or (b.PorC = 'P' and a.BuySellIndicator = 'B') then 'Short'
				 else 'Unknown'
			end
		from StockData.SignificantOptionTrade as a
		inner join StockData.OptionContract as b
		on a.OptionSymbol = b.OptionSymbol
		
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
