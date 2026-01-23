-- Stored procedure: [AutoTrade].[usp_AddTradeRequest]

CREATE PROCEDURE [AutoTrade].[usp_AddTradeRequest]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchBuySellFlag as varchar(1),
@pdecTradePrice as decimal(20, 4),
@pdecStopLossPrice as decimal(20, 4) = null,
@pdecStopProfitPrice as decimal(20, 4) = null,
@pintVolume as int,
@pvchTradeAccountName as varchar(100)
AS
/******************************************************************************
File: usp_AddTradeRequest.sql
Stored Procedure Name: usp_AddTradeRequest
Overview
-----------------
usp_AddTradeRequest

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
Date:		2020-10-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddTradeRequest'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'AutoTrade'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if not exists
		(
			select 1
			from LookupRef.TradingAccount
			where TradingPlatform = 'CMC'
			and TradeAccountName = @pvchTradeAccountName
		)
		begin
			raiserror('TradeAccountName supplied not valid', 16, 0)
		end

		if @pvchBuySellFlag not in ('B', 'S')
		begin
			raiserror('BuySellFlag supplied not valid', 16, 0)
		end

		insert into [AutoTrade].[TradeRequest]
		(
			[ASXCode]
			,[BuySellFlag]
			,[Price]
			,[StopLossPrice]
			,[StopProfitPrice]
			,[MinVolume]
			,[MaxVolume]
			,[RequestValidTimeFrameInMin]
			,[RequestValidUntil]
			,[CreateDate]
			,[LastTryDate]
			,[OrderPlaceDate]
			,[OrderPlaceVolume]
			,[OrderReceiptID]
			,[OrderFillDate]
			,[OrderFillVolume]
			,[RequestStatus]
			,[RequestStatusMessage]
			,[PreReqTradeRequestID]
			,[AccountNumber]
			,[TradeStrategyID]
			,[ErrorCount]
			,TradeStrategyMessage
			,TradeRank
			,IsNotificationSent
			,TradeAccountName
		)
		select
			 @pvchASXCode as [ASXCode]
			,@pvchBuySellFlag as [BuySellFlag]
			,@pdecTradePrice as [Price]
			,@pdecStopLossPrice as [StopLossPrice]
			,@pdecStopProfitPrice as [StopProfitPrice]
			,@pintVolume as [MinVolume]
			,@pintVolume as [MaxVolume]
			,60 as [RequestValidTimeFrameInMin]
			,dateadd(minute, 60, getdate()) as [RequestValidUntil]
			,getdate() as [CreateDate]
			,null as [LastTryDate]
			,null as [OrderPlaceDate]
			,null as [OrderPlaceVolume]
			,null as [OrderReceiptID]
			,null as [OrderFillDate]
			,null as [OrderFillVolume]
			,'R' as [RequestStatus]
			,null as [RequestStatusMessage]
			,null as [PreReqTradeRequestID]
			,(select AccountNumber from LookupRef.TradingAccount where TradeAccountName = @pvchTradeAccountName and TradingPlatform = 'CMC') as [AccountNumber]
			,101 as [TradeStrategyID]
			,0 as [ErrorCount]
			,(select TradeStrategyName from LookupRef.TradeStrategy where TradeStrategyID = 101) as TradeStrategyMessage
			,15 as TradeRank
			,null as IsNotificationSent
			,@pvchTradeAccountName as TradeAccountName
	
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