-- Stored procedure: [BackTest].[usp_GetReport]





CREATE PROCEDURE [BackTest].[usp_GetReport]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintExecutionID int = null,
@pvchExecutionIDList varchar(100) = null,
@pintMaxBuyPrice decimal(10,2) = null,
@pintMinBuyPrice decimal(10,2) = null,
@pintMaxIncreasePerc int = null,
@pintMinIncreasePerc int = null
AS
/******************************************************************************
File: usp_GetReport.sql
Stored Procedure Name: usp_GetReport
Overview
-----------------
usp_GetReport

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
Date:		2016-06-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetReport'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'BackTest'
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
		--declare @pvchExecutionIDList as varchar(100) = '1795|1796|1797|1798|1799|1800|1801|1802'
		--declare @pintExecutionID as int = null

		if object_id(N'Tempdb.dbo.#TempStrategyExecutionID ') is not null
			drop table #TempStrategyExecutionID 

		create table #TempStrategyExecutionID
		(
			StrategyExecutionID int
		)

		if @pvchExecutionIDList is not null
		begin
			insert into #TempStrategyExecutionID
			(
				StrategyExecutionID
			)
			select distinct StrValue as StrategyExecutionID
			from DA_Utility.[dbo].[ufn_ParseStringByDelimiter](1, '|', @pvchExecutionIDList)
		end

		if object_id(N'Tempdb.dbo.#TempStrategyExecution') is not null
			drop table #TempStrategyExecution

		select a.*, cast(null as bit) as IsRemoved, cast(null as bit) as IsReused 
		into #TempStrategyExecution
		from BackTest.StrategyExecution as a
		left join StockData.PriceHistoryWeekly as y
		on a.ASXCode = y.ASXCode
		and a.ObservationDate = y.WeekCloseDate
		where 
		(
			(@pintExecutionID is not null and ExecutionID = @pintExecutionID)
			or
			(
				(@pvchExecutionIDList is not null) 
				and exists
				(
					select 1
					from #TempStrategyExecutionID
					where StrategyExecutionID = a.ExecutionID
				)
			)
		)
		and (@pintMaxBuyPrice is null or ActualBuyPrice <= @pintMaxBuyPrice)
		and (@pintMinBuyPrice is null or ActualBuyPrice >= @pintMinBuyPrice)
		and 
		(
			@pintMaxIncreasePerc is null 
			or
			(
				@pintMaxIncreasePerc >= ObservationDayPriceIncreasePerc
			)
		)
		and 
		(
			@pintMinIncreasePerc is null 
			or
			(
				@pintMinIncreasePerc <= ObservationDayPriceIncreasePerc
			)
		)
		and ProfitLost < 10000
		--and 1 - case when ([high] - [low]) = 0 then null else ([high] - [close])*1.0/([high] - [low]) end > 0.50
		--and ObservationDate < '2016-08-01' 
		and ObservationDate >= '2016-09-01'
		
		declare @intStrategyExecutionID as int
		declare @intSupplierStrategyExecutionID as int
		declare curStrategyExecution cursor for
		select StrategyExecutionID
		from #TempStrategyExecution
		order by StrategyExecutionID desc

		open curStrategyExecution

		fetch curStrategyExecution into @intStrategyExecutionID

		while @@FETCH_STATUS = 0
		begin
			select @intSupplierStrategyExecutionID = null
			--print @intStrategyExecutionID

			select top 1 @intSupplierStrategyExecutionID = StrategyExecutionID
			from #TempStrategyExecution
			where ActualSellDateTime < (select ActualBuyDateTime from #TempStrategyExecution where StrategyExecutionID = @intStrategyExecutionID)
			and isnull(IsReused, 0) != 1
			order by ActualSellDateTime desc, StrategyExecutionID desc

			if @intSupplierStrategyExecutionID is not null
			begin
				update a
				set IsRemoved = 1
				from #TempStrategyExecution as a
				where StrategyExecutionID = @intStrategyExecutionID

				update a
				set IsReused = 1
				from #TempStrategyExecution as a
				where StrategyExecutionID = @intSupplierStrategyExecutionID
			end

			fetch curStrategyExecution into @intStrategyExecutionID

		end

		close curStrategyExecution
		deallocate curStrategyExecution

		declare @decTotalRequiredInvestment as decimal(20, 4)
		select @decTotalRequiredInvestment = sum(BuyTotalValue) 
		from #TempStrategyExecution
		where IsRemoved is null

		declare @intNumOfDays as int
		select @intNumOfDays = datediff(day, min(ActualBuyDateTime), max(ActualSellDateTime))
		from #TempStrategyExecution

		if object_id(N'Tempdb.dbo.#TempTradeDayByMonth') is not null
			drop table #TempTradeDayByMonth

		select Year(ActualBuyDateTime) as [Year], month(ActualBuyDateTime) as [Month], datediff(day, min(ActualBuyDateTime), max(ActualSellDateTime)) as NumOfDays
		into #TempTradeDayByMonth
		from #TempStrategyExecution
		group by Year(ActualBuyDateTime), month(ActualBuyDateTime)

		select 
			count(*) as TotalTransaction, 
			sum(ProfitLost) as TotalProfitOrLoss,
			sum(BuyTotalValue) as TotalTradeSize, 
			sum(ProfitLost) as TotalProfit,
			@decTotalRequiredInvestment as TotalRequiredInvestment,
			sum(case when ProfitLost > 0 then 1 else 0 end) as ProfitTransaction, 
			count(*) - sum(case when ProfitLost > 0 then 1 else 0 end) as LossTransaction,
			sum(case when ProfitLost > 0 then 1 else 0 end)*100.0/count(*) as TradeProfitPercentage,
			@intNumOfDays as TradeNumberOfDays,
			(sum(ProfitLost)*100.0/@decTotalRequiredInvestment)*365.0/@intNumOfDays as ROI
		from #TempStrategyExecution
		
		select 
			Year(ActualBuyDateTime) as [Year], 
			month(ActualBuyDateTime) as [Month],
			count(*) as TotalTransaction, 
			sum(ProfitLost) as TotalProfitOrLoss,
			sum(BuyTotalValue) as TotalTradeSize, 
			@decTotalRequiredInvestment as TotalRequiredInvestment,
			sum(case when ProfitLost > 0 then 1 else 0 end) as ProfitTransaction, 
			count(*) - sum(case when ProfitLost > 0 then 1 else 0 end) as LossTransaction,
			sum(case when ProfitLost > 0 then 1 else 0 end)*100.0/count(*) as TradeProfitPercentage,
			max(b.NumOfDays) as TradeNumberOfDays,
			(sum(ProfitLost)*100.0/@decTotalRequiredInvestment)*365.0/30 as ROI
		from #TempStrategyExecution as a
		inner join #TempTradeDayByMonth as b
		on Year(a.ActualBuyDateTime) = b.[Year]
		and month(a.ActualBuyDateTime) = b.[Month]
		group by Year(ActualBuyDateTime), month(ActualBuyDateTime)
		order by Year(ActualBuyDateTime), month(ActualBuyDateTime)

		select x.*, 
			cast((x.ActualSellPrice - x.EntryPrice)*100.0/x.EntryPrice as decimal(10, 2)) as PriceChange, 
			1 - case when ([high] - [low]) = 0 then null else ([high] - [close])*1.0/([high] - [low]) end as CIPR
		from BackTest.StrategyExecution as x
		left join StockData.PriceHistoryWeekly as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.WeekCloseDate
		where ExecutionID in (
			select StrategyExecutionID
			from #TempStrategyExecutionID
		)
		and EntryPrice between @pintMinBuyPrice and @pintMaxBuyPrice
		order by ProfitLost desc


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
