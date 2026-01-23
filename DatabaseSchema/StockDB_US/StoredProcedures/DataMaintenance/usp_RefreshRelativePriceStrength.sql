-- Stored procedure: [DataMaintenance].[usp_RefreshRelativePriceStrength]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshRelativePriceStrength]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshRelativePriceStrength.sql
Stored Procedure Name: usp_RefreshRelativePriceStrength
Overview
-----------------
usp_RefreshRelativePriceStrength

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
Date:		2017-06-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshRelativePriceStrength'
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
		--Updates the RelativePriceStrength
		IF OBJECT_ID(N'Tempdb.dbo.#TempPriceHistory') IS NOT NULL
			DROP TABLE #TempPriceHistory;

		-- Create a temporary table with necessary fields and calculated DateSeqReverse
		SELECT 
			*,
			ROW_NUMBER() OVER (PARTITION BY ASXCode ORDER BY ObservationDate DESC) AS DateSeqReverse
		INTO #TempPriceHistory
		FROM StockData.PriceHistory
		WHERE ObservationDate > DATEADD(YEAR, -5, GETDATE())

		IF OBJECT_ID(N'Tempdb.dbo.#TempPriceChange') IS NOT NULL
			DROP TABLE #TempPriceChange;

		-- Calculate the 12-month price change
		SELECT 
			a.ASXCode,
			a.ObservationDate,
			a.[Close],
			CAST((a.[Close] - b.[Close]) * 100.0 / b.[Close] AS DECIMAL(20, 2)) AS PriceChange,
			b.ObservationDate as PrevWindowObservationDate,
			b.[Close] as PrevWindowClose
		INTO #TempPriceChange
		FROM #TempPriceHistory AS a
		INNER JOIN #TempPriceHistory AS b
			ON a.ASXCode = b.ASXCode
			AND a.DateSeqReverse + 125 = b.DateSeqReverse
		WHERE b.[Close] > 0;

		-- Calculate mean and standard deviation of PriceChange for each ObservationDate
		IF OBJECT_ID(N'Tempdb.dbo.#Stats') IS NOT NULL
			DROP TABLE #Stats;

		SELECT 
			ObservationDate,
			AVG(PriceChange) AS MeanChange,
			STDEV(PriceChange) AS StdDevChange
		INTO #Stats
		FROM #TempPriceChange
		GROUP BY ObservationDate;

		-- Calculate Z-Score for PriceChange
		IF OBJECT_ID(N'Tempdb.dbo.#ZScores') IS NOT NULL
			DROP TABLE #ZScores;

		SELECT 
			a.ASXCode,
			a.ObservationDate,
			a.PriceChange,
			(a.PriceChange - b.MeanChange) / b.StdDevChange AS ZScore
		INTO #ZScores
		FROM #TempPriceChange a
		INNER JOIN #Stats b
			ON a.ObservationDate = b.ObservationDate;

		---- Delete extreme outliers
		--DELETE FROM #ZScores
		--WHERE ZScore > 3 OR ZScore < -3;

		-- Truncate the target table before inserting new data
		TRUNCATE TABLE StockData.RelativePriceStrength;

		-- Insert calculated relative price strength
		INSERT INTO StockData.RelativePriceStrength
		(
			[ASXCode],
			[ObservationDate],
			[PriceChange],
			[PriceChangeRank],
			[RelativePriceStrength],
			[DateSeq]
		)
		SELECT 
			a.ASXCode,
			a.ObservationDate,
			a.PriceChange,
			a.PriceChangeRank,
			(1 - a.PriceChangeRank * 1.0 / b.NumObservations) * 100.0 AS RelativePriceStrength,
			CAST(NULL AS INT) AS DateSeq
		--into StockData.RelativePriceStrength
		FROM
		(
			SELECT 
				ASXCode,
				ObservationDate,
				PriceChange,
				ZScore,
				RANK() OVER (PARTITION BY ObservationDate ORDER BY PriceChange DESC) AS PriceChangeRank
			FROM #ZScores
		) AS a
		INNER JOIN
		(
			SELECT ObservationDate, COUNT(*) AS NumObservations
			FROM #ZScores
			GROUP BY ObservationDate
		) AS b
		ON a.ObservationDate = b.ObservationDate;

		-- Update DateSeq in the target table
		UPDATE a
		SET a.DateSeq = b.RowNumber
		FROM StockData.RelativePriceStrength AS a
		INNER JOIN 
		(
			SELECT *, ROW_NUMBER() OVER (PARTITION BY ASXCode ORDER BY ObservationDate DESC) AS RowNumber
			FROM StockData.RelativePriceStrength
		) AS b
		ON a.ASXCode = b.ASXCode
		AND a.ObservationDate = b.ObservationDate;

		-- Optionally drop the temporary tables
		DROP TABLE #TempPriceHistory;
		DROP TABLE #TempPriceChange;
		DROP TABLE #Stats;
		DROP TABLE #ZScores;

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
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
