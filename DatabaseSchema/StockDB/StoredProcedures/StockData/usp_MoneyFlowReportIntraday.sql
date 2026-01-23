-- Stored procedure: [StockData].[usp_MoneyFlowReportIntraday]



CREATE PROCEDURE [StockData].[usp_MoneyFlowReportIntraday]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@intNumPrevDay int = 0, 
@pvchObservationDate date = '2050-12-12',
@pvchStockCode varchar(20)
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
		--declare @intNumPrevDay int = 0
		--declare @pvchObservationDate date = '2022-02-28'
		--declare @pvchStockCode varchar(20) = 'IGO.AX'

		--declare @dtEnqDate as date = dateadd(day, -1 * @intNumPrevDay, cast(getdate() as date))
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
		from StockData.CourseOfSale with(nolock)
		where ASXCode = @pvchStockCode
		and @dtEnqDate = cast(SaleDateTime as date)
		group by ASXCode, cast(SaleDateTime as date)
		--having sum(case when ActBuySellInd is null then 1 else 0 end)*100.0/count(*) > 25

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *
		into #TempPriceSummary
		from StockData.v_PriceSummary with(nolock)
		where ASXCode = @pvchStockCode
		and ObservationDate = @dtEnqDate

		if object_id(N'Tempdb.dbo.#TempDetail') is not null
			drop table #TempDetail

		select 
		   a.CourseOfSaleSecondaryID as [CourseOfSaleID]
		  ,a.[SaleDateTime]
		  ,a.[Price]
		  ,a.[Quantity]
		  ,cast(a.Quantity/1000.0 as decimal(10, 2)) as QuantityInK
		  ,cast(a.Price*a.Quantity as decimal(20,4)) as SaleValue
		  ,a.[ASXCode]
		  ,a.[CreateDate]
		  ,case when ActBuySellInd = 'S' then 'Sell' 
				when ActBuySellInd = 'B' then 'Buy' 
				else 'Indetermined' 
		   end as BuySellIndicator
		into #TempDetail
		from StockData.CourseOfSaleSecondary as a with(nolock)
		where cast(SaleDateTime as date) = @dtEnqDate
		and a.ASXCode = @pvchStockCode
		and a.ExChange = 'ASX'
		and 1 = 0
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

		--declare @pvchStockCode as varchar(50) = 'PLS.AX'
		--declare @dtEnqDate as date = '2019-11-12'

		if object_id(N'Tempdb.dbo.#TempVWAP') is not null
			drop table #TempVWAP

		select *
		into #TempVWAP
		from 
		(
			select 
				ASXCode,
				DateFrom,
				case when IndicativePrice > 0 then IndicativePrice else VWAP end as VWAP
			from StockData.PriceSummaryToday with(nolock)
			where ASXCode = @pvchStockCode
			--and VolumeDelta > 0
			and ObservationDate = cast(@dtEnqDate as date)
			union
			select 
				ASXCode,
				DateFrom,
				case when IndicativePrice > 0 then IndicativePrice else VWAP end as VWAP
			from StockData.PriceSummary with(nolock)
			where ASXCode = @pvchStockCode
			--and VolumeDelta > 0
			and ObservationDate = cast(@dtEnqDate as date)
		) as a

		--truncate table #TempDetail

		set identity_insert #TempDetail on

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
				case when IndicativePrice > 0 then IndicativePrice else [Close] end as Price,
				isnull(VolumeDelta, 0) as Quantity,
				isnull(VolumeDelta/1000.0, 0) as QuantityInK,
				isnull(ValueDelta, 0) as SaleValue,
				ASXCode,
				DateFrom as CreateDate,
				case when BuySellInd = 'S' then 'Sell' 
						when BuySellInd = 'B' then 'Buy' 
						else 'Indetermined' 
				end as BuySellIndicator
			from StockData.PriceSummaryToday as a with(nolock)
			where ASXCode = @pvchStockCode
			--and VolumeDelta > 0
			and case when IndicativePrice > 0 then IndicativePrice else [Close] end > 0
			and ObservationDate = cast(@dtEnqDate as date)

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
				case when IndicativePrice > 0 then IndicativePrice else [Close] end as Price,
				isnull(VolumeDelta, 0) as Quantity,
				isnull(VolumeDelta/1000.0, 0) as QuantityInK,
				isnull(ValueDelta, 0) as SaleValue,
				ASXCode,
				DateFrom as CreateDate,
				case when BuySellInd = 'S' then 'Sell' 
						when BuySellInd = 'B' then 'Buy' 
						else 'Indetermined' 
				end as BuySellIndicator
			from StockData.PriceSummary as a with(nolock)
			where ASXCode = @pvchStockCode
			--and VolumeDelta > 0
			and case when IndicativePrice > 0 then IndicativePrice else [Close] end > 0
			and ObservationDate =  cast(@dtEnqDate as date)
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

		--declare @dtEnqDate as date = '2022-02-23'
		--declare @pvchStockCode as varchar(10) = 'PLS.AX'

		if object_id(N'Tempdb.dbo.#TempFMIntraDay') is not null
			drop table #TempFMIntraDay

		select 
			identity(int, 1, 1) as UniqueKey,
			z.TimeLabel,
			z.TimeLabel as TimeEnd,
			cast(null as bigint) as AuctionVolume,
			cast(null as decimal(20, 4)) as AuctionValue,
			x.[Sale Quantity] as [Buy Sale Quantity],
			x.[Sale Value] as [Buy Sale Value],
			x.[Num Of Sale] as [Buy Num Of Sale] ,
			x.AverageValuePerTransaction as [Buy AverageValuePerTransaction],
			x.VWAP as [Buy VWAP],
			y.[Sale Quantity] as [Sell Sale Quantity],
			y.[Sale Value] as [Sell Sale Value],
			y.[Num Of Sale] as [Sell Num Of Sale],
			y.AverageValuePerTransaction as [Sell AverageValuePerTransaction],
			y.VWAP as [Sell VWAP],
			row_number() over (order by x.TimeLabel) as RowNumber,
			cast(null as decimal(20, 4)) as ClosePrice,
			z.VWAP as CumulativeVWAP,
			cast(coalesce(x.VWAP, y.VWAP) as decimal(10, 4)) as VWAP
		into #TempFMIntraDay
		from 
		(
			select *
			from 
			(
				select 
					a.TimeLabel as TimeLabel, 
					max(b.VWAP) as VWAP
				from LookupRef.TimePeriod1Min as a
				left join #TempVWAP as b
				on cast(b.DateFrom as smalldatetime) = dateadd(day, datediff(day, TimeStart, @dtEnqDate), TimeStart)
				group by a.TimeLabel
			) as vwap
		) as z
		left join
		(
			select 
				cast(SaleDateTime as smalldatetime) as TimeLabel, 
				cast(SaleDateTime as smalldatetime) as TimeEnd,
				sum(isnull(Quantity, 0)) as [Sale Quantity], 
				sum(isnull(SaleValue, 0)) as [Sale Value],
				sum(isnull(Quantity, 0)) as [Num Of Sale],
				case when sum(Quantity) > 0 then sum(SaleValue)/sum(Quantity) else null end as AverageValuePerTransaction,
				avg(Price) as VWAP
			from #TempDetailPlusRaw as a
			where a.BuySellIndicator in ('Buy', 'Indetermined')
			group by cast(SaleDateTime as smalldatetime)
		) as x
		on right(convert(varchar(50), x.TimeLabel, 120), 8) = z.TimeLabel
		left join
		(
			select 
				cast(SaleDateTime as smalldatetime) as TimeLabel, 
				cast(SaleDateTime as smalldatetime) as TimeEnd,
				sum(isnull(Quantity, 0)) as [Sale Quantity], 
				sum(isnull(SaleValue, 0)) as [Sale Value],
				sum(isnull(Quantity, 0)) as [Num Of Sale],
				case when sum(Quantity) > 0 then sum(SaleValue)/sum(Quantity) else null end as AverageValuePerTransaction,
				avg(Price) as VWAP
			from #TempDetailPlusRaw as a
			where a.BuySellIndicator in ('Sell')
			group by cast(SaleDateTime as smalldatetime)
		) as y
		on right(convert(varchar(50), y.TimeLabel, 120), 8) = z.TimeLabel
		order by z.TimeLabel

		if object_id(N'Tempdb.dbo.#TempPrevClose') is not null
			drop table #TempPrevClose

		select top 1 *
		into #TempPrevClose
		from StockData.PriceHistory with(nolock)
		where ASXCode = @pvchStockCode
		and dateadd(day, -90, @dtEnqDate) < ObservationDate
		and ObservationDate < @dtEnqDate
		order by ObservationDate desc

		update a
		set a.ClosePrice = b.[Close]
		from #TempFMIntraDay as a
		inner join #TempPrevClose as b
		on 1 = 1

		update a
		set a.ClosePrice = b.[Open]
		from #TempFMIntraDay as a
		inner join (
			select avg([Open]) as [Open]
			from #TempPriceSummary
			where [Open] > 0
		) as b
		on 1 = 1
		where a.TimeLabel >= 
		(
			select min(TimeLabel) as TimeLabel
			from #TempFMIntraDay
			where [Buy Sale Quantity] > 0 or [Sell Sale Quantity] > 0
		)

		update x
		set x.VWAP = y.VWAP
		from #TempFMIntraDay as x
		inner join
		(
			select 
				a.TimeLabel, 
				b.TimeLabel as LastTimeLabel,
				b.VWAP,
				row_number() over (partition by a.TimeLabel order by b.RowNumber desc) as RowNumber
			from #TempFMIntraDay as a
			inner join #TempFMIntraDay as b
			on a.TimeLabel > b.TimeLabel
			and a.VWAP = 0
			and b.VWAP > 0
		) as y
		on x.TimeLabel = y.TimeLabel
		and y.RowNumber = 1

		update x
		set x.VWAP = coalesce(nullif([Buy VWAP], 0), [Sell VWAP])
		from #TempFMIntraDay as x
		where nullif(x.VWAP, 0) is null

		update a
		set a.AuctionVolume = b.MatchVolume,
			a.AuctionValue = b.MatchValue
		from #TempFMIntraDay as a
		inner join
		(
			select 
				a.TimeLabel as TimeLabel, 
				max(MatchVolume) as MatchVolume,
				max(MatchVolume)*avg(IndicativePrice) as MatchValue
			from LookupRef.TimePeriod1Min as a
			inner join #TempPriceSummary as b
			on cast(b.DateFrom as smalldatetime) = dateadd(day, datediff(day, TimeStart, @dtEnqDate), TimeStart)
			where MatchVolume > 0
			and IndicativePrice > 0
			and cast(DateFrom as time) < '10:12:00'
			group by a.TimeLabel
		) as b
		on a.TimeLabel = b.TimeLabel

		--update a
		--set a.ClosePrice = 0
		--from #TempFMIntraDay as a
		--where ClosePrice is null

		declare @intIsUpdate as int = 1

		while @intIsUpdate > 0
		begin
			select @intIsUpdate = 0

			update a
			set a.CumulativeVWAP = b.CumulativeVWAP
			from #TempFMIntraDay as a
			inner join #TempFMIntraDay as b
			on a.UniqueKey = b.UniqueKey + 1
			where a.CumulativeVWAP is null
			and b.CumulativeVWAP is not null

			select @intIsUpdate = @intIsUpdate + @@ROWCOUNT

			update a
			set a.VWAP = b.VWAP
			from #TempFMIntraDay as a
			inner join #TempFMIntraDay as b
			on a.UniqueKey = b.UniqueKey + 1
			where nullif(a.VWAP, 0) is null
			and nullif(b.VWAP, 0) is not null

			select @intIsUpdate = @intIsUpdate + @@ROWCOUNT

			update a
			set a.AuctionVolume = b.AuctionVolume
			from #TempFMIntraDay as a
			inner join #TempFMIntraDay as b
			on a.UniqueKey = b.UniqueKey + 1
			where nullif(a.AuctionVolume, 0) is null
			and nullif(b.AuctionVolume, 0) is not null
			and a.TimeLabel < '10:12:00'
			and isnull(a.[Buy Sale Quantity], 0) = 0
			and isnull(a.[Sell Sale Quantity], 0) = 0
			
			select @intIsUpdate = @intIsUpdate + @@ROWCOUNT

			update a
			set a.AuctionValue = b.AuctionValue
			from #TempFMIntraDay as a
			inner join #TempFMIntraDay as b
			on a.UniqueKey = b.UniqueKey + 1
			where nullif(a.AuctionValue, 0) is null
			and nullif(b.AuctionValue, 0) is not null
			and a.TimeLabel < '10:12:00'
			and isnull(a.[Buy Sale Quantity], 0) = 0
			and isnull(a.[Sell Sale Quantity], 0) = 0
			
			select @intIsUpdate = @intIsUpdate + @@ROWCOUNT

		end

		update a
		set a.AuctionValue = 0,
			a.AuctionVolume = 0
		from #TempFMIntraDay as a
		where a.[Buy Sale Quantity] > 0
		or a.[Sell Sale Quantity] > 0

		--if exists
		--(
		--	select 1
		--	from #TempFMIntraDay 
		--	where CumulativeVWAP is not null
		--)
		--begin
		--	delete a
		--	from #TempFMIntraDay as a
		--	where CumulativeVWAP is null
		--end
		--else
		--begin
		--	update a
		--	set CumulativeVWAP = 0
		--	from #TempFMIntraDay as a
		--	where CumulativeVWAP is null
		--end
		
		--if exists
		--(
		--	select 1
		--	from #TempFMIntraDay 
		--	where VWAP is not null
		--)
		--begin
		--	delete a
		--	from #TempFMIntraDay as a
		--	where VWAP is null
		--end
		--else
		--begin
		--	update a
		--	set VWAP = 0
		--	from #TempFMIntraDay as a
		--	where VWAP is null
		--end

		--update a
		--set CumulativeVWAP = 0
		--from #TempFMIntraDay as a
		--where CumulativeVWAP is null

		--update a
		--set VWAP = 0
		--from #TempFMIntraDay as a
		--where VWAP is null

		delete a
		from #TempFMIntraDay as a
		where VWAP is null
		or CumulativeVWAP is null

		delete a
		from #TempFMIntraDay as a
		where CumulativeVWAP = 0

		delete a
		from #TempFMIntraDay as a
		where a.[Buy Sale Value] > 100*(
			select top 1 PERCENTILE_CONT(0.8) 
				WITHIN GROUP (ORDER BY ([Buy Sale Value])) OVER (partition by 1) AS [Buy Sale Value]
			from #TempFMIntraDay 
			where [Buy Sale Value] > 0		
		)
		
		delete a
		from #TempFMIntraDay as a
		where a.[Sell Sale Value] > 100*(
			select top 1 PERCENTILE_CONT(0.8) 
				WITHIN GROUP (ORDER BY ([Sell Sale Value])) OVER (partition by 1) AS [Sell Sale Value]
			from #TempFMIntraDay 
			where [Sell Sale Value] > 0		
		)
		
		select 
			right(convert(varchar(50), a.TimeLabel, 120), 8) as TimeLabel,
			right(convert(varchar(50), a.TimeLabel, 120), 8) as TimeEnd,
			isnull([AuctionVolume], 0) as [AuctionVolume],
			cast(isnull([AuctionValue],0)/1000.0 as decimal(20, 3)) as [AuctionValue],
			isnull([Buy Sale Quantity], 0) as [Buy Sale Quantity],
			cast(isnull([Buy Sale Value],0)/1000.0 as decimal(20, 3)) as [Buy Sale Value],
			isnull([Buy Num Of Sale], 0) as [Buy Num Of Sale],
			isnull([Buy AverageValuePerTransaction], 0) as [Buy AverageValuePerTransaction],
			isnull([Buy VWAP], 0) as [Buy VWAP],
			isnull([Sell Sale Quantity], 0) as [Sell Sale Quantity],
			cast(isnull([Sell Sale Value], 0)/1000.0 as decimal(20, 3)) as [Sell Sale Value],
			isnull([Sell Num Of Sale], 0) as [Sell Num Of Sale],
			isnull([Sell AverageValuePerTransaction], 0) as [Sell AverageValuePerTransaction],
			isnull([Sell VWAP], 0) as [Sell VWAP],
			RowNumber,
			isnull(ClosePrice, VWAP) as ClosePrice,
			CumulativeVWAP,
			VWAP
		from #TempFMIntraDay as a
		order by right(convert(varchar(50), a.TimeLabel, 120), 8)
		
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