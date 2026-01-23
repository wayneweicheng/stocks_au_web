-- Stored procedure: [StockData].[usp_RefreshTopBrokerBuy]


--exec [StockData].[usp_RefreshTopBrokerBuy]
--@pintNumPrevDay = 3


CREATE PROCEDURE [StockData].[usp_RefreshTopBrokerBuy]
@pbitDebug AS BIT = 0,
@pintNumPrevDay as int = 3,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTopBrokerBuy.sql
Stored Procedure Name: usp_RefreshTopBrokerBuy
Overview
-----------------
usp_GetAlertTypeID

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
Date:		2020-05-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTopBrokerBuy'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--declare @pintNumPrevDay as int = 3

		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate)
		from StockData.BrokerReport
		where ObservationDate not in
		(
			select ObservationDate
			from StockData.BrokerReport
			where dateadd(day, -10, getdate()) < ObservationDate 
			group by ObservationDate
			having count(*) < 12000
		)

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, @dtMaxDate) as date)

		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition
		) as x
		where RowNumber = 1

		delete a
		from #TempCashPosition as a
		where datediff(day, AnnDateTime, getdate()) > 105

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, @dtDate as ObservationStartDate, @dtMaxDate as ObservationEndDate, sum(NetValue) as NetValue, cast(avg(BuyPrice) as decimal(20, 3)) as AvgBuyPrice
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate >= @dtDate
		and BuyPrice > 0
		group by ASXCode, BrokerCode

		if object_id(N'Tempdb.dbo.#TempTopBrokerRecentBuy') is not null
			drop table #TempTopBrokerRecentBuy

		select x.*, y.MC
		into #TempTopBrokerRecentBuy
		from
		(
			select *, row_number() over (partition by ASXCode order by NetValue desc) as RowNumber
			from #TempBRAggregate
		) as x
		left join #TempCashVsMC as y
		on x.ASXCode = y.ASXCode
		where RowNumber <= 2
		and BrokerCode in ('ArgSec', 'BelPot', 'EurSec', 'Macqua', 'PerShn', 'ShaSto')

		delete a
		from [StockData].[TopBrokerRecentBuy] as a
		where [NumPrevDay] = @pintNumPrevDay

		insert into [StockData].[TopBrokerRecentBuy]
		(
		   [ASXCode]
		  ,[BrokerCode]
		  ,[NetValue]
		  ,[AvgBuyPrice]
		  ,[RowNumber]
		  ,[MC]
		  ,[NumPrevDay]
		  ,ObservationStartDate
		  ,ObservationEndDate
		)
		select
		   [ASXCode]
		  ,[BrokerCode]
		  ,[NetValue]
		  ,[AvgBuyPrice]
		  ,[RowNumber]
		  ,[MC]
		  ,@pintNumPrevDay as [NumPrevDay]
		  ,ObservationStartDate
		  ,ObservationEndDate
		from #TempTopBrokerRecentBuy
		
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
