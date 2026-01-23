-- Stored procedure: [Order].[usp_PlaceOrder]


CREATE PROCEDURE [Order].[usp_PlaceOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_PlaceOrder.sql
Stored Procedure Name: usp_PlaceOrder
Overview
-----------------
usp_PlaceOrder

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
Date:		2018-08-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_PlaceOrder'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Order'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		declare @vchASXCode as varchar(10)
		declare @decOrderPrice as decimal(20, 4)
		declare @intOrderVolume as int
		declare @dtValidUntil as smalldatetime
		declare @intOrderID as int
		declare @vchTradeAccountName as varchar(100)
		declare @vchBuySellFlag as char(1)

		declare @pvchOutputMessage varchar(max)
		declare @pvchErrorMessage varchar(max)
		declare @intTradeRequestID as int

		--Code goes here 
		--declare @intNumPrevDay as int = 125

		if exists
		(
			select 1
			from [Order].[Order]
			where 1 = 1
			--and OrderTypeID in (1, 2)
			and OrderTriggerDate is not null
			and datediff(second, OrderTriggerDate, getdate()) < 120
			and OrderProcessDate is null
			and ValidUntil > getdate()
		)
		begin

			--declare @vchASXCode as varchar(10)
			--declare @decOrderPrice as decimal(20, 4)
			--declare @intOrderVolume as int
			--declare @dtValidUntil as smalldatetime
			--declare @intOrderID as int

			select @vchASXCode = ''
			select @decOrderPrice = 0
			select @intOrderVolume = 0
			select @dtValidUntil = '1900-12-12'
			select @intOrderID = 0
			select @vchTradeAccountName = ''
			select @vchBuySellFlag = ''

			declare curOrder cursor for
			select 
				a.ASXCode, 
				a.OrderPrice, 
				a.OrderVolume, 
				a.ValidUntil, 
				a.OrderID, 
				a.TradeAccountName, 
				b.BuySellFlag
			from [Order].[Order] as a
			inner join LookupRef.OrderType as b
			on a.OrderTypeID = b.OrderTypeID
			where 1 = 1
			--and OrderTypeID in (1, 2)
			and OrderTriggerDate is not null
			and datediff(second, OrderTriggerDate, getdate()) < 120
			and OrderPlaceDate is null
			and ValidUntil > getdate()

			open curOrder
			fetch curOrder into @vchASXCode, @decOrderPrice, @intOrderVolume, @dtValidUntil, @intOrderID, @vchTradeAccountName, @vchBuySellFlag

			while @@fetch_status = 0
			begin
				print @vchASXCode
				print @decOrderPrice
				print @intOrderVolume
				print @dtValidUntil

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
					  ,[TradeStrategyMessage]
					  ,[TradeRank]
					  ,[IsNotificationSent]
					  ,TradeAccountName
				)
				select
					   @vchASXCode as [ASXCode]
					  ,@vchBuySellFlag as [BuySellFlag]
					  ,@decOrderPrice as [Price]
					  ,null as [StopLossPrice]
					  ,null as [StopProfitPrice]
					  ,@intOrderVolume as [MinVolume]
					  ,@intOrderVolume as [MaxVolume]
					  ,-1 as [RequestValidTimeFrameInMin]
					  ,@dtValidUntil as [RequestValidUntil]
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
					  ,null as [AccountNumber]
					  ,101 as [TradeStrategyID]
					  ,0 as [ErrorCount]
					  ,cast(@intOrderID as varchar(20)) as [TradeStrategyMessage]
					  ,100 as [TradeRank]
					  ,null as [IsNotificationSent]
					  ,@vchTradeAccountName as TradeAccountName

				select @intTradeRequestID = @@IDENTITY

				update a
				set OrderProcessDate = getdate()
				from [Order].[Order] as a
				where OrderID = @intOrderID

				select @pvchOutputMessage = ''
				select @pvchErrorMessage = ''

				exec [Order].[usp_ConsumeAPIPlaceOrder]
				@pvchStockCode = @vchASXCode,
				@intTradeRequestID = @intTradeRequestID,
				@vchTradeAccountName = @vchTradeAccountName,
				@pvchOutputMessage = @pvchOutputMessage output,
				@pvchErrorMessage = @pvchErrorMessage output

				print @pvchOutputMessage

				if @pvchOutputMessage like '%Trade executed on the required stock%'
				begin
					update a
					set OrderPlaceDate = getdate()
					from [Order].[Order] as a
					where OrderID = @intOrderID
				end

				fetch curOrder into @vchASXCode, @decOrderPrice, @intOrderVolume, @dtValidUntil, @intOrderID, @vchTradeAccountName, @vchBuySellFlag

			end

			close curOrder
			deallocate curOrder

			
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
		if cursor_status('global','curOrder')>=-1
		begin
			deallocate curOrder
		end

		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
