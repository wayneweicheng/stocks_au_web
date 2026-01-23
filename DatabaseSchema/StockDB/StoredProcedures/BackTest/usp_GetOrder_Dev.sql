-- Stored procedure: [BackTest].[usp_GetOrder_Dev]



create PROCEDURE [BackTest].[usp_GetOrder_Dev]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintOrderTypeID as int = null,
@pvchTradeAccountName varchar(100) = null,
@pintOrderID as int = null,
@pvchASXCode as varchar(20) = null
AS
/******************************************************************************
File: usp_GetOrder.sqlf
Stored Procedure Name: usp_GetOrder
Overview
-----------------
usp_AddNotification

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
Date:		2019-12-16
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetOrder'
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
		--declare @intNumPrevDay as int = 125
		--declare @pintOrderTypeID as int = 23
		--declare @pintOrderID as int = null
		--declare @pvchASXCode as varchar(20) = null
		--declare @pvchTradeAccountName varchar(100) = null

		if @pintOrderTypeID is null
			select @pintOrderTypeID = -1

		if object_id(N'Tempdb.dbo.#TempOrder') is not null
			drop table #TempOrder

		select distinct
			[OrderID],
			upper(a.[ASXCode]) as ASXCode,
			--[UserID],
			TradeAccountName,
			a.[OrderTypeID],
			b.OrderType,
			a.OrderPriceType,
			[RawOrderPrice] as [OrderPrice],
			[OrderPrice] as AdjustedOrderPrice,
			null as CurrentPrice,
			null as DifferenceToCurrentPrice,
			isnull(OrderPriceBufferNumberOfTick, 0) as PriceBufferNumberOfTick,
			isnull([VolumeGt], 0) as [CustomIntegerValue],
			[OrderVolume],
			cast(OrderValue as int) as OrderValue,
			ValidUntil,
			a.[CreateDate],
			[OrderTriggerDate],
			b.BuySellFlag,
			null as IndicativePrice,
			null as SurplusVolume,
			null as MatchVolume,
			a.AdditionalSettings,
		    AS_TriggerPrice,
		    AS_TotalVolume,
		    AS_Entry1Price,
		    AS_Entry2Price,
		    AS_StopLossPrice,
		    AS_ExitStrategy,
		    AS_Exit1Price,
		    AS_Exit2Price,
			OptionSymbol,
			OptionSymbolDetails,
			OptionBuySell
		into #TempOrder
		from [BackTest].[v_Order] as a with(nolock)
		inner join LookupRef.OrderType as b with(nolock)
		on b.IsDisabled = 0
		and a.OrderTypeID = b.OrderTypeID
		and (@pintOrderTypeID = -1 or a.OrderTypeID = @pintOrderTypeID)
		and (@pintOrderID is null or a.OrderID = @pintOrderID)
		where 1 = 1
		--and a.ASXCode not in ('HLX.AX')		
		and 
		(			
			(
				not exists
				(
					select 1
					from BackTest.BackTestTrade
					where OrderId = a.OrderID
					and BuySell = 'B'
				)
				and
				not exists
				(
					select 1
					from BackTest.BackTestTrade
					where OrderId = a.OrderID
					and BuySell = 'S'
				)
			)
		)
		and (@pvchTradeAccountName is null or @pvchTradeAccountName = TradeAccountName)
		and (@pvchASXCode is null or a.ASXCode = @pvchASXCode)
		and isnull(a.IsDisabled, 0) = 0
		and 
		(
			--For SMA and SMAWK type orders, we allow order to exist for 72 hours after place date is populated
			(a.OrderPriceType in ('SMA', 'SMAWK') and datediff(hour, isnull(a.OrderPlaceDate, getdate()), getdate()) < 48)
			or
			--For other type of orders, we allow order to exist for 2 hours after place date is populated
			(a.OrderPriceType not in ('SMA', 'SMAWK') and datediff(minute, isnull(a.OrderPlaceDate, getdate()), getdate()) < 90)
			or
			b.OrderType like '%Strategy %'
		)
		-- Any order that is older than 72 hours, we don't include it anymore.
		and datediff(hour, a.CreateDate, getdate()) < 720
		order by a.CreateDate desc
		
		select top 10000 * 
		from #TempOrder

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
