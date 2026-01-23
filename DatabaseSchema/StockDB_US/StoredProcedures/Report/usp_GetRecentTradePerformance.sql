-- Stored procedure: [Report].[usp_GetRecentTradePerformance]


--exec [StockData].[usp_GetLargetSale]
--@intNumPrevDay = 7



CREATE PROCEDURE [Report].[usp_GetRecentTradePerformance]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetRecentTradePerformance.sql
Stored Procedure Name: usp_GetRecentTradePerformance
Overview
-----------------
usp_GetRecentTradePerformance

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
Date:		2018-06-26
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetRecentTradePerformance'
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
		select 
			ASXCode, 
			dateadd(hour, datepart(hour, DateFrom), cast(cast(DateFrom as date) as smalldatetime)) as DateHour, 
			isnull(BuySellInd, 'U') as BuySellInd, 
			sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
			avg(VWAP)*100.0 as VWAP 
		from StockData.PriceSummary
		where 1 = 1
		--and ASXCode = 'AVZ.AX'
		and VWAP > 0
		group by ASXCode, cast(DateFrom as date), datepart(hour, DateFrom), BuySellInd

		--select 
		--	ASXCode, 
		--	cast(DateFrom as date) as CurrentDate,
		--	isnull(BuySellInd, 'U') as BuySellInd, 
		--	sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
		--	avg(VWAP)*100.0 as VWAP 
		--into #Temp
		--from StockData.PriceSummary
		--where cast(DateFrom as date) = cast(getdate() as date)
		--and VWAP > 0
		--group by ASXCode, cast(DateFrom as date), BuySellInd

		--select a.ASXCode, a.CurrentDate, a.TradeValue as BuyTradeValue, b.TradeValue as SellTradeValue, a.VWAP, a.TradeValue*100.0/b.TradeValue as BuyVsSell 
		--from #Temp as a
		--inner join #Temp as b
		--on a.ASXCode = b.ASXCode
		--and a.CurrentDate = b.CurrentDate
		--and a.BuySellInd = 'B'
		--and b.BuySellInd = 'S'
		--where b.TradeValue > 0
		--and a.TradeValue > 20000
		--order by a.TradeValue*100.0/b.TradeValue desc

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
