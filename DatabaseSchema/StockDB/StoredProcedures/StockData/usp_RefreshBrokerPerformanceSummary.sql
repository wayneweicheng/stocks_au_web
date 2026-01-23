-- Stored procedure: [StockData].[usp_RefreshBrokerPerformanceSummary]



CREATE PROCEDURE [StockData].[usp_RefreshBrokerPerformanceSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int,
@pintMinMC as int = 100,
@pintMaxMC as int = 5000
AS
/******************************************************************************
File: usp_RefreshBrokerPerformanceSummary.sql
Stored Procedure Name: usp_RefreshBrokerPerformanceSummary
Overview
-----------------
usp_RefreshBrokerPerformanceSummary

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
Date:		2018-08-20
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBrokerPerformanceSummary'
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
		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate)
		from StockData.BrokerReport

--declare @pintNumPrevDay as int = 1
--declare @pintMinMC as int = 200
--declare @pintMaxMC as int = 100000

		if object_id(N'Tempdb.dbo.#TempBRPerformance1') is not null
			drop table #TempBRPerformance1

		select a.*, 
			   b.CleansedMarketCap
		into #TempBRPerformance1
		from StockData.BrokerReport as a
		inner join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		where b.CleansedMarketCap between @pintMinMC and @pintMaxMC
		and (a.NetValue > 10000 or a.NetValue < -10000)
		and ObservationDate >= cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, @dtMaxDate) as date)

		if object_id(N'Tempdb.dbo.#TempBRPerformance2') is not null
			drop table #TempBRPerformance2

		select BrokerCode, 
			   ASXCode, 
			   CleansedMarketCap,
			   min(ObservationDate) as StartDate,
			   max(ObservationDate) as EndDate,
			   sum(NetValue) as NetValue, 
			   sum(NetVolume) as NetVolume, 
			   cast(null as decimal(20, 4)) as HoldPrice, 
			   cast(null as decimal(20, 4)) as CurrentPrice, 
			   cast(null as bigint) as CurrentValue,
			   cast(null as decimal(10, 2)) as CumulativePerf,
			   case when sum(NetVolume) > 0 then 'Long' else 'Short' end as LongShort,
			   cast(null as decimal(10, 2)) as AggPercReturn,
			   cast(null as decimal(10, 2)) as AggPercOfWin
		into #TempBRPerformance2
		from #TempBRPerformance1
		group by 
			BrokerCode, 
			ASXCode,
			CleansedMarketCap

		update a
		set a.CurrentPrice = b.[Close],
			a.CurrentValue = b.[Close]*NetVolume
		from #TempBRPerformance2 as a
		inner join StockData.PriceHistory as b
		on a.ASXCode = b.ASXCode

		update a
		set a.CurrentPrice = b.[Close],
			a.CurrentValue = b.[Close]*NetVolume
		from #TempBRPerformance2 as a
		inner join StockData.PriceHistoryCurrent as b
		on a.ASXCode = b.ASXCode

		delete x
		from #TempBRPerformance2 as x
		where abs(NetValue) < 10000

		update x
		set x.HoldPrice = y.HoldPrice
		from #TempBRPerformance2 as x
		inner join
		(
			select
				a.ASXCode,
				a.BrokerCode,
				case when sum(b.NetVolume) = 0 then null else sum(b.NetValue)*1.0/sum(b.NetVolume) end as HoldPrice
			from #TempBRPerformance2 as a
			inner join #TempBRPerformance1 as b
			on a.ASXCode = b.ASXCode
			and a.BrokerCode = b.BrokerCode
			and a.NetValue > 0
			and b.NetValue > 0
			group by 
				a.ASXCode,
				a.BrokerCode
		) as y
		on x.ASXCode = y.ASXCode
		and x.BrokerCode = y.BrokerCode
		
		update x
		set x.HoldPrice = y.HoldPrice
		from #TempBRPerformance2 as x
		inner join
		(
			select
				a.ASXCode,
				a.BrokerCode,
				case when sum(b.NetVolume) != 0 then sum(b.NetValue)*1.0/sum(b.NetVolume) else null end as HoldPrice
			from #TempBRPerformance2 as a
			inner join #TempBRPerformance1 as b
			on a.ASXCode = b.ASXCode
			and a.BrokerCode = b.BrokerCode
			and a.NetValue < 0
			and b.NetValue < 0
			group by 
				a.ASXCode,
				a.BrokerCode
		) as y
		on x.ASXCode = y.ASXCode
		and x.BrokerCode = y.BrokerCode

		update a
		set CumulativePerf = case when HoldPrice > 0 then (CurrentPrice - HoldPrice)*100.0/HoldPrice
		else (CurrentValue - NetValue)*100.0/abs(NetValue) end 
		from #TempBRPerformance2 as a

		update a
		set a.AggPercOfWin = PercOfWin,
			a.AggPercReturn = PercReturn
		from #TempBRPerformance2 as a
		inner join
		(
			select BrokerCode, 
				   LongShort,
				   case when sum(NetValue) = 0 then null else (sum(CurrentValue) - sum(NetValue))*100.0/abs(sum(NetValue)) end as PercReturn,
				   avg(CumulativePerf) as AvgReturn, 
				   sum(case when CumulativePerf > 0 then 1 else 0 end)*100.0/count(*) as PercOfWin 
			from #TempBRPerformance2 as a
			where NetVolume != 0
			--and CumulativePerf > 0
			group by BrokerCode, LongShort
		) as b
		on a.BrokerCode = b.BrokerCode
		and a.LongShort = b.LongShort

		delete a
		from [Transform].[BrokerInsightSummary] as a
		where NumPrevDay = @pintNumPrevDay

		insert into [Transform].[BrokerInsightSummary]
		(
		   [NumPrevDay]
          ,StartDate
		  ,EndDate
		  ,[BrokerCode]
		  ,[ASXCode]
		  ,[CleansedMarketCap]
		  ,[NetValue]
		  ,[NetVolume]
		  ,[CurrentPrice]
		  ,[CurrentValue]
		  ,[CumulativePerf]
		  ,[LongShort]
		  ,[AggPercReturn]
		  ,[AggPercOfWin]
		)
		select
		   @pintNumPrevDay as [NumPrevDay]
          ,StartDate
		  ,EndDate
		  ,[BrokerCode]
		  ,[ASXCode]
		  ,[CleansedMarketCap]
		  ,[NetValue]
		  ,[NetVolume]
		  ,[CurrentPrice]
		  ,[CurrentValue]
		  ,[CumulativePerf]
		  ,[LongShort]
		  ,[AggPercReturn]
		  ,[AggPercOfWin]
		from #TempBRPerformance2

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
