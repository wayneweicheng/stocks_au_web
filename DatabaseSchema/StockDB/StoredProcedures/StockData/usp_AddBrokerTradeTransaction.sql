-- Stored procedure: [StockData].[usp_AddBrokerTradeTransaction]


CREATE PROCEDURE [StockData].[usp_AddBrokerTradeTransaction]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchBrokerTradeTransaction as varchar(max),
@pdtObservationDate as date,
@pvchASXCode as varchar(10)
AS
/******************************************************************************
File: usp_AddBrokerTradeTransaction.sql
Stored Procedure Name: usp_AddBrokerTradeTransaction
Overview
-----------------
usp_AddBrokerTradeTransaction - Processes broker trade transaction data

Input Parameters
-----------------
@pbitDebug                      -- Set to 1 to force the display of debugging information
@pvchBrokerTradeTransaction     -- XML string containing broker trade transaction data
@pdtObservationDate             -- Date of the trading session
@pvchASXCode                    -- ASX stock code

Output Parameters
-----------------
@pintErrorNumber                -- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
DECLARE @ErrorNum INT = 0
EXEC [StockData].[usp_AddBrokerTradeTransaction] 
    @pbitDebug = 1,
    @pintErrorNumber = @ErrorNum OUTPUT,
    @pvchBrokerTradeTransaction = '<BrokerTradeTransaction>...</BrokerTradeTransaction>',
    @pdtObservationDate = '2025-07-22',
    @pvchASXCode = 'ABC'

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2025-07-26
Author:		WAYNE CHENG
Description: Initial Version - Based on usp_AddPriceHistory template
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddBrokerTradeTransaction'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal variable declarations
		DECLARE @xmlBrokerTradeTransaction AS XML

		--Code goes here 
		--begin transaction
		
		-- Insert raw data for audit trail
		INSERT INTO StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate
		)
		SELECT
			31 AS DataTypeID,  -- Assuming 31 is the DataTypeID for broker trade transactions
			@pvchBrokerTradeTransaction AS RawData,
			GETDATE() AS CreateDate,
			@pdtObservationDate AS SourceSystemDate
		
		-- Convert input to XML for parsing
		SELECT @xmlBrokerTradeTransaction = CAST(@pvchBrokerTradeTransaction AS XML)

		-- Create temporary table for parsed data
		IF OBJECT_ID(N'Tempdb.dbo.#TempBrokerTradeTransaction') IS NOT NULL
			DROP TABLE #TempBrokerTradeTransaction

		SELECT 
			x.trade.value('transactionDateTime[1]', 'varchar(100)') AS [TransactionDateTime],
			x.trade.value('buyer[1]', 'varchar(100)') AS [Buyer],
			x.trade.value('seller[1]', 'varchar(100)') AS [Seller],
			x.trade.value('price[1]', 'varchar(100)') AS [Price],
			x.trade.value('volume[1]', 'varchar(100)') AS [Volume],
			x.trade.value('value[1]', 'varchar(100)') AS [Value],
			x.trade.value('condition[1]', 'varchar(100)') AS [Condition],
			x.trade.value('market[1]', 'varchar(100)') AS [Market]
		INTO #TempBrokerTradeTransaction
		FROM @xmlBrokerTradeTransaction.nodes('/BrokerTradeTransaction/trade') AS x(trade)

		-- Insert parsed data into main table
		set dateformat dmy

		INSERT INTO StockData.BrokerTradeTransaction
		(
			ObservationDate,
			ASXCode,
			TransactionDateTime,
			Buyer,
			Seller,
			Price,
			Volume,
			Value,
			Condition,
			Market,
			CreateDate
		)
		SELECT
			@pdtObservationDate AS ObservationDate,
			@pvchASXCode AS ASXCode,
			CASE 
				WHEN ISDATE([TransactionDateTime]) = 1 
				THEN CAST([TransactionDateTime] AS DATETIME2(3))
				ELSE CAST(@pdtObservationDate AS DATETIME2(3))
			END AS TransactionDateTime,
			[Buyer],
			[Seller],
			CASE 
				WHEN ISNUMERIC(REPLACE([Price], '$', '')) = 1 
				THEN CAST(REPLACE([Price], '$', '') AS DECIMAL(10,4))
				ELSE 0.0000
			END AS Price,
			CASE 
				WHEN ISNUMERIC(REPLACE(REPLACE([Volume], ',', ''), ' ', '')) = 1 
				THEN CAST(REPLACE(REPLACE([Volume], ',', ''), ' ', '') AS BIGINT)
				ELSE 0
			END AS Volume,
			CASE 
				WHEN ISNUMERIC(REPLACE(REPLACE(REPLACE([Value], '$', ''), ',', ''), ' ', '')) = 1 
				THEN CAST(REPLACE(REPLACE(REPLACE([Value], '$', ''), ',', ''), ' ', '') AS DECIMAL(15,2))
				ELSE 0.00
			END AS Value,
			NULLIF(LTRIM(RTRIM([Condition])), '') AS Condition,
			[Market],
			GETDATE() AS CreateDate
		FROM #TempBrokerTradeTransaction AS a
		WHERE NOT EXISTS
		(
			SELECT 1
			FROM StockData.BrokerTradeTransaction
			WHERE ObservationDate = @pdtObservationDate
			AND ASXCode = @pvchASXCode
			AND Buyer = a.Buyer
			AND Seller = a.Seller
			AND ABS(Price - CASE 
				WHEN ISNUMERIC(REPLACE(a.[Price], '$', '')) = 1 
				THEN CAST(REPLACE(a.[Price], '$', '') AS DECIMAL(10,4))
				ELSE 0.0000
			END) < 0.0001  -- Price comparison with small tolerance
			AND Volume = CASE 
				WHEN ISNUMERIC(REPLACE(REPLACE(a.[Volume], ',', ''), ' ', '')) = 1 
				THEN CAST(REPLACE(REPLACE(a.[Volume], ',', ''), ' ', '') AS BIGINT)
				ELSE 0
			END
		)

		-- Clean up temporary table
		IF OBJECT_ID(N'Tempdb.dbo.#TempBrokerTradeTransaction') IS NOT NULL
			DROP TABLE #TempBrokerTradeTransaction
		
	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occurred in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(GETDATE() AS VARCHAR(20))
			PRINT 'Processed broker trade transactions for ASX Code: ' + @pvchASXCode + ' on ' + CAST(@pdtObservationDate AS VARCHAR(20))
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
