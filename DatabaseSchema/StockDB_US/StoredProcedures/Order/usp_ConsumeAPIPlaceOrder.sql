-- Stored procedure: [Order].[usp_ConsumeAPIPlaceOrder]

CREATE PROCEDURE [Order].[usp_ConsumeAPIPlaceOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode varchar(10),
@intTradeRequestID int = -1,
@vchTradeAccountName varchar(50),
@pvchOutputMessage varchar(max) output,
@pvchErrorMessage varchar(max) = null output 
AS
/******************************************************************************
File: usp_ConsumeAPIPlaceOrder.sql
Stored Procedure Name: usp_ConsumeAPIPlaceOrder
Overview
-----------------
usp_ConsumeAPIPlaceOrder

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------

exec [AutoTrade].[usp_AddTradeRequest]
@pvchASXCode = 'DSE.AX',
@pvchBuySellFlag = 'S',
@pdecTradePrice = 0.12,
@pdecStopLossPrice = null,
@pdecStopProfitPrice = null,
@pintVolume = 68741,
@pvchTradeAccountName = 'huanwang'

declare @pvchOutputMessage as varchar(200)

exec [Order].[usp_ConsumeAPIPlaceOrder]
@pvchStockCode = 'DSE.AX',
@pvchOutputMessage = @pvchOutputMessage output

select @pvchOutputMessage

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2019-12-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_ConsumeAPIPlaceOrder'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Order'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--declare @pvchStockCode as varchar(10) = 'SPZ.AX'

		declare @postMessage as varchar(max) = '{
			"StockCode": "' + @pvchStockCode + '",
			"TradeRequestID": "' + cast(@intTradeRequestID as varchar(50)) + '",
			"AccountName": "' + @vchTradeAccountName + '"
		}'

		exec DA_Utility.[dbo].[StockAPIPost]
		@urlToSendTo = 'http://192.168.20.102:56088/api/PlaceOrder/', 
		@appHeader = 'json', 
		@xInsertKey = 'StockAPI', 
		@dataToSend = @postMessage, 
		@responseFromWeb = @pvchOutputMessage output,
		@error = @pvchErrorMessage output 

		--exec DA_Utility.[dbo].[StockAPIPost]
		--@urlToSendTo = 'http://192.168.20.102:56088/api/Stock/', 
		--@appHeader = 'json', 
		--@xInsertKey = 'StockAPI', 
		--@dataToSend = @postMessage, 
		--@responseFromWeb = @outputMessage output,
		--@error = @errorMessage output 

		
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
