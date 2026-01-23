-- Stored procedure: [StockData].[usp_AddMarketDepth]






CREATE PROCEDURE [StockData].[usp_AddMarketDepth]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchMarketDepth as varchar(max),
@pvchDateTime as varchar(100)
--@pintOrderTypeID tinyint,
--@pintOrderPosition smallint,
--@pvchASXCode varchar(10),
--@pintNumberOfOrder smallint,
--@pintVolume int,
--@pdecPrice decimal(20, 4)
AS
/******************************************************************************
File: usp_AddMarketDepth.sql
Stored Procedure Name: usp_AddMarketDepth
Overview
-----------------
usp_AddMarketDepth

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
Date:		2016-05-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddMarketDepth'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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
		
		--@pxmlMarketDepth

		--declare @pvchDateTime as varchar(100) = '10 Aug 11:49:16 PM'

		declare @vchModifiedDateTime as varchar(100) = left(@pvchDateTime, 7) + cast(year(getdate()) as varchar(4)) + ' ' + parsename(replace(@pvchDateTime, ' ', '.'), 2) + ' ' + parsename(replace(@pvchDateTime, ' ', '.'), 1)

		--select convert(smalldatetime, @vchModifiedDateTime, 113)

		insert into StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate
		)
		select
			10 as DataTypeID,
			@pvchMarketDepth as RawData,
			getdate() as CreateDate,
			convert(datetime, @vchModifiedDateTime, 113) as SourceSystemDate
		
		declare @vchStockCode as varchar(20)
		declare @xmlMarketDepth as xml
		--select @xmlMarketDepth = cast(RawData as xml) from StockData.RawData
		--where RawDataID = 9
		select @xmlMarketDepth = cast(@pvchMarketDepth as xml)

		select @vchStockCode = @xmlMarketDepth.value('(/MarketDepth/stockCode)[1]', 'varchar(20)')

		if object_id(N'Tempdb.dbo.#TempBuyerList') is not null
			drop table #TempBuyerList

		select 
			x.mdi.value('position[1]', 'varchar(100)') as position,
			x.mdi.value('NumTraders[1]', 'varchar(100)') as NumTraders,
			x.mdi.value('volume[1]', 'varchar(100)') as volume,
			x.mdi.value('price[1]', 'varchar(100)') as price
		into #TempBuyerList
		from @xmlMarketDepth.nodes('/MarketDepth/buyerList/MarketDepthItem') as x(mdi)
		
		if object_id(N'Tempdb.dbo.#TempSellerList') is not null
			drop table #TempSellerList

		select 
			x.mdi.value('position[1]', 'varchar(100)') as position,
			x.mdi.value('NumTraders[1]', 'varchar(100)') as NumTraders,
			x.mdi.value('volume[1]', 'varchar(100)') as volume,
			x.mdi.value('price[1]', 'varchar(100)') as price
		into #TempSellerList
		from @xmlMarketDepth.nodes('/MarketDepth/sellerList/MarketDepthItem') as x(mdi)

		update a
		set a.DateTo = convert(datetime, @vchModifiedDateTime, 113)
		from [StockData].[MarketDepth] as a
		left join #TempBuyerList as b
		on a.OrderPosition = b.position
		and a.NumberOfOrder = b.NumTraders
		and a.Volume = b.volume
		and a.Price = b.price
		where a.ASXCode = @vchStockCode
		and a.DateTo is null
		and a.OrderTypeID = 1
		and b.price is null
		
		insert into [StockData].[MarketDepth]
		(
		   [OrderTypeID]
		  ,[OrderPosition]
		  ,[NumberOfOrder]
		  ,[Volume]
		  ,[Price]
		  ,[ASXCode]
		  ,[DateFrom]
		  ,[DateTo]
		)
		select
		   1 as [OrderTypeID]
		  ,position as [OrderPosition]
		  ,NumTraders as [NumberOfOrder]
		  ,volume as [Volume]
		  ,price as [Price]
		  ,@vchStockCode as [ASXCode]
		  ,convert(datetime, @vchModifiedDateTime, 113) as [DateFrom]
		  ,null as [DateTo]
		from #TempBuyerList as a
		where not exists
		(
			select 1
			from [StockData].[MarketDepth]
			where ASXCode = @vchStockCode
			and position = a.position
			and NumberOfOrder = a.NumTraders
			and Volume = a.volume
			and Price = a.price
			and OrderTypeID = 1
			and DateTo is null
		)

		update a
		set a.DateTo = convert(datetime, @vchModifiedDateTime, 113)
		from [StockData].[MarketDepth] as a
		left join #TempSellerList as b
		on a.OrderPosition = b.position
		and a.NumberOfOrder = b.NumTraders
		and a.Volume = b.volume
		and a.Price = b.price
		where a.ASXCode = @vchStockCode
		and a.DateTo is null
		and a.OrderTypeID = 2
		and b.price is null
		
		insert into [StockData].[MarketDepth]
		(
		   [OrderTypeID]
		  ,[OrderPosition]
		  ,[NumberOfOrder]
		  ,[Volume]
		  ,[Price]
		  ,[ASXCode]
		  ,[DateFrom]
		  ,[DateTo]
		)
		select
		   2 as [OrderTypeID]
		  ,position as [OrderPosition]
		  ,NumTraders as [NumberOfOrder]
		  ,volume as [Volume]
		  ,price as [Price]
		  ,@vchStockCode as [ASXCode]
		  ,convert(datetime, @vchModifiedDateTime, 113) as [DateFrom]
		  ,null as [DateTo]
		from #TempSellerList as a
		where not exists
		(
			select 1
			from [StockData].[MarketDepth]
			where ASXCode = @vchStockCode
			and position = a.position
			and NumberOfOrder = a.NumTraders
			and Volume = a.volume
			and Price = a.price
			and OrderTypeID = 2
			and DateTo is null
		)

		declare @dtmFakeSaleDate as datetime = dateadd(second, 5, convert(datetime, @vchModifiedDateTime, 113))

		--declare @dtmFakeSaleDate as datetime = '2017-11-24 10:02:00'
		--declare @vchStockCode as varchar(10) = 'MMJ.AX'

		if object_id(N'Tempdb.dbo.#TempPreMarket') is not null
			drop table #TempPreMarket

		select 
			*, 
			cast(null as bigint) as VolAcc, 
			cast(null as bigint) as VolAccPrev, 
			cast(null as int) as MatchOrderPosition,
			cast(null as bigint) as MatchOrderVolAcc,
			cast(null as decimal(20, 4)) as MatchOrderPrice,
			cast(null as char(1)) as IsBuyMatchSell, 
			cast(null as decimal(20, 4)) as IndicativePrice, 
			cast(null as bigint) as SaleVolume 
		into #TempPreMarket
		from StockData.MarketDepth
		where ASXCode = @vchStockCode
		and DateFrom < @dtmFakeSaleDate
		and isnull(DateTo, '2020-01-12') > @dtmFakeSaleDate
		order by OrderTypeID, OrderPosition

		update a
		set a.VolAcc = c.VolAcc
		from #TempPreMarket as a
		inner join
		(
			select a.OrderTypeID, a.OrderPosition, sum(b.Volume) as VolAcc
			from #TempPreMarket as a
			inner join #TempPreMarket as b
			on a.OrderTypeID = b.OrderTypeID
			and a.OrderPosition >= b.OrderPosition
			group by a.OrderTypeID, a.OrderPosition
		) as c
		on a.OrderTypeID = c.OrderTypeID
		and a.OrderPosition = c.OrderPosition
		
		update a
		set a.VolAccPrev = b.VolAcc
		from #TempPreMarket as a
		inner join #TempPreMarket as b
		on a.OrderPosition = b.OrderPosition + 1
		and a.OrderTypeID = b.OrderTypeID

		update a
		set a.VolAccPrev = 0
		from #TempPreMarket as a
		where OrderPosition = 1

		update x
		set x.MatchOrderPosition = y.SellOrderPosition,
			x.MatchOrderVolAcc = z.VolAcc,
			x.MatchOrderPrice = z.Price
		from #TempPreMarket as x
		inner join
		(
			select 
				a.OrderPosition as BuyOrderPosition,
				max(b.OrderPosition) as SellOrderPosition
			from #TempPreMarket as a
			inner join #TempPreMarket as b
			on a.OrderTypeID = 1
			and b.OrderTypeID = 2
			and a.VolAcc > b.VolAccPrev
			and b.VolAcc > a.VolAccPrev
			and a.Price >= b.Price
			group by a.OrderPosition
		) as y
		on x.OrderTypeID = 1
		and x.OrderPosition = y.BuyOrderPosition
		inner join #TempPreMarket as z
		on y.SellOrderPosition = z.OrderPosition
		and z.OrderTypeID = 2

		declare @decIndicativePrice as decimal(20, 4)
		declare @intSaleVolume as bigint
		declare @vchBuySellIndicator as char(1) 

		update a 
		set
			IndicativePrice = case when a.VolAcc >= b.MatchOrderVolAcc then a.Price else b.MatchOrderPrice end,
			IsBuyMatchSell = case when a.VolAcc >= b.MatchOrderVolAcc then 'B' else 'S' end,
			SaleVolume = a.VolAcc - b.MatchOrderVolAcc
		from #TempPreMarket as a
		inner join
		(
			select 
				MarketDepthID,
				MatchOrderPosition,
				MatchOrderVolAcc,
				MatchOrderPrice,
				row_number() over (order by OrderPosition desc) as RowNumber
			from #TempPreMarket
			where MatchOrderPosition is not null
		) as b
		on a.MarketDepthID = b.MarketDepthID
		where b.RowNumber = 1

		select 
			@decIndicativePrice = IndicativePrice,
			@vchBuySellIndicator = IsBuyMatchSell,
			@intSaleVolume = SaleVolume
		from #TempPreMarket
		where IndicativePrice is not null

		if @decIndicativePrice is not null
		begin
			insert into [StockData].[IndicativePrice]
			(
			   [SaleDateTime]
			  ,[Price]
			  ,[Quantity]
			  ,[ASXCode]
			  ,[CreateDate]
			  ,[ActBuySellInd]
			)
			select
			   @dtmFakeSaleDate as [SaleDateTime]
			  ,@decIndicativePrice as [Price]
			  ,@intSaleVolume as [Quantity]
			  ,@vchStockCode as [ASXCode]
			  ,getdate() as [CreateDate]
			  ,@vchBuySellIndicator as [ActBuySellInd]
		
			--select @decIndicativePrice
			--select @intSaleVolume
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
