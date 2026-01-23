-- Stored procedure: [StockData].[usp_GetCourseOfSale]






CREATE PROCEDURE [StockData].[usp_GetCourseOfSale]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@intNumPrevDay int = 0, 
@pvchObservationDate date = '2050-12-12',
@pvchStockCode varchar(20),
@pbitIsMobile as bit = 0
AS
/******************************************************************************
File: usp_GetCourseOfSale.sql
Stored Procedure Name: usp_GetCourseOfSale
Overview
-----------------
usp_GetCourseOfSale

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
Date:		2016-05-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetCourseOfSale'
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
		--declare @pvchStockCode as varchar(10) = 'MCR.AX'
		--declare @pvchObservationDate as date = '2020-09-16'

		declare @dtEnqDate as date 
		if @pvchObservationDate = '2050-12-12'
		begin
			select @dtEnqDate = dateadd(day, 0, cast(getdate() as date))
		end
		else
		begin
			select @dtEnqDate = cast(@pvchObservationDate as date)	
		end

		if object_id(N'Tempdb.dbo.#TempUnknownCOS') is not null
			drop table #TempUnknownCOS

		select 
			ASXCode, 
			cast(SaleDateTime as date) as ObservationDate, 
			sum(case when ActBuySellInd is null then 1 else 0 end)*100.0/count(*) as UnknownPerc,
			min(SaleDateTime) as MinSaleDateTime,
			max(SaleDateTime) as MaxSaleDateTime,
			count(*) as NumTrade
		into #TempUnknownCOS
		from StockData.CourseOfSale
		where ASXCode = @pvchStockCode
		and @dtEnqDate = cast(SaleDateTime as date)
		group by ASXCode, cast(SaleDateTime as date)
		--having sum(case when ActBuySellInd is null then 1 else 0 end)*100.0/count(*) > 25

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ASXCode = @pvchStockCode
		and ObservationDate = @dtEnqDate

		if object_id(N'Tempdb.dbo.#TempDetail') is not null
			drop table #TempDetail

		select 
		   a.[CourseOfSaleID]
		  ,a.[SaleDateTime]
		  ,a.[Price]
		  ,a.[Quantity]
		  ,cast(a.Quantity/1000.0 as decimal(10, 2)) as QuantityInK
		  ,cast(a.Price*a.Quantity as decimal(10,0)) as SaleValue
		  ,a.[ASXCode]
		  ,a.[CreateDate]
		  ,case when ActBuySellInd = 'S' then 'Sell' 
				when ActBuySellInd = 'B' then 'Buy' 
				else 'Indetermined' 
		   end as BuySellIndicator
		into #TempDetail
		from StockData.CourseOfSale as a
		--left join [StockData].[MarketDepth] as b
		--on a.ASXCode = @pvchStockCode
		--and b.ASXCode = @pvchStockCode
		--and b.OrderTypeID = 1
		--and isnull(b.DateTo, '2050-01-01') > a.SaleDateTime
		--and b.DateFrom < a.SaleDateTime
		--and a.Price = b.Price
		--and cast(a.SaleDateTime as date) = cast(b.DateFrom as date)
		--and (cast(a.SaleDateTime as date) = cast(b.DateTo as date) or b.DateTo is null)
		--left join [StockData].[MarketDepth] as c
		--on a.ASXCode = @pvchStockCode
		--and c.ASXCode = @pvchStockCode
		--and c.OrderTypeID = 2
		--and isnull(c.DateTo, '2050-01-01') > a.SaleDateTime
		--and c.DateFrom < a.SaleDateTime
		--and a.Price = c.Price
		--and cast(a.SaleDateTime as date) = cast(c.DateFrom as date)
		--and (cast(a.SaleDateTime as date) = cast(c.DateTo as date) or c.DateTo is null)
		where cast(SaleDateTime as date) = @dtEnqDate
		and a.ASXCode = @pvchStockCode
		and not exists
		(
			select 1
			from #TempUnknownCOS
			where ASXCode = a.ASXCode
			and UnknownPerc > 25
		)
		and 
		(
			not exists
			(
				select 1
				from #TempUnknownCOS
				where ASXCode = a.ASXCode
				and cast(MinSaleDateTime as time) > cast('10:20:00' as time)
			)
			or
			not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and cast(DateFrom as time) < cast('10:20:00' as time)
			)
		)
		and 
		(
			not exists
			(
				select 1
				from #TempUnknownCOS
				where ASXCode = a.ASXCode
				and cast(MaxSaleDateTime as time) < cast('15:30:00' as time)
			)
			or
			not exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
				and cast(DateFrom as time) > cast('15:30:00' as time)
			)
		)

		order by a.SaleDateTime desc

		set identity_insert #TempDetail on

		insert into #TempDetail
		(
		   [CourseOfSaleID]
		  ,[SaleDateTime]
		  ,[Price]
		  ,[Quantity]
		  ,QuantityInK
		  ,SaleValue
		  ,[ASXCode]
		  ,[CreateDate]
		  ,BuySellIndicator
		)
		select
		   0 as [CourseOfSaleID]
		  ,a.[SaleDateTime]
		  ,a.[Price]
		  ,a.[Quantity]
		  ,cast(a.Quantity/1000.0 as decimal(10, 2)) as QuantityInK
		  ,cast(a.Price*a.Quantity as decimal(10,0)) as SaleValue
		  ,[ASXCode]
		  ,[CreateDate]
		  ,case when ActBuySellInd = 'S' then 'Sell' 
				when ActBuySellInd = 'B' then 'Buy' 
				else 'Indetermined' 
		   end as BuySellIndicator
		from [StockData].[IndicativePrice] as a
		where cast(SaleDateTime as date) = @dtEnqDate
		and a.ASXCode = @pvchStockCode
		order by a.SaleDateTime desc

		if not exists(
			select 1
			from #TempDetail
			where CourseOfSaleID > 0
		)
		begin

			insert into #TempDetail
			(
				[CourseOfSaleID]
				,[SaleDateTime]
				,[Price]
				,[Quantity]
				,QuantityInK
				,SaleValue
				,[ASXCode]
				,[CreateDate]
				,BuySellIndicator
			)
			select
				0 as CourseOfSaleID,
				DateFrom as SaleDateTime,
				[Close] as Price,
				VolumeDelta as Quantity,
				VolumeDelta/1000.0 as QuantityInK,
				ValueDelta as SaleValue,
				ASXCode,
				DateFrom as CreateDate,
				case when BuySellInd = 'S' then 'Sell' 
						when BuySellInd = 'B' then 'Buy' 
						else 'Indetermined' 
				end as BuySellIndicator
			from StockData.PriceSummary as a
			where ASXCode = @pvchStockCode
			and VolumeDelta > 0
			and cast(DateFrom as date) =  cast(@dtEnqDate as date)

			insert into #TempDetail
			(
				[CourseOfSaleID]
				,[SaleDateTime]
				,[Price]
				,[Quantity]
				,QuantityInK
				,SaleValue
				,[ASXCode]
				,[CreateDate]
				,BuySellIndicator
			)
			select
				0 as CourseOfSaleID,
				DateFrom as SaleDateTime,
				[Close] as Price,
				VolumeDelta as Quantity,
				VolumeDelta/1000.0 as QuantityInK,
				ValueDelta as SaleValue,
				ASXCode,
				DateFrom as CreateDate,
				case when BuySellInd = 'S' then 'Sell' 
						when BuySellInd = 'B' then 'Buy' 
						else 'Indetermined' 
				end as BuySellIndicator
			from StockData.PriceSummaryToday as a
			where ASXCode = @pvchStockCode
			and VolumeDelta > 0
			and cast(DateFrom as date) =  cast(@dtEnqDate as date)

		end

		set identity_insert #TempDetail off

		if object_id(N'Tempdb.dbo.#TempDetailPlusRaw') is not null
			drop table #TempDetailPlusRaw

		select
			min(a.CourseOfSaleID) as CourseOfSaleID,
			a.SaleDateTime,
			a.Price,
			sum(a.SaleValue) as RawSaleValue,
			sum([Quantity]) as [Quantity],
			sum(a.QuantityInK) as QuantityInK,
			sum(a.SaleValue) as SaleValue,
			a.ASXCode,
			min([CreateDate]) as [CreateDate],
			a.BuySellIndicator
		into #TempDetailPlusRaw
		from #TempDetail as a
		group by 
			a.SaleDateTime,
			a.Price,
			a.ASXCode,
			a.BuySellIndicator

		select 
			x.[Sale Hour] as [Sale Hour],
			isnull(y.[Buy Sell Indicator], x.[Buy Sell Indicator]) as [Buy Sell Indicator],
			format(isnull(y.[Sale Quantity], x.[Sale Quantity]), 'N0') as [Sale Quantity],
			'$' + cast(format(isnull(y.[Sale Value], x.[Sale Value]), 'N0') as varchar(50)) as [Sale Value],
			format(isnull(y.[Num Of Sale], x.[Num Of Sale]), 'N0') as [Num Of Sale],
			format(isnull(y.AverageValuePerTransaction, x.AverageValuePerTransaction), 'N0') as [Average Value],
			format(isnull(y.VWAP, x.VWAP), 'N5') as VWAP
		from
		(
			select
				16 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				16 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				15 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				15 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				14 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				14 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				13 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				13 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				12 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				12 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				11 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				11 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				10 as [Sale Hour],
				'Sell' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
			union
			select
				10 as [Sale Hour],
				'Buy' as [Buy Sell Indicator],
				0 as [Sale Quantity],
				0 as [Sale Value],
				0 as [Num Of Sale],
				0 as AverageValuePerTransaction,
				0 as VWAP
		) as x
		left join
		(
			select 
				right('0' + cast(datepart(hour, CreateDate) as varchar(10)), 2) as [Sale Hour], 
				BuySellIndicator as [Buy Sell Indicator], 
				sum(Quantity) as [Sale Quantity], 
				sum(SaleValue) as [Sale Value],
				count(Quantity) as [Num Of Sale],
				case when count(Quantity) > 0 then sum(SaleValue)/count(Quantity) else 0 end as AverageValuePerTransaction,
				case when sum(Quantity) > 0 then sum(SaleValue)/sum(Quantity) else 0 end as VWAP				 
			from #TempDetailPlusRaw
			where BuySellIndicator in ('Sell', 'Buy')
			and cast(CreateDate as time) > cast('10:12:00' as time)
			and cast(CreateDate as time) < cast('16:00:00' as time)	
			and SaleValue >= 1000.0
			group by right('0' + cast(datepart(hour, CreateDate) as varchar(10)), 2), BuySellIndicator
		) as y
		on x.[Sale Hour] = y.[Sale Hour]
		and x.[Buy Sell Indicator] = y.[Buy Sell Indicator]
		order by x.[Sale Hour] desc, x.[Buy Sell Indicator]

		if object_id(N'Tempdb.dbo.#TempDetailPlus') is not null
			drop table #TempDetailPlus

		select
			min(a.CourseOfSaleID) as CourseOfSaleID,
			a.SaleDateTime,
			a.Price,
			sum(a.SaleValue) as RawSaleValue,
			format(sum([Quantity]), 'N0') as [Quantity],
			format(sum(a.QuantityInK), 'N0') as QuantityInK,
			format(sum(a.SaleValue), 'N0') as SaleValue,
			a.ASXCode,
			min([CreateDate]) as [CreateDate],
			a.BuySellIndicator
		into #TempDetailPlus
		from #TempDetail as a
		group by 
			a.SaleDateTime,
			a.Price,
			a.ASXCode,
			a.BuySellIndicator

		select 
		   a.[CourseOfSaleID]
		  ,a.[SaleDateTime] as [Sale DateTime]
		  ,a.[Price]
		  ,a.[Quantity]
		  ,QuantityInK as [Quantity '000]
		  ,'$' + cast(SaleValue as varchar(50)) as [Sale Value]
		  ,a.[ASXCode]
		  ,a.[CreateDate] as [Create Date]
		  ,a.BuySellIndicator as [Buy Sell Indicator]
		from #TempDetailPlus as a
		order by a.SaleDateTime desc

		if object_id(N'Tempdb.dbo.#TempDetailPlus2') is not null
			drop table #TempDetailPlus2

		select
			min(a.CourseOfSaleID) as CourseOfSaleID,
			a.SaleDateTime,
			case when sum(Quantity) > 0 then format(sum(a.SaleValue)/sum(Quantity), 'N5') else null end as VWAPPrice,
			sum(a.SaleValue) as RawSaleValue,
			format(sum([Quantity]), 'N0') as [Quantity],
			format(sum(a.QuantityInK), 'N0') as QuantityInK,
			format(sum(a.SaleValue), 'N0') as SaleValue,
			a.ASXCode,
			min([CreateDate]) as [CreateDate],
			a.BuySellIndicator
		into #TempDetailPlus2
		from #TempDetail as a
		group by 
			a.SaleDateTime,
			a.ASXCode,
			a.BuySellIndicator


		if object_id(N'Tempdb.dbo.##Temp') is not null
		drop table ##Temp

		select *
		into ##Temp
		from #TempDetailPlus2

		select 
		   a.[CourseOfSaleID]
		  ,a.[SaleDateTime] as [Sale DateTime]
		  ,a.[VWAPPrice]
		  ,a.[Quantity]
		  ,QuantityInK as [Quantity '000]
		  ,'$' + cast(SaleValue as varchar(50)) as [Sale Value]
		  ,a.[ASXCode]
		  ,a.[CreateDate] as [Create Date]
		  ,a.BuySellIndicator as [Buy Sell Indicator]
		from #TempDetailPlus2 as a
		where 1 = 1
		order by a.RawSaleValue desc

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
