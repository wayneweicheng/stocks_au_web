-- Stored procedure: [Utility].[usp_CompressTableAndIndex]





create PROCEDURE [Utility].[usp_CompressTableAndIndex]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_CompressTableAndIndex.sql
Stored Procedure Name: usp_CompressTableAndIndex
Overview
-----------------
usp_CompressTableAndIndex

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
Date:		2020-11-29
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CompressTableAndIndex'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Utility'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--Creates the ALTER TABLE Statements

		SET NOCOUNT ON
		SELECT 'ALTER TABLE ' + '[' + s.[name] + ']'+'.' + '[' + o.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);'
		FROM sys.objects AS o WITH (NOLOCK)
		INNER JOIN sys.indexes AS i WITH (NOLOCK)
		ON o.[object_id] = i.[object_id]
		INNER JOIN sys.schemas AS s WITH (NOLOCK)
		ON o.[schema_id] = s.[schema_id]
		INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
		ON i.[object_id] = ps.[object_id]
		AND ps.[index_id] = i.[index_id]
		WHERE o.[type] = 'U'
		ORDER BY ps.[reserved_page_count]

		--Creates the ALTER INDEX Statements

		SET NOCOUNT ON
		SELECT s.name, o.name, 'ALTER INDEX '+ '[' + i.[name] + ']' + ' ON ' + '[' + s.[name] + ']' + '.' + '[' + o.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);'
		FROM sys.objects AS o WITH (NOLOCK)
		INNER JOIN sys.indexes AS i WITH (NOLOCK)
		ON o.[object_id] = i.[object_id]
		INNER JOIN sys.schemas s WITH (NOLOCK)
		ON o.[schema_id] = s.[schema_id]
		INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
		ON i.[object_id] = ps.[object_id]
		AND ps.[index_id] = i.[index_id]
		WHERE o.type = 'U' AND i.[index_id] >0
		and s.name = 'StockData'
		and o.name = 'PriceSummary'
		ORDER BY ps.[reserved_page_count]

		ALTER INDEX [idx_stockdatapricesummary_observationdate] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [idx_stockdata_pricesummary] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [idx_stockdatapricesummary_datetoobservationdateasxcode] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [idx_stockdatapricesummary_latestobdateasxcode] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [idx_stockdatapricesummary_datefromvolumnobdateasxcode] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [pk_stockdatapricesummary_pricesummaryid] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [idx_stockdatapricesummary_vwapasxcode] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);
		ALTER INDEX [idx_stockdatapricesummary_asxcodeobdatevolume] ON [StockData].[PriceSummary] REBUILD WITH (DATA_COMPRESSION=PAGE);


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
