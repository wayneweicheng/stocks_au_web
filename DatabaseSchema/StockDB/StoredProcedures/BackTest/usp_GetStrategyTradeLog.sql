-- Stored procedure: [BackTest].[usp_GetStrategyTradeLog]





CREATE PROCEDURE [BackTest].[usp_GetStrategyTradeLog]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchExecutionId as varchar(50),
@pvchEntryTimeMax as varchar(10) = '14:30',
@pdecCommmission as decimal(10, 2) = 20.0,
@pdtStartDate as date = null,
@pdtEndDate as date = null
AS
/******************************************************************************
File: usp_GetStrategyTradeLog.sql
Stored Procedure Name: usp_GetStrategyTradeLog
Overview
-----------------
usp_GetStrategyTradeLog

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [BackTest].[usp_GetStrategyTradeLog]
@pvchExecutionId = '410E675E-4AD1-45C3-96F0-2989C07420BE',
@pvchEntryTimeMax = '14:30',
@pdecCommmission = 20.0

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2025-04-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStrategyTradeLog'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'BackTest'
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
		declare @pdecComission as decimal(10, 2) = @pdecCommmission

		select *
		from
		(
			SELECT ExecutionId, InitialCashPosition, OrderId, EntryTime, EntryPrice, ExitTime, ExitPrice, ProfitLoss/1.0 - @pdecComission as ProfitLoss, Duration, BuyConditionCode, BuyRSI, SellConditionCode, SellRSI, ASXCode 
			from [StockDB].[BackTest].[v_BackTestTrade_Performance]
			where 1 = 1 
			and ExecutionId = @pvchExecutionId
			--and ExecutionId = '901f6412-2ddc-4b2d-93a3-37d2ee4382fb'
			--and ExecutionId = '127cfac7-c45f-48f6-aa1a-5ae416255a6d'
			and cast(EntryTime as time) <= @pvchEntryTimeMax
			and (@pdtStartDate is null or EntryTime > @pdtStartDate)
			and (@pdtEndDate is null or EntryTime < @pdtEndDate)
			--union
			--SELECT ExecutionId, InitialCashPosition, OrderId, EntryTime, EntryPrice, ExitTime, ExitPrice, ProfitLoss/1.0 - @pdecComission as ProfitLoss, Duration, BuyConditionCode, BuyRSI, SellConditionCode, SellRSI, ASXCode 
			--from [StockDB].[BackTest].[v_BackTestTrade_Performance]
			--where 1 = 1 
			--and ExecutionId = '58e8d652-5e96-4177-9168-7c1e435e2630'
			----and ExecutionId = '127cfac7-c45f-48f6-aa1a-5ae416255a6d'
			--and cast(EntryTime as time) <= '14:30'
			--and cast(EntryTime as date) >= '2021-01-01'
			--and cast(EntryTime as date) <= '2024-01-01'

		) as x
		where 1 = 1
		--and
		--(
		--	(cast(EntryTime as time) > cast('9:30' as time) and cast(EntryTime as time) < cast('10:30' as time))
		--	or
		--	(cast(EntryTime as time) > cast('12:30' as time) and cast(EntryTime as time) < cast('14:30' as time))
		--)
		order by EntryTime desc;

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