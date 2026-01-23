-- Stored procedure: [BackTest].[usp_AddStrategyExecution]





CREATE PROCEDURE [BackTest].[usp_AddStrategyExecution]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintExecutionID int,
@pvchASXCode varchar(10),
@pvchObservationDate date,
@pdecEntryPrice decimal(20, 4),
@pdecActualBuyPrice decimal(20, 4),
@pdtmActualBuyDateTime datetime,
@pdecExitPrice decimal(20, 4),
@pdecStopLossPrice decimal(20, 4),
@pdecActualSellPrice decimal(20, 4),
@pdtmActualSellDateTime datetime,
@pdecObservationDayPriceIncreasePerc decimal(5, 2),
@pintExitRuleID int = -1,
@pintStrategyExecutionID int output
AS
/******************************************************************************
File: usp_AddStrategyExecution.sql
Stored Procedure Name: usp_AddStrategyExecution
Overview
-----------------
usp_AddStrategyExecution

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
Date:		2016-06-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddStrategyExecution'
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
		declare @decBrokerageFee as decimal(20, 4)
		declare @decTransactionValue as decimal(20, 4)
		declare @intVolume as int
		declare @decSellTotalValue as decimal(20, 4)

		select 
			@decBrokerageFee = a.BrokerageFee,
			@decTransactionValue = a.TransactionValue
		from BackTest.ExecutionSetting as a
		inner join BackTest.Execution as b
		on a.ExecutionSettingID = b.ExecutionSettingID
		and b.ExecutionID = @pintExecutionID

		select @intVolume = floor(@decTransactionValue*1.0/@pdecActualBuyPrice)
		select @decSellTotalValue = @pdecActualSellPrice*@intVolume

		select @decTransactionValue = @pdecActualBuyPrice*@intVolume

		insert into [BackTest].[StrategyExecution]
		(
		   [ExecutionID]
		  ,[ASXCode]
		  ,[ObservationDate]
		  ,[EntryPrice]
		  ,[ActualBuyPrice]
		  ,[ActualBuyDateTime]
		  ,[ExitPrice]
		  ,[StopLossPrice]
		  ,[ActualSellPrice]
		  ,[ActualSellDateTime]
		  ,[Volume]
		  ,[BuyTotalValue]
		  ,[SellTotalValue]
		  ,[BrokerageFee]
		  ,[ActualHoldDays]
		  ,[ProfitLost]
		  ,ObservationDayPriceIncreasePerc
		  ,ExitRuleID
		  ,[CreateDate]
		)
		select
		   @pintExecutionID as [ExecutionID]
		  ,@pvchASXCode as [ASXCode]
		  ,@pvchObservationDate as [ObservationDate]
		  ,@pdecEntryPrice as [EntryPrice]
		  ,@pdecActualBuyPrice as [ActualBuyPrice]
		  ,@pdtmActualBuyDateTime as [ActualBuyDateTime]
		  ,@pdecExitPrice as [ExitPrice]
		  ,@pdecStopLossPrice as [StopLossPrice]
		  ,@pdecActualSellPrice as [ActualSellPrice]
		  ,@pdtmActualSellDateTime as [ActualSellDateTime]
		  ,@intVolume as [Volume]
		  ,@decTransactionValue as [BuyTotalValue]
		  ,@decSellTotalValue as [SellTotalValue]
		  ,@decBrokerageFee as [BrokerageFee]
		  ,datediff(day, @pdtmActualBuyDateTime, @pdtmActualSellDateTime) as [ActualHoldDays]
		  ,@decSellTotalValue - @decTransactionValue - @decBrokerageFee*2 as [ProfitLost]
		  ,@pdecObservationDayPriceIncreasePerc as ObservationDayPriceIncreasePerc
		  ,@pintExitRuleID as ExitRuleID
		  ,getdate() as [CreateDate]

		select @pintStrategyExecutionID = @@IDENTITY

		if @pintStrategyExecutionID is null
			select @pintStrategyExecutionID = 0

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
