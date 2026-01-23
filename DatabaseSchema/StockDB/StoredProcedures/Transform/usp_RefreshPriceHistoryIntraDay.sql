-- Stored procedure: [Transform].[usp_RefreshPriceHistoryIntraDay]





CREATE PROCEDURE [Transform].[usp_RefreshPriceHistoryIntraDay]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTimeInterval as varchar(20) = '5M'
AS
/******************************************************************************
File: usp_RefreshPriceHistoryIntraDay.sql
Stored Procedure Name: usp_RefreshPriceHistoryIntraDay
Overview
-----------------
usp_RefreshPriceHistoryIntraDay

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
Date:		2019-07-25
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshPriceHistoryIntraDay'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Transform'
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
		--declare @pvchTimeInterval as varchar(10) = '1M'
		
		declare @dtProcessStartDate as date
		select @dtProcessStartDate = isnull(cast(max(TimeIntervalStart) as date), '2020-01-01')
		from [StockData].[PriceHistoryTimeFrame]
		where TimeFrame = @pvchTimeInterval

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary
		
		select *
		into #TempPriceSummary
		from StockData.PriceSummary
		where ObservationDate >= @dtProcessStartDate

		if object_id(N'Tempdb.dbo.#TempDetail') is not null
			drop table #TempDetail

		select 
		   a.[CourseOfSaleID]
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
		   ,cast(null as decimal(20, 4)) as VWAP
		into #TempDetail
		from StockData.CourseOfSale as a
		where 1 = 0

		set identity_insert #TempDetail on

		if not exists(
			select 1
			from #TempDetail
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
			  ,VWAP
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
				end as BuySellIndicator,
			    VWAP
			from StockData.PriceSummaryToday as a
			where ASXCode is not null
			and VolumeDelta > 0
			
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
			  ,VWAP
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
				end as BuySellIndicator,
				VWAP
			from #TempPriceSummary as a
			where ASXCode is not null
			and VolumeDelta > 0

		end

		set identity_insert #TempDetail off

		if object_id(N'Tempdb.dbo.#TempDetailPlusRaw') is not null
			drop table #TempDetailPlusRaw

		select
			min(a.CourseOfSaleID) as CourseOfSaleID,
			cast(a.SaleDateTime as date) as ObservationDate,
			a.SaleDateTime,
			a.Price,
			sum(a.SaleValue) as RawSaleValue,
			sum([Quantity]) as [Quantity],
			sum(a.QuantityInK) as QuantityInK,
			sum(a.SaleValue) as SaleValue,
			a.ASXCode,
			min([CreateDate]) as [CreateDate],
			min(VWAP) as VWAP
		into #TempDetailPlusRaw
		from #TempDetail as a
		group by 
			cast(a.SaleDateTime as date),
			a.SaleDateTime,
			a.Price,
			a.ASXCode

		create index idx_#tempdetailplusraw_saledatetimeasxcodeIncprice on #TempDetailPlusRaw(SaleDateTime, ASXCode)Include(Price)

		if object_id(N'Tempdb.dbo.#TempTimeFrameIntraDay') is not null
			drop table #TempTimeFrameIntraDay

		select 
			a.ASXCode, 
			dateadd(day, datediff(day, TimeStart, ObservationDate), TimeStart) as TimeIntervalStart,
			cast(null as decimal(20, 4)) as [Open],
			max(Price) as [High],
			min(Price) as [Low],
			cast(null as decimal(20, 4)) as [Close],
			isnull(sum(Quantity), 0) as [Volume], 
			min(SaleDateTime) as FirstSale,
			max(SaleDateTime) as LastSale,
			isnull(sum(SaleValue), 0) as [SaleValue],
			isnull(count(Quantity), 0) as [NumOfSale],
			case when count(Quantity) > 0 then sum(SaleValue)/count(Quantity) else null end as AverageValuePerTransaction,
			cast(null as decimal(20, 4)) as VWAP
		into #TempTimeFrameIntraDay
		from LookupRef.v_TimePeriodIntraDay as b		
		--and cast(CreateDate as time) > cast('10:12:00' as time)
		--and cast(CreateDate as time) < cast('16:00:00' as time)	
		--and SaleValue >= 1000.0
		left join #TempDetailPlusRaw as a
		on a.SaleDateTime >= dateadd(day, datediff(day, TimeStart, ObservationDate), TimeStart)
		and a.SaleDateTime < dateadd(day, datediff(day, TimeEnd, ObservationDate), TimeEnd)
		where 1 = 1
		and b.TimeFrame = @pvchTimeInterval
		group by a.ASXCode, dateadd(day, datediff(day, TimeStart, ObservationDate), TimeStart)

		if object_id(N'Tempdb.dbo.#TempVWAPAgg') is not null
			drop table #TempVWAPAgg

		select 
			a.ASXCode, 
			a.VWAP,
			dateadd(day, datediff(day, TimeStart, ObservationDate), TimeStart) as TimeIntervalStart, 
			a.SaleDateTime,
			row_number() over (partition by ASXCode, dateadd(day, datediff(day, TimeStart, ObservationDate), TimeStart) order by SaleDateTime desc) as RowNumber 
		into #TempVWAPAgg
		from #TempDetailPlusRaw as a
		inner join LookupRef.v_TimePeriodIntraDay as b		
		on a.SaleDateTime >= dateadd(day, datediff(day, TimeStart, ObservationDate), TimeStart)
		and a.SaleDateTime < dateadd(day, datediff(day, TimeEnd, ObservationDate), TimeEnd)
		where 1 = 1
		and b.TimeFrame = @pvchTimeInterval

		update a
		set a.VWAP = b.VWAP
		from #TempTimeFrameIntraDay as a
		inner join #TempVWAPAgg as b
		on a.ASXCode = b.ASXCode
		and a.TimeIntervalStart = b.TimeIntervalStart
		and b.RowNumber = 1

		update a
		set a.[Open] = b.Price
		from #TempTimeFrameIntraDay as a
		inner join #TempDetailPlusRaw as b
		on a.ASXCode = b.ASXCode
		and a.FirstSale = b.SaleDateTime

		update a
		set a.[Close] = b.Price
		from #TempTimeFrameIntraDay as a
		inner join #TempDetailPlusRaw as b
		on a.ASXCode = b.ASXCode
		and a.LastSale = b.SaleDateTime

		delete a
		from [StockData].[PriceHistoryTimeFrame] as a
		inner join #TempTimeFrameIntraDay as b
		on a.ObservationDate = cast(b.TimeIntervalStart as date)
		and a.ASXCode = b.ASXCode
		where TimeFrame = @pvchTimeInterval

		insert into [StockData].[PriceHistoryTimeFrame]
		(
		   [ASXCode]
		  ,[TimeFrame]
		  ,[TimeIntervalStart]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Close]
		  ,[Volume]
		  ,[FirstSale]
		  ,[LastSale]
		  ,[SaleValue]
		  ,[NumOfSale]
		  ,[AverageValuePerTransaction]
		  ,[VWAP]
		  ,ObservationDate
		)
		select
		   [ASXCode]
		  ,@pvchTimeInterval as [TimeFrame]
		  ,[TimeIntervalStart]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Close]
		  ,[Volume]
		  ,[FirstSale]
		  ,[LastSale]
		  ,[SaleValue]
		  ,[NumOfSale]
		  ,[AverageValuePerTransaction]
		  ,[VWAP]
		  ,cast(TimeIntervalStart as date) as ObservationDate
		from #TempTimeFrameIntraDay
		where len(ASXCode) > 0
		and TimeIntervalStart is not null

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