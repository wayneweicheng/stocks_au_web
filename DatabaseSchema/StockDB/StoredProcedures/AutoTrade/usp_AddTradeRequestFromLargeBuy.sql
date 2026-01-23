-- Stored procedure: [AutoTrade].[usp_AddTradeRequestFromLargeBuy]

CREATE PROCEDURE [AutoTrade].[usp_AddTradeRequestFromLargeBuy]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@intNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_AddTradeRequestFromLargeBuy.sql
Stored Procedure Name: usp_AddTradeRequestFromLargeBuy
Overview
-----------------
usp_AddTradeRequestFromLargeBuy

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
Date:		2018-01-14
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddTradeRequestFromLargeBuy'
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
		--declare @intNumPrevDay as int = 125
		declare @dtEnqDate as date = dateadd(day, -1 * @intNumPrevDay, cast(getdate() as date))

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		select *
		into #TempCourseOfSale
		from StockData.v_CourseOfSale as a
		where cast(SaleDateTime as date) = @dtEnqDate
		and datepart(hour, SaleDateTime) < 16
		and 
		(
			datepart(hour, SaleDateTime) > 10 
			or
			(datepart(hour, SaleDateTime) = 10 and datepart(minute, SaleDateTime) > 12)
		)
		and a.Price < 0.90

		if object_id(N'Tempdb.dbo.#TempLargeSale') is not null
			drop table #TempLargeSale
		
		select identity(int, 1, 1) as TimeSlot, a.*, a.Price*a.Quantity as SaleValue, b.AvgSaleValue, case when b.AvgSaleValue > 0 then a.Price*a.Quantity/b.AvgSaleValue else null end as PriceToAvgRatio
		into #TempLargeSale
		from #TempCourseOfSale as a
		inner join StockData.v_LastTenDayAvgSaleValue as b
		on a.ASXCode = b.ASXCode
		and case when b.AvgSaleValue > 0 then a.Price*a.Quantity/b.AvgSaleValue else null end > 0
		where Price*Quantity > 2000
		and ActBuySellInd in ('B', 'S')
		order by SaleDateTime asc

		declare @intCount as int = 1

		while @intCount > 0
		begin
			select @intCount = 0

			update b
			set SaleDateTime = a.SaleDateTime
			from #TempLargeSale as a
			inner join #TempLargeSale as b
			on a.ASXCode = b.ASXCode
			and a.ActBuySellInd = b.ActBuySellInd
			and a.Price = b.Price
			and datediff(second, a.SaleDateTime, b.SaleDateTime) <= 90
			and a.SaleDateTime < b.SaleDateTime

			select @intCount = @@ROWCOUNT
		end

		if object_id(N'Tempdb.dbo.#TempLargeSalePlus') is not null
			drop table #TempLargeSalePlus

		select 
			a.ASXCode, 
			SaleDateTime, 
			Price, 
			ActBuySellInd, 
			AvgSaleValue, 
			sum(Quantity) as Quantity, 
			sum(SaleValue) as SaleValue, 
			sum(SaleValue)*1.0/AvgSaleValue as PriceToAvgRatio,
			sum(SaleValue)*1.0/(b.MarketCap*1000000.0) as PercOfMC
		into #TempLargeSalePlus
		from #TempLargeSale as a
		left join StockData.StockOverview as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		group by a.ASXCode, SaleDateTime, Price, ActBuySellInd, AvgSaleValue, b.MarketCap
		having 
		(
			sum(SaleValue)*1.0/AvgSaleValue > 7.5 
			or
			sum(SaleValue)*1.0/(b.MarketCap*1000000.0) > 0.005
		)
		and sum(SaleValue) > 15000
		
		if object_id(N'Tempdb.dbo.#TempCadidateSale') is not null
			drop table #TempCadidateSale	

		select 
			ASXCode, 
			SaleDateTime, 
			Price, 
			ActBuySellInd, 
			AvgSaleValue, 
			Quantity, 
			SaleValue, 
			PriceToAvgRatio,
			PercOfMC*100.0[Percentage of MC],
			case when a.ActBuySellInd = 'S' then 'Sell' when a.ActBuySellInd = 'B' then 'Buy' else 'Indetermined' end as BuySellIndicator
		into #TempCadidateSale
		from #TempLargeSalePlus as a
		where 1 = 1
		and datepart(hour, SaleDateTime) < 16
		and 
		(
			datepart(hour, SaleDateTime) > 10 
			or
			(datepart(hour, SaleDateTime) = 10 and datepart(minute, SaleDateTime) > 12)
		)
		and a.Price < 0.90
		order by PercOfMC desc, a.PriceToAvgRatio desc	

		if object_id(N'Tempdb.dbo.#TempLargeBuy') is not null
			drop table #TempLargeBuy

		select * 
		into #TempLargeBuy
		from #TempCadidateSale as a
		where BuySellIndicator = 'Buy'
		and 
		(
			([Percentage of MC] > 0.08 and SaleValue >150000 and PriceToAvgRatio > 8)
			or
			([Percentage of MC] > 0.24 and SaleValue >50000 and PriceToAvgRatio > 8)
			or
			([Percentage of MC] > 0.65 and SaleValue >30000 and PriceToAvgRatio > 4)
		)
		and not exists
		(
			select 1
			from #TempCadidateSale
			where BuySellIndicator = 'Sell'
			and ASXCode = a.ASXCode
			and SaleDateTime < a.SaleDateTime
		)

		declare @bitAddRequest as bit = 1

		if @bitAddRequest = 1
		begin

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
			)
			select
			   a.ASXCode as [ASXCode]
			  ,'B' as [BuySellFlag]
			  ,Price as [Price]
			  ,null as [StopLossPrice]
			  ,Price as [StopProfitPrice]
			  ,cast(3000.0/Price as int) as [MinVolume]
			  ,cast(3000.0/Price as int) as [MaxVolume]
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
			  ,null as [AccountNumber]
			  ,2 as [TradeStrategyID]
			  ,0 as [ErrorCount]
			  ,--'ASXCode: ' + cast(a.ASXCode as varchar(50)) + ', ' +
			   'SaleDateTime: ' + Convert(varchar(50), SaleDateTime, 126) + ', ' +
			   'Price: ' + cast(Price as varchar(50)) + ', ' +
			   --'AvgSaleValue: ' + cast(AvgSaleValue as varchar(50)) + ', ' +
			   --'Quantity: ' + cast(Quantity as varchar(50)) + ', ' +
			   'SaleValue: ' + cast(SaleValue as varchar(50)) + ', ' +
			   'PriceToAvgRatio: ' + cast(PriceToAvgRatio as varchar(50)) + ', ' +
			   'Percentage of MC: ' + cast([Percentage of MC] as varchar(50))
			   --'BuySellIndicator: ' + cast(BuySellIndicator as varchar(50))
			   as TradeStrategyMessage
			  ,800 as TradeRank
			  ,case when b.SMSAlertSetupDate is not null then 0 else null end as IsNotificationSent
			from #TempLargeBuy as a
			left join StockData.MonitorStock as b
			on a.ASXCode = b.ASXCode
			and b.MonitorTypeID = 'C'
			and cast(b.SMSAlertSetupDate as date) = cast(getdate() as date)
			where not exists
			(
				select 1
				from [AutoTrade].[TradeRequest]
				where ASXCode = a.ASXCode
				and BuySellFlag = 'B'
				and datediff(hour, CreateDate, getdate()) < 24
			)
			
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