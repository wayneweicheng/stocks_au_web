-- Stored procedure: [StockData].[usp_RefreshBrokerPerformance]



CREATE PROCEDURE [StockData].[usp_RefreshBrokerPerformance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchMCRange as varchar(100),
@pintXNumDaysPerformance as int = 5
AS
/******************************************************************************
File: usp_RefreshBrokerPerformance.sql
Stored Procedure Name: usp_RefreshBrokerPerformance
Overview
-----------------
usp_RefreshBrokerPerformance

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBrokerPerformance'
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
		declare @pintMinMC as int = 300
		declare @pintMaxMC as int = 10000

		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate)
		from StockData.BrokerReport

		if @pvchMCRange = '0-50M'
		begin
			select @pintMinMC = 0
			select @pintMaxMC = 50
		end
		
		if @pvchMCRange = '50-300M'
		begin
			select @pintMinMC = 50
			select @pintMaxMC = 300
		end
		
		if @pvchMCRange = '300-2000M'
		begin
			select @pintMinMC = 300
			select @pintMaxMC = 2000
		end
		
		if @pvchMCRange = '2000-10000M'
		begin
			select @pintMinMC = 2000
			select @pintMaxMC = 10000
		end

		if object_id(N'Tempdb.dbo.#TempBRPerformance1') is not null
			drop table #TempBRPerformance1

		select a.*, 
			   b.CleansedMarketCap
		into #TempBRPerformance1
		from StockData.BrokerReport as a with(nolock)
		inner join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		where b.CleansedMarketCap > @pintMinMC 
		and b.CleansedMarketCap <= @pintMaxMC
		and (a.NetValue > 10000 or a.NetValue < -10000)
		and ObservationDate >= cast(Common.DateAddBusinessDay(-1 * 400, @dtMaxDate) as date)
		and a.NetVolume != 0

		if object_id(N'Tempdb.dbo.#TempBRPerformance2') is not null
			drop table #TempBRPerformance2

		select BrokerCode, 
			   ASXCode, 
			   ObservationDate,
			   CleansedMarketCap,
			   sum(NetValue) as NetValue, 
			   sum(NetVolume) as NetVolume, 
			   cast(null as decimal(20, 4)) as EntryPrice, 
			   cast(null as bigint) as EntryValue,
			   cast(null as decimal(20, 4)) as ExitPrice, 
			   cast(null as bigint) as ExitValue,
			   cast(null as decimal(10, 2)) as CumulativePerf,
			   case when sum(NetVolume) > 0 then 'Long' else 'Short' end as LongShort,
			   cast(null as decimal(10, 2)) as AggPercReturn,
			   cast(null as decimal(10, 2)) as AggPercOfWin
		into #TempBRPerformance2
		from #TempBRPerformance1
		group by 
			BrokerCode, 
			ASXCode,
			ObservationDate,
			CleansedMarketCap

		update a
		set a.EntryPrice = b.[Open],
			a.EntryValue = b.[Open]*NetVolume
		from #TempBRPerformance2 as a
		inner join StockData.PriceHistory as b
		on a.ASXCode = b.ASXCode
		and cast(Common.DateAddBusinessDay(3, a.ObservationDate ) as date) = b.ObservationDate 
		and b.[Open] > 0

		update a
		set a.ExitPrice = b.[Close],
			a.ExitValue = b.[Close]*NetVolume
		from #TempBRPerformance2 as a
		inner join StockData.PriceHistory as b
		on a.ASXCode = b.ASXCode
		and cast(Common.DateAddBusinessDay(3 + @pintXNumDaysPerformance, a.ObservationDate ) as date) = b.ObservationDate 
		and b.[Close] > 0

		update a
		set CumulativePerf = case when EntryValue = 0 then null else (ExitValue - EntryValue)*100.0/abs(EntryValue) end 
		from #TempBRPerformance2 as a

		update a
		set a.AggPercOfWin = PercOfWin,
			a.AggPercReturn = PercReturn
		from #TempBRPerformance2 as a
		inner join
		(
			select BrokerCode, 
				   LongShort,
				   cast(year(ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(ObservationDate) as varchar(10)), 2) as YearMonth,
				   case when sum(EntryValue) = 0 then null else (sum(ExitValue) - sum(EntryValue))*100.0/abs(sum(EntryValue)) end as PercReturn,
				   avg(CumulativePerf) as AvgReturn, 
				   sum(case when CumulativePerf > 0 then 1 else 0 end)*100.0/count(*) as PercOfWin 
			from #TempBRPerformance2 as a
			where NetVolume != 0
			and CumulativePerf is not null
			group by BrokerCode, LongShort, cast(year(ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(ObservationDate) as varchar(10)), 2)
		) as b
		on a.BrokerCode = b.BrokerCode
		and a.LongShort = b.LongShort
		and cast(year(a.ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(a.ObservationDate) as varchar(10)), 2) = b.YearMonth

		--select top 100 BrokerCode, LongShort, avg(AggPercOfWin), avg(AggPercReturn), count(*)
		--from #TempBRPerformance2
		--group by BrokerCode, LongShort
		--having count(*) > 10
		--order by avg(AggPercOfWin) desc

		--select BrokerCode, LongShort, avg(AggPercOfWin) as WinPercentage, avg(AggPercReturn) as ROI, count(*) as NumTrades
		--from #TempBRPerformance2
		--where LongShort = 'Long'
		--and abs(CumulativePerf) <= 35
		--group by BrokerCode, LongShort
		--having count(*) > 10
		--order by avg(AggPercReturn) desc, avg(AggPercOfWin) desc

		--select 
		--	cast(year(a.ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(a.ObservationDate) as varchar(10)), 2) as YearMonth, 
		--	max(AggPercReturn) as AggPercReturn, 
		--	max(AggPercOfWin) as AggPercOfWin,
		--	count(*) as NumTrade,
		--	count(distinct ASXCode) as NumTradeStock
		--from #TempBRPerformance2 as a
		--where BrokerCode = 'MorgSt'
		--and LongShort = 'Long'
		--and CumulativePerf is not null
		--group by cast(year(a.ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(a.ObservationDate) as varchar(10)), 2)
		--order by cast(year(a.ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(a.ObservationDate) as varchar(10)), 2) desc

		--select NetValue*1.0/NetVolume, * 
		--from #TempBRPerformance2 as a
		--where BrokerCode = 'MorgSt'
		--and LongShort = 'Long'
		--and cast(year(a.ObservationDate) as varchar(10)) + '-' + right('0' + cast(month(a.ObservationDate) as varchar(10)), 2) = '2019-08'
		--and CumulativePerf is not null
		--order by AggPercReturn asc, CumulativePerf asc

		insert into Transform.BrokerInsight
		(
		   [MCRange]
		  ,[NumDays]
		  ,[BrokerCode]
		  ,[ASXCode]
		  ,[ObservationDate]
		  ,[CleansedMarketCap]
		  ,[NetValue]
		  ,[NetVolume]
		  ,[EntryPrice]
		  ,[EntryValue]
		  ,[ExitPrice]
		  ,[ExitValue]
		  ,[CumulativePerf]
		  ,[LongShort]
		  ,[AggPercReturn]
		  ,[AggPercOfWin]
		)
		select 
		   @pvchMCRange as MCRange 
		  ,@pintXNumDaysPerformance as NumDays 
		  ,[BrokerCode]
		  ,[ASXCode]
		  ,[ObservationDate]
		  ,[CleansedMarketCap]
		  ,[NetValue]
		  ,[NetVolume]
		  ,[EntryPrice]
		  ,[EntryValue]
		  ,[ExitPrice]
		  ,[ExitValue]
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
