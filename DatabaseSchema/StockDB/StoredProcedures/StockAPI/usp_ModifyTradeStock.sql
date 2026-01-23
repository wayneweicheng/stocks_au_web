-- Stored procedure: [StockAPI].[usp_ModifyTradeStock]

CREATE PROCEDURE [StockAPI].[usp_ModifyTradeStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchBuySellFlag as varchar(1),
@pvchTradeTypeID varchar(10),
@pdecPrice as decimal(20, 4),
@pdecStopLossPrice as decimal(20, 4) = null,
@pdecStopProfitPrice as decimal(20, 4) = null,
@pintVolume as int,
@pvchOrderReceiptID as varchar(50) = null,
@pvchTradeAccountName as varchar(100),
@pintLinkedTradeStockId as int = null,
@pintOrderId as int = 0,
@pvchSourceOrderId varchar(100) = null
AS
/******************************************************************************
File: usp_ModifyTradeStock.sql
Stored Procedure Name: usp_ModifyTradeStock
Overview
-----------------
usp_ModifyTradeStock

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
Date:		2021-04-11
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_ModifyTradeStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
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
			where TradingPlatform = 'IB'
			and TradeAccountName = @pvchTradeAccountName
		)
		begin
			raiserror('TradeAccountName supplied not valid', 16, 0)
		end

		if @pvchBuySellFlag not in ('B', 'S')
		begin
			raiserror('BuySellFlag supplied not valid', 16, 0)
		end

		declare @intTradeStockId as int

		if exists
		(
			select 1
			from [StockAPI].[TradeStock]
			where TradeTypeID = @pvchTradeTypeID
			and ASXCode = @pvchASXCode
			and BuySellFlag = @pvchBuySellFlag
			and TradeStatus not in ('FF')
		)
		begin
			select @intTradeStockId = TradeStockId
			from [StockAPI].[TradeStock]
			where TradeTypeID = @pvchTradeTypeID
			and ASXCode = @pvchASXCode
			and BuySellFlag = @pvchBuySellFlag
			and TradeStatus not in ('FF')
			order by TradeStockId desc
		end
		else
		begin
			raiserror('Order to modify cannot be found', 16, 0)
		end

		update a
		set 
			[Price] = @pdecPrice,
			[StopLossPrice] = @pdecStopLossPrice,
			StopProfitPrice = @pdecStopProfitPrice,
			[OrderPlaceDate] = getdate(),
			[OrderPlaceVolume] = @pintVolume,
			[OrderReceiptID] = @pvchOrderReceiptID,
			[LastUpdateDate] = getdate()
		from [StockAPI].[TradeStock] as a
		where TradeStockId = @intTradeStockId

		if @pintOrderId > 0
		begin
			update a
			set OrderTriggerDate = getdate(),
				OrderPlaceDate = getdate(),
				ActualOrderPrice = @pdecPrice
			from [Order].[Order] as a
			where OrderID = @pintOrderId
		end
		

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