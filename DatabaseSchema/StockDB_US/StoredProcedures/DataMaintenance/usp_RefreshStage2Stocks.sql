-- Stored procedure: [DataMaintenance].[usp_RefreshStage2Stocks]



CREATE PROCEDURE [DataMaintenance].[usp_RefreshStage2Stocks]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshStage2Stocks.sql
Stored Procedure Name: usp_RefreshStage2Stocks
Overview
-----------------
usp_RefreshStage2Stocks

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
Date:		2020-02-22
Author:		WAYNE CHENG
Description: usp_Get_Strategy_BreakoutRetrace
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshStage2Stocks'
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
		--declare @pintNumPrevDay as int = 3
		--select @pintNumPrevDay = @pintNumPrevDay -	 1
		-- Step 2: Calculate Moving Averages and other required metrics

		if object_id(N'StockData.Stage2Stocks') is not null
			drop table StockData.Stage2Stocks;

		-- Calculate the 50-day, 150-day, and 200-day moving averages
		WITH MovingAverages AS (
			SELECT
				ASXCode,
				ObservationDate,
				[Close],
				AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS MA50,
				AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 149 PRECEDING AND CURRENT ROW) AS MA150,
				AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) AS MA200
			FROM
				StockData.PriceHistory
		),
		-- Calculate 52-week low and high
		WeeklyStats AS (
			SELECT
				ASXCode,
				ObservationDate,
				[Close],
				MIN([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 365 PRECEDING AND CURRENT ROW) AS Low52Weeks,
				MAX([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 365 PRECEDING AND CURRENT ROW) AS High52Weeks
			FROM
				StockData.PriceHistory
		),
		-- Calculate the 200-day moving average trend over the last month
		MA200Trend AS (
			SELECT
				ASXCode,
				ObservationDate,
				MA200,
				LAG(MA200, 30) OVER (PARTITION BY ASXCode ORDER BY ObservationDate) AS MA200_1MonthAgo
			FROM
				MovingAverages
		)

		-- Step 3: Implement the conditions to filter the stocks
		SELECT
			m.ASXCode,
			m.ObservationDate,
			m.[Close],
			m.MA50,
			m.MA150,
			m.MA200,
			w.Low52Weeks,
			w.High52Weeks
		into StockData.Stage2Stocks
		FROM
			MovingAverages m
		JOIN
			WeeklyStats w ON m.ASXCode = w.ASXCode AND m.ObservationDate = w.ObservationDate
		JOIN
			MA200Trend t ON m.ASXCode = t.ASXCode AND m.ObservationDate = t.ObservationDate
		WHERE
			m.[Close] > m.MA50
			AND m.[Close] > m.MA150
			AND m.[Close] > m.MA200
			AND m.MA50 > m.MA150
			AND m.MA150 > m.MA200
			AND t.MA200 > t.MA200_1MonthAgo
			AND m.[Close] > w.Low52Weeks * 1.25
			AND m.[Close] > w.High52Weeks * 0.75
			and m.ObservationDate >= '2021-01-01'
		ORDER BY
			m.ASXCode, m.ObservationDate;

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
