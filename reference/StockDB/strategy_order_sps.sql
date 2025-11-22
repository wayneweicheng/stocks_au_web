USE [StockDB]
GO

/****** Object:  StoredProcedure [Order].[usp_AddOrder]    Script Date: 20/10/2025 10:13:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [Order].[usp_AddOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(20),
@pintUserID int,
@pvchTradeAccountName varchar(100),
@pintOrderTypeID int,
@pvchOrderPriceType varchar(100),
@pdecOrderPrice decimal(20, 4) = null,
@pintVolumeGT bigint = null,
@pintOrderVolume bigint = null,
@pdecOrderValue decimal(20, 4) = null,
@pintOrderPriceBufferNumberOfTick int = null,
@pvchValidUntil varchar(100) = null,
@pvchAdditionalSettings varchar(max) = null,
@pvchMessage as varchar(200) output
AS
/******************************************************************************
File: usp_AddTradingAlert.sql
Stored Procedure Name: usp_AddTradingAlert
Overview
-----------------
usp_AddTradingAlert

Input Parameters
----------------2
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
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2020-01-03
Author:		WAYNE CHENG
Description: Add in addtional parameters OrderPriceType and OrderPriceBufferNumberOfTick
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOrder'
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
		--declare @pvchOrderPriceType as varchar(10) = 'Price'
		--declare @pvchASXCode as varchar(20) = 'BCB.AX'
		--declare @pdecOrderPrice as decimal(20, 4) = 0.0035
		declare @bitPriceCheckSuccess as bit = 1

		if @pvchAdditionalSettings is not null and not isjson(@pvchAdditionalSettings) = 1
		begin
			--raiserror('Invalid order price', 16, 0)
			select @pvchMessage = 'Invalid AdditionalSettings, not a valid json'
			select @bitPriceCheckSuccess = 0
		end

		declare @pvchBuySellFlag as varchar(1)
		select @pvchBuySellFlag = BuySellFlag
		from LookupRef.OrderType
		where OrderTypeID = @pintOrderTypeID

		if @pvchOrderPriceType = 'Price'
		begin
			declare @decCurrentPrice as decimal(20, 4)

			select @decCurrentPrice = [Close]
			from StockData.PriceHistoryCurrent
			where ASXCode = @pvchASXCode

			if @pdecOrderPrice > 3*@decCurrentPrice or @decCurrentPrice > 3*@pdecOrderPrice
			begin
				--raiserror('Invalid order price', 16, 0)
				select @pvchMessage = 'Invalid order price, latest close price - ' + cast(@decCurrentPrice as varchar(20))
				select @bitPriceCheckSuccess = 0
			end
		end

		if isnull(@pintOrderVolume, -1) < 0 and @pvchBuySellFlag = 'S'
		begin
			select @pvchMessage = 'Invalid order volume - ' + cast(@pintOrderVolume as varchar(10)) + '. Volume must be provided'
			select @bitPriceCheckSuccess = 0
		end

		if isnull(@pdecOrderValue, -1) < 0 and @pvchBuySellFlag = 'B'
		begin
			select @pvchMessage = 'Invalid order value - ' + cast(@pdecOrderValue as varchar(10)) + '. Value must be provided'
			select @bitPriceCheckSuccess = 0
		end

		if isnull(@pdecOrderPrice, -1) < 0
		begin
			select @pvchMessage = 'Invalid order price - ' + cast(@pdecOrderPrice as varchar(10)) + '. Price must be provided'
			select @bitPriceCheckSuccess = 0
		end

		if @bitPriceCheckSuccess  = 1
		begin
			select @pvchMessage = ''

			if exists
			(
				select 1
				from LookupRef.OrderType
				where OrderType in 
				(
					'Buy Close Price Advantage', 'Sell Open Price Advantage', 'Buy Open Price Advantage', 'Sell Close Price Advantage'
				)
				and OrderTypeID = @pintOrderTypeID
			)
			begin
				select @pintVolumeGT = 98
			end

			insert into [Order].[Order]
			(
			   [ASXCode]
			  ,[UserID]
			  ,TradeAccountName
			  ,[OrderTypeID]
			  ,[OrderPriceType]
			  ,[OrderPrice]
			  ,[VolumeGt]
			  ,[OrderVolume]
			  ,[OrderValue]
			  ,[OrderPriceBufferNumberOfTick]
			  ,AdditionalSettings
			  ,[ValidUntil]
			  ,[CreateDate]
			  ,[OrderTriggerDate]
			)
			select
			   @pvchASXCode as [ASXCode]
			  ,@pintUserID as [UserID]
			  ,@pvchTradeAccountName as TradeAccountName
			  ,@pintOrderTypeID as [OrderTypeID]
			  ,@pvchOrderPriceType as [OrderPriceType]
			  ,@pdecOrderPrice as [OrderPrice]
			  ,case when @pintVolumeGt >= 0 then @pintVolumeGt else null end as [VolumeGt]
			  ,case when @pintOrderVolume >= 0 then @pintOrderVolume else null end as [OrderVolume]
			  ,case when @pdecOrderValue >= 0 then @pdecOrderValue else null end as [OrderValue]
			  ,case when @pintOrderPriceBufferNumberOfTick >= 0 then @pintOrderPriceBufferNumberOfTick else null end as OrderPriceBufferNumberOfTick
			  ,@pvchAdditionalSettings as AdditionalSettings
			  ,case when @pvchValidUntil is not null then @pvchValidUntil else dateadd(month, 1, getdate()) end as [ValidUntil]
			  ,getdate() as [CreateDate]
			  ,null as [OrderTriggerDate]

			  if right(@pvchASXCode, 3) = '.AX'
			  begin
				exec [StockData].[usp_Add_Stock_To_High_Frequency_WatchList]
				@pvchASXCode = @pvchASXCode		  
			  end

			  select @pvchMessage = 'Order on ' + @pvchASXCode + ' successfully added.'
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
GO

/****** Object:  StoredProcedure [Order].[usp_GetStrategyOrder]    Script Date: 20/10/2025 10:13:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [Order].[usp_GetStrategyOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintOrderTypeID as int = null,
@pvchTradeAccountName varchar(100) = null,
@pintOrderID as int = null,
@pvchASXCode as varchar(20) = null
AS
/******************************************************************************
File: usp_GetStrategyOrder.sql
Stored Procedure Name: usp_GetStrategyOrder
Overview
-----------------
usp_AddNotification

Input Parameters
----------------
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStrategyOrder'
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

		if object_id(N'Tempdb.dbo.#TempLastBidAsk') is not null
			drop table #TempLastBidAsk

		select *
		into #TempLastBidAsk
		from
		(
			select 
				*, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber 
			from StockData.v_PriceSummary as a
			where ObservationDate = cast(getdate() as date)
			and cast(DateFrom as time) > cast('16:00:00' as time)
			AND IndicativePrice > 0
			and exists
			(
				select 1
				from [Order].[v_Order]
				where ASXCode = a.ASXCode
				and CreateDate > dateadd(day, -20, getdate())
			)
		) as a
		where a.RowNumber = 1

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
			c.[Close] as CurrentPrice,
			case when c.[Close] > 0 and a.[OrderPrice] > 0 then cast(cast((c.[Close] - a.[OrderPrice])*100.0/a.[OrderPrice] as decimal(10, 2)) as varchar(50)) + '%' else null end as DifferenceToCurrentPrice,
			isnull(OrderPriceBufferNumberOfTick, 0) as PriceBufferNumberOfTick,
			isnull([VolumeGt], 0) as [CustomIntegerValue],
			[OrderVolume],
			cast(OrderValue as int) as OrderValue,
			ValidUntil,
			a.[CreateDate],
			[OrderTriggerDate],
			b.BuySellFlag,
			isnull(e.IndicativePrice, -1) as IndicativePrice,
			isnull(e.SurplusVolume, -1) as SurplusVolume,
			isnull(e.MatchVolume, -1) as MatchVolume,
			a.AdditionalSettings,
		    AS_TriggerPrice,
		    AS_TotalVolume,
		    AS_Entry1Price,
		    AS_Entry2Price,
		    AS_StopLossPrice,
		    AS_ExitStrategy,
		    AS_Exit1Price,
		    AS_Exit2Price,
			AS_BarCompletedInMin,
			OptionSymbol,
			OptionSymbolDetails,
			OptionBuySell
		into #TempOrder
		from [Order].[v_Order] as a with(nolock)
		inner join LookupRef.OrderType as b with(nolock)
		on b.IsDisabled = 0
		and a.OrderTypeID = b.OrderTypeID
		and (@pintOrderTypeID = -1 or a.OrderTypeID = @pintOrderTypeID)
		and (@pintOrderID is null or a.OrderID = @pintOrderID)
		left join Alert.v_StockStatsHistoryPlusCurrent as c with(nolock)
		on a.ASXCode = c.ASXCode
		--left join StockData.v_PriceSummary_Latest_Today as d with(nolock)
		--on a.ASXCode = d.ASXCode
		--and d.ObservationDate = cast(getdate() as date)
		left join #TempLastBidAsk as e
		on a.ASXCode = e.ASXCode
		where 1 = 1
		--and a.ASXCode not in ('HLX.AX')
		
		and 
		(
			(
				b.OrderType not like '%Strategy %'
				and not exists
				(
					select 1
					from StockAPI.TradeStock
					where OrderId = a.OrderID
					and TradeStatus in ('FF')
				)
			)
			or
			(
				b.OrderType like '%Strategy %'
				and 
				(
					not exists
					(
						select 1
						from StockAPI.TradeStock
						where OrderId = a.OrderID
						and TradeStatus in ('FF')
						and BuySellFlag = 'B'
					)
					or
					not exists
					(
						select 1
						from StockAPI.TradeStock
						where OrderId = a.OrderID
						and TradeStatus in ('FF')
						and BuySellFlag = 'S'
					)
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
		and datediff(hour, a.CreateDate, getdate()) < 72
		order by a.CreateDate desc
		
		select 
			OrderID,
			ASXCode,
			TradeAccountName,
			OrderTypeID,
			AS_TriggerPrice as TriggerPrice,
			AS_TotalVolume as TotalVolume,
			AS_Entry1Price as EntryPrice,
			AS_StopLossPrice as StopLossPrice,
			AS_ExitStrategy as ExitStrategy,
			AS_Exit1Price as ExitPrice,
			AS_BarCompletedInMin as BarCompletedInMin,
			OptionSymbol,
			OptionSymbolDetails,
			OptionBuySell,
			(AS_Entry1Price - AS_StopLossPrice)*AS_TotalVolume as PotentialLoss,
			(AS_Exit1Price - AS_Entry1Price)*AS_TotalVolume as PotentialProfit,
			case when (AS_Entry1Price - AS_StopLossPrice)*AS_TotalVolume > 0 then ((AS_Exit1Price - AS_Entry1Price)*AS_TotalVolume)*1.0/((AS_Entry1Price - AS_StopLossPrice)*AS_TotalVolume) else null end as ProfitLossRatio,
			OrderType,					
			CreateDate
		from #TempOrder
		where OrderType like 'Strategy %'
		--select *, row_number() over(partition by ASXCode, OrderTypeID, TradeAccountName order by case when BuySellFlag = 'B' then AdjustedOrderPrice desc)
		--from #TempOrder

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
GO

/****** Object:  StoredProcedure [Order].[usp_GetStrategyOrderType]    Script Date: 20/10/2025 10:13:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [Order].[usp_GetStrategyOrderType]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetStrategyOrderType.sql
Stored Procedure Name: usp_GetStrategyOrderType
Overview
-----------------
usp_GetStrategyOrderType

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStrategyOrderType'
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
		select cast(OrderTypeID as varchar(20)) + ': ' + OrderType
		from
		(
			select
				-1 as OrderTypeID,
				'All Orders' as OrderType,
				5 as DisplayOrder
			union
			select
				OrderTypeID,
				case when IsDisabled = 1 then '**' + OrderType else OrderType end as OrderType,
				DisplayOrder
			from LookupRef.OrderType
			where OrderType like 'Strategy %'
		) as x
		order by DisplayOrder asc

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
GO

/****** Object:  StoredProcedure [Order].[usp_UpdateOrder]    Script Date: 20/10/2025 10:13:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [Order].[usp_UpdateOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintOrderID as int,
@pdecOrderPrice decimal(20, 4) = null,
@pintVolumeGt int = null,
@pintOrderVolume int = null,
@pdecOrderValue decimal(20, 4) = null,
@pintOrderPriceBufferNumberOfTick int = null,
@pvchValidUntil varchar(100) = null,
@pvchAdditionalSettings varchar(max) = null,
@pvchMessage as varchar(200) output
AS
/******************************************************************************
File: usp_UpdateOrder.sql
Stored Procedure Name: usp_UpdateOrder
Overview
-----------------
usp_UpdateOrder

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_UpdateOrder'
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
		set dateformat dmy

		--declare @intNumPrevDay as int = 125
		update a
		set 
			OrderPrice = case when @pdecOrderPrice > 0 then @pdecOrderPrice else null end,
			OrderVolume = case when @pintOrderVolume >= 0 then @pintOrderVolume else null end,
			OrderValue = case when @pdecOrderValue >= 0 then @pdecOrderValue else null end,
			VolumeGt = case when @pintVolumeGt > 0 then @pintVolumeGt else 0 end,
			ValidUntil = case when @pvchValidUntil is not null then @pvchValidUntil else dateadd(month, 1, getdate()) end,
			AdditionalSettings = case when @pvchAdditionalSettings is not null then @pvchAdditionalSettings else null end,
			OrderPriceBufferNumberOfTick = case when @pintOrderPriceBufferNumberOfTick >= 0 then @pintOrderPriceBufferNumberOfTick else 0 end
		from [Order].[Order] as a
		where OrderID = @pintOrderID

		select @pvchMessage = 'Record updated successfully.'


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
GO

/****** Object:  StoredProcedure [Order].[usp_DeleteOrder]    Script Date: 20/10/2025 10:13:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [Order].[usp_DeleteOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintOrderID as int
AS
/******************************************************************************
File: usp_DeleteOrder.sql
Stored Procedure Name: usp_DeleteOrder
Overview
-----------------
usp_DeleteOrder

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_DeleteOrder'
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
		--delete a
		--from [Order].[Order] as a
		--where OrderID = @pintOrderID

		update a
		set IsDisabled = 1
		from [Order].[Order] as a
		where OrderID = @pintOrderID

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
GO


