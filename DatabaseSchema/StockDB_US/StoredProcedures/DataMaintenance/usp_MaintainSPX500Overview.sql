-- Stored procedure: [DataMaintenance].[usp_MaintainSPX500Overview]





CREATE PROCEDURE [DataMaintenance].[usp_MaintainSPX500Overview]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintPrevNumDay as int = 2
AS
/******************************************************************************
File: usp_MaintainSPX500Overview.sql
Stored Procedure Name: usp_MaintainSPX500Overview
Overview
-----------------
usp_MaintainSPX500Overview

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
Date:		2024-07-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MaintainSPX500Overview'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here
		--declare @pintPrevNumDay as int = 2
		-- Step 1: Create a temporary table to store the 50-day SMA for each stock
		update a
		set a.IsSPX500 = 0
		from StockData.PriceHistory as a
		where a.IsSPX500 = 1
		and a.ObservationDate > dateadd(day, -30, getdate())

		update a
		set a.IsSPX500 = 1
		from StockData.PriceHistory as a
		inner join [dbo].[Component Stocks - SPX500] as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate > dateadd(day, -30, getdate())

		update a
		set a.IsDJIA30 = 0
		from StockData.PriceHistory as a
		where a.IsDJIA30 = 1
		and a.ObservationDate > dateadd(day, -30, getdate())

		update a
		set a.IsDJIA30 = 1
		from StockData.PriceHistory as a
		inner join [dbo].[Component Stocks - DJIA30] as b
		on a.ASXCode = ltrim(rtrim(b.Symbol)) + '.US'
		and a.ObservationDate > dateadd(day, -30, getdate())

		update a
		set a.IsNASDAQ100 = 0
		from StockData.PriceHistory as a
		where a.IsNASDAQ100 = 1
		and a.ObservationDate > dateadd(day, -30, getdate())

		update a
		set a.IsNASDAQ100 = 1
		from StockData.PriceHistory as a
		inner join [dbo].[Component Stocks - NASDAQ100] as b
		on a.ASXCode = ltrim(rtrim(b.Symbol)) + '.US'
		and a.ObservationDate > dateadd(day, -30, getdate())

		if object_id(N'StockData.SPX500Overview') is not null
			drop table StockData.SPX500Overview;

		WITH SMA_Calculation AS (
			SELECT
				ASXCode,
				ObservationDate,
				[Close],
				IsSPX500,
				AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS SMA50,
				AVG([Close]) OVER (PARTITION BY ASXCode ORDER BY ObservationDate ROWS BETWEEN 199 PRECEDING AND CURRENT ROW) AS SMA200
			FROM
				StockData.PriceHistory
				where IsSPX500 = 1
		),
		-- Step 2: Determine whether each stock's [Close] price is above its 50-day SMA
		Above_SMA AS (
			SELECT
				ASXCode,
				ObservationDate,
				CASE WHEN [Close] > SMA50 THEN 1 ELSE 0 END AS IsAboveSMA50,
				CASE WHEN [Close] > SMA200 THEN 1 ELSE 0 END AS IsAboveSMA200,
				IsSPX500
			FROM
				SMA_Calculation
		)
		-- Step 3: Calculate the percentage of SPX stocks above their 50-day SMA for each observation date

		SELECT
			ObservationDate,
			CAST(SUM(IsAboveSMA50) * 100.0 / COUNT(*) AS DECIMAL(5, 2)) AS PercentageAboveSMA50,
			CAST(SUM(IsAboveSMA200) * 100.0 / COUNT(*) AS DECIMAL(5, 2)) AS PercentageAboveSMA200
		INTO
			StockData.SPX500Overview
		FROM
			Above_SMA
		WHERE
			IsSPX500 = 1
		GROUP BY
			ObservationDate
		ORDER BY
			ObservationDate;

		
	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
