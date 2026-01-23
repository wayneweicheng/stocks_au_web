-- Stored procedure: [DataMaintenance].[usp_MaintainStockMergeandSplit]





CREATE PROCEDURE [DataMaintenance].[usp_MaintainStockMergeandSplit]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintPrevNumDay as int = 2
AS
/******************************************************************************
File: usp_MaintainStockMergeandSplit.sql
Stored Procedure Name: usp_MaintainStockMergeandSplit
Overview
-----------------
usp_MaintainStockMergeandSplit

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MaintainStockMergeandSplit'
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
		if object_id(N'Tempdb.dbo.#TempSplitandMergeStock') is not null
			drop table #TempSplitandMergeStock

		select a.ASXCode 
		into #TempSplitandMergeStock
		from [StockData].[StockStatsHistoryPlus] as a
		inner hash join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeqReverse + 1 = b.DateSeqReverse
		and 
		(
			cast((a.[Close] - b.[Close])*100.0/b.[Close] as decimal(8, 2)) >= 300
			or
			cast((b.[Close] - a.[Close])*100.0/a.[Close] as decimal(8, 2)) >= 300
		)
		and a.DateSeqReverse < 255
		and a.DateSeqReverse < 256
		and b.[Close] > 0
		and a.[Close] > 0
		
		delete a
		from StockData.[StockStatsHistoryPlus] as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)

		delete a
		from StockData.StockStatsHistoryPlusCurrent as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)

		delete a
		from StockData.[StockStatsHistoryPlusWeekly] as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)

		delete a
		from StockData.StockStatsHistoryPlusMonthly as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)

		delete a
		from StockData.[StockStatsHistoryPlusWeekly] as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)

		delete a
		from StockData.StockStatsHistoryPlusMonthly as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)

		delete a
		from Transform.PriceHistory as a
		where ASXCode in (
			select a.ASXCode 
			from #TempSplitandMergeStock
		)


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
