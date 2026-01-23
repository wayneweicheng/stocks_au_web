-- Stored procedure: [StockAPI].[usp_UpdateTradeStockStatus]

CREATE PROCEDURE [StockAPI].[usp_UpdateTradeStockStatus]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTradeAccountName as varchar(100),
@pvchASXCode as varchar(10),
@pvchBuySellFlag as varchar(1),
@pvchTradeTypeID varchar(10),
@pvchSourceOrderId as varchar(100),
@pvchOrderStatus varchar(100)
AS
/******************************************************************************
File: usp_UpdateTradeStockStatus.sql
Stored Procedure Name: usp_UpdateTradeStockStatus
Overview
-----------------
usp_UpdateTradeStockStatus

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
Date:		2021-05-10
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2025-10-18
Author:		WAYNE CHENG
Description: Added UPSERT logic to handle race condition where order status
             updates arrive before initial record creation. If UPDATE affects
             0 rows, will attempt to INSERT a record with the current status.
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_UpdateTradeStockStatus'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''
		DECLARE @intRowsAffected AS INT;				SET @intRowsAffected = 0

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

		-- Try to UPDATE existing record
		update a
		set SourceOrderStatus = @pvchOrderStatus,
			TradeStatus = case when @pvchOrderStatus in ('Filled') then 'FF'
							   when @pvchOrderStatus in ('Submitted') then 'P'
							   when @pvchOrderStatus in ('Cancelled', 'ApiCancelled') then 'CA'
							   else TradeStatus
						  end,
			LastUpdateDate = getdate()
		from StockAPI.TradeStock as a
		where SourceOrderID = @pvchSourceOrderId
		and (ASXCode = @pvchASXCode or ASXCode = @pvchASXCode + '.AX' or ASXCode = @pvchASXCode + '.US')
		and BuySellFlag = @pvchBuySellFlag
		and TradeStatus not in ('FF', 'CA')
		and datediff(day, a.CreateDate, getdate()) <= 3

		SET @intRowsAffected = @@ROWCOUNT

		-- Fix 5: UPSERT logic - If UPDATE affected 0 rows, INSERT a fallback record
		-- This handles the race condition where order status arrives before initial record creation
		IF @intRowsAffected = 0
		BEGIN
			RAISERROR('Not able to find the order to update the status', 16, 1);
		END

		-- Handle Order.Order table updates (unchanged)
		update a
		set a.OrderPlaceDate = null
		from [Order].[Order] as a
		inner join StockAPI.TradeStock as b
		on 1 = 1
		and b.ASXCode = a.ASXCode
		and a.OrderID = b.OrderId
		where 1 = 1
		and a.ASXCode = @pvchASXCode
		and (b.TradeStatus in ('CA') or b.SourceOrderStatus in ('Cancelled', 'ApiCancelled'))
		and a.OrderPlaceDate is not null
		and a.OrderTypeID in (8, 9, 12, 13);

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
