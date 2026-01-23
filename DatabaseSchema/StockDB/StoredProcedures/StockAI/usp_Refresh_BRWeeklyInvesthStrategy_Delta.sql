-- Stored procedure: [StockAI].[usp_Refresh_BRWeeklyInvesthStrategy_Delta]


CREATE PROCEDURE [StockAI].[usp_refresh_BRWeeklyInvesthStrategy_Delta]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_refresh_BRWeeklyInvesthStrategy_Delta.sql
Stored Procedure Name: usp_refresh_BRWeeklyInvesthStrategy_Delta
Overview
-----------------
usp_refresh_BRWeeklyInvesthStrategy_Delta

Input Parameters
----------------
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
Date:		2018-08-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_refresh_BRWeeklyInvesthStrategy_Delta'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAI'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pintLookupNumDay as int = 5
		--declare @pvchBrokerCode as varchar(20) = 'pershn'
		--Code goes here 	

		declare @dtMaxObDate as date
		select @dtMaxObDate = max(ObservationDate)
		from StockData.BrokerTradeTransaction
		DECLARE @pdtCurrentStartDate AS DATE = [Common].[DateAddBusinessDay_Plus](-7, @dtMaxObDate)
		DECLARE @pdtFinalStartDate AS DATE = @dtMaxObDate

		if object_id(N'Tempdb.dbo.#TempPriceHistoryFiltered') is not null
			drop table #TempPriceHistoryFiltered

		SELECT *
		INTO #TempPriceHistoryFiltered
		FROM Transform.PriceHistory24Month
		WHERE ObservationDate >= @pdtCurrentStartDate

		WHILE @pdtCurrentStartDate <= @pdtFinalStartDate
		BEGIN
			DECLARE @pdtStartDate AS DATE = @pdtCurrentStartDate
			DECLARE @pdtEndDate AS DATE = [Common].[DateAddBusinessDay_Plus](6, @pdtStartDate) -- 6 business days from start
			DECLARE @pdtObservationDate AS DATE = [Common].[DateAddBusinessDay_Plus](3, @pdtEndDate)
    
			PRINT 'Processing period: ' + CAST(@pdtStartDate AS VARCHAR(10)) + ' to ' + CAST(@pdtEndDate AS VARCHAR(10)) + ', Observation: ' + CAST(@pdtObservationDate AS VARCHAR(10))
    
			-- Drop temp tables if they exist
			IF OBJECT_ID(N'Tempdb.dbo.#TempPriceHistory') IS NOT NULL
				DROP TABLE #TempPriceHistory

			-- Create price history temp table
			SELECT *
			INTO #TempPriceHistory
			FROM #TempPriceHistoryFiltered
			WHERE ObservationDate = @pdtObservationDate

			IF OBJECT_ID(N'Tempdb.dbo.#TempNetBuyRank') IS NOT NULL
				DROP TABLE #TempNetBuyRank

			-- Create net buy rank analysis
			SELECT
				x.ASXCode,
				x.Buyer,
				x.BuyVolume,
				y.SellVolume,
				x.BuyVolume - y.SellVolume AS NetVolume,
				x.BuyValue,
				y.SellValue,
				x.BuyValue - y.SellValue AS NetValue,
				x.BuyValue * 1.0 / x.BuyVolume AS BuyVWAP,
				y.SellValue * 1.0 / y.SellVolume AS SellVWAP,
				z.BuyVolume AS SelfTradeVolume,
				z.BuyVolume * 1.0 / y.SellVolume AS SelfTradePerc,
				ROW_NUMBER() OVER (PARTITION BY x.ASXCode ORDER BY x.BuyVolume - y.SellVolume DESC) AS RowNumber
			INTO #TempNetBuyRank
			FROM
			(
				SELECT
					ASXCode,
					Buyer,
					SUM(Volume) AS BuyVolume,
					SUM([Value]) AS BuyValue
				FROM StockData.BrokerTradeTransaction
				WHERE ObservationDate >= @pdtStartDate
					AND ObservationDate <= @pdtEndDate
					AND ASXCode IS NOT NULL
				GROUP BY ASXCode, Buyer
			) AS x
			LEFT JOIN
			(
				SELECT
					ASXCode,
					Seller,
					SUM(Volume) AS SellVolume,
					SUM([Value]) AS SellValue
				FROM StockData.BrokerTradeTransaction
				WHERE ObservationDate >= @pdtStartDate
					AND ObservationDate <= @pdtEndDate
					AND ASXCode IS NOT NULL
				GROUP BY ASXCode, Seller
			) AS y
				ON x.Buyer = y.Seller
				AND x.ASXCode = y.ASXCode
			LEFT JOIN
			(
				SELECT
					ASXCode,
					Buyer,
					SUM(Volume) AS BuyVolume,
					SUM([Value]) AS BuyValue
				FROM StockData.BrokerTradeTransaction
				WHERE ObservationDate >= @pdtStartDate
					AND ObservationDate <= @pdtEndDate
					AND ASXCode IS NOT NULL
					AND Buyer = Seller
				GROUP BY ASXCode, Buyer
			) AS z
				ON x.Buyer = z.Buyer
				AND x.ASXCode = z.ASXCode
			ORDER BY x.BuyVolume - y.SellVolume DESC;

			-- Insert results into target table
			delete a 
			from StockDB.StockAI.BRWeeklyInvesthStrategy as a
			where StartDate = @pdtStartDate
			and EndDate = @pdtEndDate

			INSERT INTO StockDB.[StockAI].[BRWeeklyInvesthStrategy]
			(
				[ASXCode],
				[StartDate],
				[EndDate],
				[Buyer],
				[BuyVolume],
				[SellVolume],
				[NetVolume],
				[BuyValue],
				[SellValue],
				[NetValue],
				[BuyVWAP],
				[SellVWAP],
				[SelfTradeVolume],
				[SelfTradePerc],
				[RowNumber],
				[TodayChange],
				[TomorrowChange],
				[Next2DaysChange],
				[Next5DaysChange],
				[Next10DaysChange],
				[Prev2DaysChange],
				[Prev10DaysChange]
			)
			SELECT 
				a.[ASXCode],
				@pdtStartDate AS [StartDate],
				@pdtEndDate AS [EndDate],
				[Buyer],
				[BuyVolume],
				[SellVolume],
				[NetVolume],
				[BuyValue],
				[SellValue],
				[NetValue],
				[BuyVWAP],
				[SellVWAP],
				[SelfTradeVolume],
				[SelfTradePerc],
				[RowNumber],
				[TodayChange],
				[TomorrowChange],
				[Next2DaysChange],
				[Next5DaysChange],
				[Next10DaysChange],
				[Prev2DaysChange],
				[Prev10DaysChange]
			FROM #TempNetBuyRank AS a
			LEFT JOIN #TempPriceHistory AS b
				ON a.ASXCode = b.ASXCode
			WHERE RowNumber >= 1
				AND RowNumber <= 2

			-- Clean up temp tables
			DROP TABLE #TempPriceHistory
			DROP TABLE #TempNetBuyRank
    
			-- Increment start date by 3 business days for next iteration
			SET @pdtCurrentStartDate = [Common].[DateAddBusinessDay_Plus](1, @pdtCurrentStartDate)
			print '@pdtCurrentStartDate: ' + cast(@pdtCurrentStartDate as varchar(100))
			print '@pdtFinalStartDate: ' + cast(@pdtFinalStartDate as varchar(100))
		END

		delete a
		from StockAI.BRWeeklyInvesthStrategy as a
		where EndDate > (
			select max(ObservationDate) as ObservationDate
			from StockData.BrokerTradeTransaction
		)		

		DROP TABLE IF EXISTS StockDB.StockAI.BRWeeklyInvesthStrategy_Delta;

		WITH Base AS (
			SELECT DISTINCT
				Buyer,
				ASXCode,
				StartDate,
				EndDate,
				RowNumber,
				NetVolume,
				NetValue
			FROM StockDB.StockAI.BRWeeklyInvesthStrategy
			WHERE RowNumber IN (1, 2)  -- treat rank 1-2 as "top net buyer"
		),
		Periods AS (
			SELECT DISTINCT StartDate, EndDate
			FROM Base
		),
		BuyerPeriodCurrent AS (
			SELECT DISTINCT b.Buyer, b.StartDate, b.EndDate
			FROM Base b
		),
		BuyerPeriodFromPrev AS (
			SELECT DISTINCT
				b.Buyer,
				[Common].[DateAddBusinessDay_Plus](1, b.StartDate) AS StartDate,
				[Common].[DateAddBusinessDay_Plus](1, b.EndDate)   AS EndDate
			FROM Base b
		),
		BuyerPeriod AS (
			SELECT DISTINCT c.Buyer, c.StartDate, c.EndDate
			FROM BuyerPeriodCurrent c
			UNION
			SELECT DISTINCT x.Buyer, x.StartDate, x.EndDate
			FROM BuyerPeriodFromPrev x
			JOIN Periods p
			  ON p.StartDate = x.StartDate
			 AND p.EndDate   = x.EndDate
		),
		CurrentTop AS (
			SELECT
				bp.Buyer, bp.StartDate, bp.EndDate,
				t.ASXCode, t.RowNumber, t.NetVolume, t.NetValue
			FROM BuyerPeriod bp
			LEFT JOIN Base t
			  ON t.Buyer     = bp.Buyer
			 AND t.StartDate = bp.StartDate
			 AND t.EndDate   = bp.EndDate
		),
		PrevTop AS (
			SELECT
				bp.Buyer, bp.StartDate, bp.EndDate,
				p.ASXCode, p.RowNumber, p.NetVolume, p.NetValue
			FROM BuyerPeriod bp
			LEFT JOIN Base p
			  ON p.Buyer     = bp.Buyer
			 AND p.StartDate = [Common].[DateAddBusinessDay_Plus](-1, bp.StartDate)
			 AND p.EndDate   = [Common].[DateAddBusinessDay_Plus](-1, bp.EndDate)
		),
		Added AS (
			SELECT
				c.Buyer,
				c.StartDate, c.EndDate,
				[Common].[DateAddBusinessDay_Plus](-1, c.StartDate) AS PrevStartDate,
				[Common].[DateAddBusinessDay_Plus](-1, c.EndDate)   AS PrevEndDate,
				N'Added' AS ChangeType,
				c.ASXCode,
				c.RowNumber AS CurrentRank,
				CAST(NULL AS int) AS PrevRank,
				c.NetVolume AS CurrentNetVolume,
				CAST(NULL AS bigint) AS PrevNetVolume,
				c.NetValue AS CurrentNetValue,
				CAST(NULL AS bigint) AS PrevNetValue
			FROM CurrentTop c
			LEFT JOIN PrevTop p
			  ON p.Buyer     = c.Buyer
			 AND p.StartDate = c.StartDate
			 AND p.EndDate   = c.EndDate
			 AND p.ASXCode   = c.ASXCode
			WHERE c.ASXCode IS NOT NULL
			  AND p.ASXCode IS NULL
		),
		Removed AS (
			SELECT
				p.Buyer,
				p.StartDate, p.EndDate,
				[Common].[DateAddBusinessDay_Plus](-1, p.StartDate) AS PrevStartDate,
				[Common].[DateAddBusinessDay_Plus](-1, p.EndDate)   AS PrevEndDate,
				N'Removed' AS ChangeType,
				p.ASXCode,
				CAST(NULL AS int) AS CurrentRank,
				p.RowNumber AS PrevRank,
				CAST(NULL AS bigint) AS CurrentNetVolume,
				p.NetVolume AS PrevNetVolume,
				CAST(NULL AS bigint) AS CurrentNetValue,
				p.NetValue AS PrevNetValue
			FROM PrevTop p
			LEFT JOIN CurrentTop c
			  ON c.Buyer     = p.Buyer
			 AND c.StartDate = p.StartDate
			 AND c.EndDate   = p.EndDate
			 AND c.ASXCode   = p.ASXCode
			WHERE p.ASXCode IS NOT NULL
			  AND c.ASXCode IS NULL
		)
		SELECT
			Buyer,
			StartDate, EndDate,
			PrevStartDate, PrevEndDate,
			ChangeType,
			ASXCode,
			CurrentRank, PrevRank,
			CurrentNetVolume, PrevNetVolume,
			CurrentNetValue, PrevNetValue
		INTO StockDB.StockAI.BRWeeklyInvesthStrategy_Delta
		FROM Added
		UNION ALL
		SELECT
			Buyer,
			StartDate, EndDate,
			PrevStartDate, PrevEndDate,
			ChangeType,
			ASXCode,
			CurrentRank, PrevRank,
			CurrentNetVolume, PrevNetVolume,
			CurrentNetValue, PrevNetValue
		FROM Removed;

		
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