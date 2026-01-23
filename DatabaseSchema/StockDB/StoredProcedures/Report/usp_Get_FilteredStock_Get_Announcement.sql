-- Stored procedure: [Report].[usp_Get_FilteredStock_Get_Announcement]




CREATE PROCEDURE [Report].[usp_Get_FilteredStock_Get_Announcement]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_Get_FilteredStock.sql
Stored Procedure Name: usp_Get_FilteredStock
Overview
-----------------
usp_Get_FilteredStock

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
Date:		2024-11-02
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_FilteredStock'
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
		if object_id(N'Tempdb.dbo.#TempActiveStocks') is not null
			drop table #TempActiveStocks;

		WITH daily_stats AS (
			SELECT 
				ASXCode, 
				ObservationDate, 
				Volume * VWAP as DailyValue,
				Trades,
				[Close]
			FROM Transform.PriceHistorySecondarySMART
			WHERE ObservationDate >= DATEADD(day, -20, GETDATE())
			--WHERE ObservationDate >= DATEADD(day, -20, '2025-06-13')
		),
		activity_days AS (
			SELECT 
				ASXCode,
				COUNT(*) as total_days,
				SUM(CASE WHEN DailyValue > 200000 AND Trades > 20 AND [Close] > 0.02 AND [Close] < 1.0 
						THEN 1 ELSE 0 END) as active_days,
				AVG(DailyValue) as avg_daily_value,
				AVG(Trades) as avg_trades,
				AVG([Close]) as avg_close
			FROM daily_stats
			GROUP BY ASXCode
		)
		SELECT DISTINCT ASXCode
		into #TempActiveStocks
		FROM activity_days
		WHERE 
			total_days >= 10  -- at least 10 trading days
			AND active_days >= (total_days * 0.3)  -- at least 50% of days meet criteria
			AND avg_daily_value > 100000
			AND avg_trades > 20
			AND avg_close > 0.02 
			AND avg_close < 1.0

		select StockCode,  cast(getdate() as date) as ObservationDate
		from
		(
			select ASXCode as StockCode
			from #TempActiveStocks as a
			group by ASXCode
			union
			select ASXCode as StockCode
			from StockData.MonitorStock as a with(nolock)
			where MonitorTypeID in ('M', 'X')
			and isnull(PriorityLevel, 999) <= 100
			union
			select distinct ASXCode as StockCode
			from Transform.PriceHistory24Month
			where TodayChange >= 8
			and [Value] > 200000
			and ObservationDate > dateadd(day, -30, getdate())
			--union
			--select distinct ASXCode
			--from StockData.v_MarketScan_Latest as a with(nolock)
			--where 1 = 1
			----and ObservationDate = @pdtObservationDate
			--and ObservationDate >= dateadd(day, -5, getdate())
			--and PriceChange > 5
			--and TradeValue > 200
			--and ClosePrice > 0.02 
			--and ClosePrice < 5
			--union
			--select 
			--	ASXCode
			--from Transform.PriceHistory
			--where 1 = 1
			--and ObservationDate >= dateadd(day, -5, getdate())
			--and PriceChangeVsPrevClose > 5
			--and PriceChangeVsOpen > 0
			--and [Value] > 200000
			--and [Close] > 0.01 
			--and [Close] < 5
		) as x
		where 1 = 1 
		and StockCode in ('WWI.AX', 'AR1.AX', 'DTR.AX', 'LLM.AX', 'SGQ.AX', '4DX.AX', 'BMG.AX', 'AW1.AX', 'AVM.AX', 'PNN.AX', 'BM8.AX', 'BNZ.AX', 'GRL.AX', 'VTX.AX', 'IMR.AX', 'TVN.AX', 'HWK.AX', 'ORD.AX', 'CAY.AX', '3DA.AX')
		--and StockCode in ('WWI.AX', 'AR1.AX')
		order by newid()

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
