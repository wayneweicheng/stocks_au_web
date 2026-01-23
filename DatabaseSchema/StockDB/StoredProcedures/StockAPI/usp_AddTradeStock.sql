-- Stored procedure: [StockAPI].[usp_AddTradeStock]

CREATE PROCEDURE [StockAPI].[usp_AddTradeStock]
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
@pintOrderId int = 0,
@pvchSourceOrderId varchar(100) = null,
@pvchTradeStatus varchar(2) = 'P',
@pvchConditionCode varchar(10) = null,
@pdecRSI as decimal(10,3) = null,
@pvchTradeStatusMessage varchar(max) = null
AS
/******************************************************************************
File: usp_AddTradeStock.sql
Stored Procedure Name: usp_AddTradeStock
Overview
-----------------
usp_AddTradeStock

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddTradeStock'
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
		select @pvchTradeStatus = case when @pvchTradeTypeID in ('SAB', 'SABB', 'BWBVU', 'BAAA') and @pvchTradeStatus = 'P' then 'FF' else @pvchTradeStatus end

		if not exists
		(
			select 1
			from LookupRef.TradingAccount
			where TradingPlatform in ('IB', 'CMC')
			and TradeAccountName = @pvchTradeAccountName
		)
		begin
			raiserror('TradeAccountName supplied not valid', 16, 0)
		end

		if @pvchBuySellFlag not in ('B', 'S')
		begin
			raiserror('BuySellFlag supplied not valid', 16, 0)
		end

		if @pvchBuySellFlag in ('S') 
		and @pintLinkedTradeStockId is not null
		and not exists
		(
			select 1
			from [StockAPI].[TradeStock]
			where TradeStockId = @pintLinkedTradeStockId
			and BuySellFlag = 'B'
			and ASXCode = @pvchASXCode
			and isnull(LinkedTradeStockId, -1) = -1
		)
		begin
			raiserror('LinkedTradeStockId supplied not valid', 16, 0)
		end

		declare @intNewTradeStockId as int

		insert into [StockAPI].[TradeStock]
		(
		   [ASXCode]
		  ,[BuySellFlag]
		  ,[Price]
		  ,[StopLossPrice]
		  ,[StopProfitPrice]
		  ,[CreateDate]
		  ,[LastTryDate]
		  ,[OrderPlaceDate]
		  ,[OrderPlaceVolume]
		  ,[OrderReceiptID]
		  ,[OrderFillPrice]
		  ,[OrderFillDate]
		  ,[OrderFillVolume]
		  ,[TradeStatus]
		  ,[TradeStatusMessage]
		  ,[AccountNumber]
		  ,[TradeTypeID]
		  ,[ErrorCount]
		  ,[TradeTypeMessage]
		  ,[TradeRank]
		  ,[IsNotificationSent]
		  ,[TradeAccountName]
		  ,[LastUpdateDate]
		  ,LinkedTradeStockId
		  ,OrderId
		  ,SourceOrderId
		  ,ConditionCode
		  ,RSI
		)
		select
		   @pvchASXCode as [ASXCode]
 		  ,@pvchBuySellFlag as [BuySellFlag]
		  ,@pdecPrice as [Price]
		  ,@pdecStopLossPrice as [StopLossPrice]
		  ,@pdecStopProfitPrice as [StopProfitPrice]
		  ,getdate() as [CreateDate]
		  ,null as [LastTryDate]
		  ,getdate() as [OrderPlaceDate]
		  ,@pintVolume as [OrderPlaceVolume]
		  ,@pvchOrderReceiptID as [OrderReceiptID]
		  ,null as [OrderFillPrice]
		  ,null as [OrderFillDate]
		  ,null as [OrderFillVolume]
		  --,'P' as [TradeStatus] --P stands for "placed"
		  --,case when @pvchTradeTypeID = 'NDS' then 'FF' else 'P' end as [TradeStatus] --P: "placed" FF: "Fully Filled" E: "Errored"
		  ,@pvchTradeStatus as [TradeStatus] --P: "placed" FF: "Fully Filled" E: "Errored"
		  ,null as [TradeStatusMessage]
		  ,null as [AccountNumber]
		  ,@pvchTradeTypeId as [TradeTypeID]
		  ,0 as [ErrorCount]
		  ,null as [TradeTypeMessage]
		  ,99 as [TradeRank]
		  ,null as [IsNotificationSent]
		  ,@pvchTradeAccountName as [TradeAccountName]
		  ,getdate() as [LastUpdateDate]
		  ,case when @pintLinkedTradeStockId is not null then @pintLinkedTradeStockId else -1 end as LinkedTradeStockId
		  ,case when @pintOrderId > 0 then @pintOrderId else null end as OrderId
		  ,@pvchSourceOrderId as SourceOrderId
		  ,@pvchConditionCode as ConditionCode
		  ,@pdecRSI as RSI

		  select @intNewTradeStockId  = @@IDENTITY

		  if @pvchBuySellFlag = 'S'
		  begin
			update a
			set LinkedTradeStockId = @intNewTradeStockId 
			from [StockAPI].[TradeStock] as a
			where TradeStockId = @pintLinkedTradeStockId
		  end

		  if @pintOrderId > 0
		  begin
			update a
			set OrderTriggerDate = getdate(),
				OrderPlaceDate = getdate(),
				ActualOrderPrice = @pdecPrice
			from [Order].[Order] as a
			where OrderID = @pintOrderId
		  end

		  if @pvchTradeTypeID = 'BADRFD'
		  begin
			update a
			set ProcessDate = getdate()
			from [StockAPI].[TradeCandidateRiseFromDip] as a
			where ASXCode = @pvchASXCode
			and cast(CreateDate as date) = cast(getdate() as date)
			and ProcessDate is null
		  end

		--if @pvchBuySellFlag in ('B')
		--begin
		--	insert into [StockData].[CurrentHoldings]
		--	(
		--	   [ASXCode]
		--	  ,[HeldPrice]
		--	  ,[HeldVolume]
		--	  ,[CreateDate]
		--	)
		--	select
		--	   @pvchASXCode as [ASXCode]
		--	  ,@pdecPrice as [HeldPrice]
		--	  ,@pintVolume as [HeldVolume]
		--	  ,getdate() as [CreateDate]
		--	where not exists
		--	(
		--		select 1
		--		from [StockData].[CurrentHoldings]
		--		where ASXCode = @pvchASXCode
		--	)
		--end

		
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