-- Stored procedure: [Order].[usp_AddBuyCloseAdvantageConditionalOrder]


CREATE PROCEDURE [Order].[usp_AddBuyCloseAdvantageConditionalOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumOrder as int = 15
AS
/******************************************************************************
File: usp_AddBuyCloseAdvantageConditionalOrder.sql
Stored Procedure Name: usp_AddBuyCloseAdvantageConditionalOrder
Overview
-----------------
usp_AddBuyCloseAdvantageConditionalOrder

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
Date:		2021-01-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddBuyCloseAdvantageConditionalOrder'
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
		if object_id(N'Tempdb.dbo.#TempCandidate') is not null
			drop table #TempCandidate

		select ASXCode, RankNumber, BuyValue, cast(null as decimal(20, 4)) as OrderPrice, cast(null as datetime) as DateFrom, cast(null as decimal(10, 2)) as PriceChange
		into #TempCandidate
		from StockData.StrategyCandidate
		where StrategyID = 12

		if object_id(N'Tempdb.dbo.#Temp1') is not null
			drop table #Temp1

		select 
			*, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
		into #Temp1
		from StockData.PriceSummaryToday as x
		where 1 = 1
		--and ObservationDate = '2021-12-15'
		and cast(DateFrom as time) > cast('15:55:00' as time)
		and cast(DateFrom as time) < cast('16:00:00' as time)
		and IndicativePrice = 0
		and exists
		(
			select ASXCode, RankNumber, BuyValue
			from #TempCandidate
			where x.ASXCode = ASXCode
		)

		update a
		set a.DateFrom = b.DateFrom,
			a.OrderPrice = b.Bid
		from #TempCandidate as a
		inner join #Temp1 as b
		on a.ASXCode = b.ASXCode
		where RowNumber = 1

		update a
		set a.PriceChange = case when PrevClose > 0 then ([Close] - PrevClose)*100.0/PrevClose else null end
		from #TempCandidate as a
		inner join StockData.v_PriceSummary_Latest_Today as b
		on a.ASXCode = b.ASXCode
		where RowNumber = 1

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
		  ,[ValidUntil]
		  ,[CreateDate]
		  ,[OrderTriggerDate]
		)
		select top(@pintNumOrder)
		   [ASXCode]
		  ,1 as [UserID]
		  ,'huanw2114' as TradeAccountName
		  ,8 as [OrderTypeID]
		  ,'Price' as [OrderPriceType]
		  ,[OrderPrice] as [OrderPrice]
		  ,0 as [VolumeGt]
		  ,null as [OrderVolume]
		  ,case when cast([BuyValue]/2.0 as int) < 7500 then 7500 else cast([BuyValue]/2.0 as int) end as [OrderValue]
		  ,0 as [OrderPriceBufferNumberOfTick]
		  ,dateadd(day, 30, getdate()) as [ValidUntil]
		  ,getdate() as [CreateDate]
		  ,null as [OrderTriggerDate]
		from #TempCandidate as a
		where OrderPrice is not null
		and BuyValue is not null
		and PriceChange < 10
		and not exists
		(
			select 1
			from [Order].[Order]
			where ASXCode = a.ASXCode
			and OrderTypeID = 8
			and TradeAccountName = 'huanw2114'
			and cast(CreateDate as date) = cast(getdate() as date)
		)
		order by RankNumber


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