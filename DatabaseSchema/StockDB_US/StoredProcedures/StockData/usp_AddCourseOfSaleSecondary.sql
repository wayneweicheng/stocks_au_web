-- Stored procedure: [StockData].[usp_AddCourseOfSaleSecondary]






CREATE PROCEDURE [StockData].[usp_AddCourseOfSaleSecondary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10),
@pvchCourseOfSale as varchar(max)
AS
/******************************************************************************
File: usp_AddCourseOfSaleSecondary.sql
Stored Procedure Name: usp_AddCourseOfSaleSecondary
Overview
-----------------
usp_AddCourseOfSale

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
Date:		2021-06-25
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCourseOfSaleSecondary'
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
		if @pvchCourseOfSale is not null
		begin
			insert into StockData.RawData
			(
				DataTypeID,
				RawData,
				CreateDate,
				SourceSystemDate
			)
			select
				220 as DataTypeID,
				@pvchCourseOfSale as RawData,
				getdate() as CreateDate,
				null as SourceSystemDate
		end
		
		declare @jsonCourseOfSale as varchar(max)
		select @jsonCourseOfSale = @pvchCourseOfSale
		
		--select @jsonCourseOfSale = RawData
		--from StockData.RawData
		--where DataTypeID = 220
		--and RawDataID = 23306

		--if object_id(N'Tempdb.dbo.#TempCOS') is not null
		--	drop table #TempCOS

		--select 
		--	ASXCode,
		--	SaleDateTime,
		--	Price,
		--	Quantity,
		--	Exchange,
		--	SpecialCondition,
		--	ObservationDate
		--into #TempCOS
		--from Working.CourseOfSaleSecondary as a
		--where ObservationDate = '2021-07-23'
		--and ASXCode = @pvchStockCode

		if object_id(N'Tempdb.dbo.#TempCOS') is not null
			drop table #TempCOS

		select 
			json_value(b.value, '$.ASXCode') as ASXCode,
			cast(json_value(b.value, '$.SaleDateTime') as datetime) as SaleDateTime,
			cast(json_value(b.value, '$.Price') as decimal(20, 4)) as Price,
			cast(json_value(b.value, '$.Quantity') as int) as Quantity,
			json_value(b.value, '$.Exchange') as Exchange,
			json_value(b.value, '$.SpecialCondition') as SpecialCondition,
			cast(cast(json_value(b.value, '$.SaleDateTime') as datetime) as date) as ObservationDate
		into #TempCOS
		from openjson(@jsonCourseOfSale) as a
		cross apply openjson(a.value) as b
		where a.[key] = 'COS'

		--select * 
		--into ##TempCOS
		--from #TempCOS

		if object_id(N'Tempdb.dbo.#TempCourseOfSaleSecondary') is not null
			drop table #TempCourseOfSaleSecondary

		select
			identity(int, 1, 1) as CourseOfSaleSecondaryID,
			[SaleDateTime],
			[Price],
			[Quantity],
			[ASXCode],
			ExChange,
			SpecialCondition,
			getdate() as [CreateDate],
			cast(null as char(1)) as ActBuySellInd,
			cast(null as bit) as DerivedInstitute,
			ObservationDate as ObservationDate
		into #TempCourseOfSaleSecondary
		from 
		(
			select SaleDateTime, Exchange, Price, ASXCode, nullif(Specialcondition, '') as Specialcondition, sum(Quantity) as Quantity, ObservationDate
			from #TempCOS
			group by SaleDateTime, Exchange, Price, ASXCode, nullif(Specialcondition, ''), ObservationDate
		) as a
		where not exists
		(
			select 1
			from [StockData].[CourseOfSaleSecondary] with(nolock)
			where SaleDateTime = a.SaleDateTime
			and ASXCode = a.ASXCode
			and Price = a.Price
			and Quantity = a.Quantity
			and ExChange = a.ExChange
			and ObservationDate = a.ObservationDate
		)

		delete a
		from #TempCourseOfSaleSecondary as a
		inner join
		(
			select CourseOfSaleSecondaryID, row_number() over (partition by ASXCode, Price, Quantity, Exchange, ObservationDate, SaleDateTime order by isnull(SpecialCondition, '000') asc) as RowNumber
			from #TempCourseOfSaleSecondary 
		) as b
		on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		and b.RowNumber > 1

		if object_id(N'Tempdb.dbo.#TempDistinctPrice') is not null
			drop table #TempDistinctPrice

		select 
			ASXCode,
			Price,
			SaleDateTime,
			ObservationDate
		into #TempDistinctPrice
		from #TempCOS as a
		where 1 = 1
		group by
			ASXCode,
			Price,
			SaleDateTime,
			ObservationDate

		declare @dtObservationDate as date
		select top 1 @dtObservationDate = ObservationDate
		from #TempCOS
		
		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		select
			a.*,
			row_number() over (partition by ASXCode order by SaleDateTime desc, Price asc) as RowNumber,
			cast(null as char(1)) as [ActBuySellInd]
		into #TempCourseOfSale
		from #TempDistinctPrice as a

		if object_id(N'Tempdb.dbo.#TempCourseOfSale2') is not null
			drop table #TempCourseOfSale2

		select b.*
		into #TempCourseOfSale2
		from #TempCourseOfSaleSecondary as b with(nolock)
		where b.ObservationDate = @dtObservationDate

		if object_id(N'Tempdb.dbo.#TempMarketDepth') is not null
			drop table #TempMarketDepth

		select a.*, b.CourseOfSaleSecondaryID, b.Price as SalePrice
		into #TempMarketDepth
		from StockData.MarketDepth as a with(nolock)
		inner join #TempCourseOfSale2 as b
		on a.ASXCode = b.ASXCode
		and a.DateFrom <= b.SaleDateTime 
		and isnull(a.DateTo, '2030-01-12') > b.SaleDateTime 
		and cast(a.DateFrom as date) = cast(b.SaleDateTime as date)

		if not exists(
			select 1
			from #TempMarketDepth
		)
		begin
			declare @dtMaxDate as date
			select @dtMaxDate = cast(max(SaleDateTime) as date) from #TempCOS

			if object_id(N'Tempdb.dbo.#TempPriceSummaryToday') is not null
				drop table #TempPriceSummaryToday

			create table #TempPriceSummaryToday
			(
			    [ASXCode] [varchar](10) NOT NULL,
				[Bid] [decimal](20, 4) NULL,
				[Offer] [decimal](20, 4) NULL,
				[Open] [decimal](20, 4) NULL,
				[High] [decimal](20, 4) NULL,
				[Low] [decimal](20, 4) NULL,
				[Close] [decimal](20, 4) NULL,
				[Volume] [bigint] NULL,
				[Value] [decimal](20, 4) NULL,
				[Trades] [int] NULL,
				[VWAP] [decimal](20, 4) NULL,
				[DateFrom] [datetime] NOT NULL,
				[DateTo] [datetime] NULL,
				[LastVerifiedDate] [smalldatetime] NULL,
				[bids] [decimal](20, 4) NULL,
				[bidsTotalVolume] [bigint] NULL,
				[offers] [decimal](20, 4) NULL,
				[offersTotalVolume] [bigint] NULL,
				[IndicativePrice] [decimal](20, 4) NULL,
				[SurplusVolume] [bigint] NULL,
				[PrevClose] [decimal](20, 4) NULL,
				[SysLastSaleDate] [datetime] NULL,
				[SysCreateDate] [datetime] NULL,
				[Prev1PriceSummaryID] [int] NULL,
				[Prev1Bid] [decimal](20, 4) NULL,
				[Prev1Offer] [decimal](20, 4) NULL,
				[Prev1Volume] [bigint] NULL,
				[Prev1Value] [decimal](20, 4) NULL,
				[VolumeDelta] [int] NULL,
				[ValueDelta] [decimal](20, 4) NULL,
				[TimeIntervalInSec] [int] NULL,
				[BuySellInd] [char](1) NULL,
				[Prev1Close] [decimal](20, 4) NULL,
				[LatestForTheDay] [bit] NULL,
				[ObservationDate] [date] NULL,
				[MatchVolume] [int] NULL,
			)

			declare @dtTodayDate as date 
			select @dtTodayDate = cast(getdate() as date)
		
			if @dtMaxDate = @dtTodayDate 
			begin
				insert into #TempPriceSummaryToday
				(
					 [ASXCode]
					,[Bid]
					,[Offer]
					,[Open]
					,[High]
					,[Low]
					,[Close]
					,[Volume]
					,[Value]
					,[Trades]
					,[VWAP]
					,[DateFrom]
					,[DateTo]
					,[LastVerifiedDate]
					,[bids]
					,[bidsTotalVolume]
					,[offers]
					,[offersTotalVolume]
					,[IndicativePrice]
					,[SurplusVolume]
					,[PrevClose]
					,[SysLastSaleDate]
					,[SysCreateDate]
					,[Prev1PriceSummaryID]
					,[Prev1Bid]
					,[Prev1Offer]
					,[Prev1Volume]
					,[Prev1Value]
					,[VolumeDelta]
					,[ValueDelta]
					,[TimeIntervalInSec]
					,[BuySellInd]
					,[Prev1Close]
					,[LatestForTheDay]
					,[ObservationDate]
					,[MatchVolume]
				)
				select 
					 [ASXCode]
					,[Bid]
					,[Offer]
					,[Open]
					,[High]
					,[Low]
					,[Close]
					,[Volume]
					,[Value]
					,[Trades]
					,[VWAP]
					,[DateFrom]
					,[DateTo]
					,[LastVerifiedDate]
					,[bids]
					,[bidsTotalVolume]
					,[offers]
					,[offersTotalVolume]
					,[IndicativePrice]
					,[SurplusVolume]
					,[PrevClose]
					,[SysLastSaleDate]
					,[SysCreateDate]
					,[Prev1PriceSummaryID]
					,[Prev1Bid]
					,[Prev1Offer]
					,[Prev1Volume]
					,[Prev1Value]
					,[VolumeDelta]
					,[ValueDelta]
					,[TimeIntervalInSec]
					,[BuySellInd]
					,[Prev1Close]
					,[LatestForTheDay]
					,[ObservationDate]
					,[MatchVolume]
				from StockData.PriceSummaryToday with(nolock)
				where ASXCode = @pvchStockCode
				and ObservationDate = @dtMaxDate
			end
			else
			begin
				insert into #TempPriceSummaryToday
				(
					 [ASXCode]
					,[Bid]
					,[Offer]
					,[Open]
					,[High]
					,[Low]
					,[Close]
					,[Volume]
					,[Value]
					,[Trades]
					,[VWAP]
					,[DateFrom]
					,[DateTo]
					,[LastVerifiedDate]
					,[bids]
					,[bidsTotalVolume]
					,[offers]
					,[offersTotalVolume]
					,[IndicativePrice]
					,[SurplusVolume]
					,[PrevClose]
					,[SysLastSaleDate]
					,[SysCreateDate]
					,[Prev1PriceSummaryID]
					,[Prev1Bid]
					,[Prev1Offer]
					,[Prev1Volume]
					,[Prev1Value]
					,[VolumeDelta]
					,[ValueDelta]
					,[TimeIntervalInSec]
					,[BuySellInd]
					,[Prev1Close]
					,[LatestForTheDay]
					,[ObservationDate]
					,[MatchVolume]
				)
				select 
					 [ASXCode]
					,[Bid]
					,[Offer]
					,[Open]
					,[High]
					,[Low]
					,[Close]
					,[Volume]
					,[Value]
					,[Trades]
					,[VWAP]
					,[DateFrom]
					,[DateTo]
					,[LastVerifiedDate]
					,[bids]
					,[bidsTotalVolume]
					,[offers]
					,[offersTotalVolume]
					,[IndicativePrice]
					,[SurplusVolume]
					,[PrevClose]
					,[SysLastSaleDate]
					,[SysCreateDate]
					,[Prev1PriceSummaryID]
					,[Prev1Bid]
					,[Prev1Offer]
					,[Prev1Volume]
					,[Prev1Value]
					,[VolumeDelta]
					,[ValueDelta]
					,[TimeIntervalInSec]
					,[BuySellInd]
					,[Prev1Close]
					,[LatestForTheDay]
					,[ObservationDate]
					,[MatchVolume]				
				from StockData.v_PriceSummary with(nolock)
				where ASXCode = @pvchStockCode
				and ObservationDate = @dtMaxDate
			end

			insert into #TempMarketDepth
			(
				MarketDepthID,
				OrderTypeID,
				OrderPosition,
				NumberOfOrder,
				Volume, 
				Price,
				ASXCode,
				DateFrom,
				DateTo,
				CourseOfSaleSecondaryID,
				SalePrice
			)
			select
				-1 as MarketDepthID,
				1 as OrderTypeID,
				1 as OrderPosition,
				-1 as NumberOfOrder,
				-1 as Volume, 
				Bid as Price,
				a.ASXCode,
				a.DateFrom,
				a.DateTo,
				b.CourseOfSaleSecondaryID,
				b.Price as SalePrice
			from #TempPriceSummaryToday as a with(nolock)
			inner join #TempCourseOfSale2 as b
			on a.ASXCode = b.ASXCode
			and a.DateFrom <= b.SaleDateTime 
			and isnull(a.DateTo, '2030-01-12') > b.SaleDateTime 
			and cast(a.DateFrom as date) = cast(b.SaleDateTime as date)
			and a.ASXCode = @pvchStockCode
			union all
			select
				-1 as MarketDepthID,
				2 as OrderTypeID,
				1 as OrderPosition,
				-1 as NumberOfOrder,
				-1 as Volume, 
				Offer as Price,
				a.ASXCode,
				a.DateFrom,
				a.DateTo,
				b.CourseOfSaleSecondaryID,
				b.Price as SalePrice
			from #TempPriceSummaryToday as a with(nolock)
			inner join #TempCourseOfSale2 as b
			on a.ASXCode = b.ASXCode
			and a.DateFrom <= b.SaleDateTime 
			and isnull(a.DateTo, '2030-01-12') > b.SaleDateTime 
			and cast(a.DateFrom as date) = cast(b.SaleDateTime as date)
			and a.ASXCode = @pvchStockCode
		end

		update a
		set a.ActBuySellInd = 'S'
		from #TempCourseOfSaleSecondary as a
		inner join #TempMarketDepth as b
		on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		and b.OrderTypeID = 1
		and a.Price <= b.Price
		and a.ActBuySellInd is null
		and b.OrderPosition in (1)
		and 
		(
			left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('09:30:00' as time)
		)
		and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		and a.ObservationDate = @dtObservationDate

		update a
		set a.ActBuySellInd = 'B'
		from #TempCourseOfSaleSecondary as a
		inner join #TempMarketDepth as b
		on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		and b.OrderTypeID = 2
		and a.Price >= b.Price
		and a.ActBuySellInd is null
		and b.OrderPosition in (1)
		and 
		(
			left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('09:30:00' as time)
			or
			left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('09:30:00' as time)
		)
		and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		and a.ObservationDate = @dtObservationDate

		update c
		set ActBuySellInd = case when a.Price > b.Price then 'B' 
									when a.Price < b.Price then 'S'	
									else null
							end
		from #TempCourseOfSale as a
		inner join #TempCourseOfSale as b
		on a.ASXCode = b.ASXCode
		and a.RowNumber + 1 = b.RowNumber
		and a.SaleDateTime != b.SaleDateTime
		inner join #TempCourseOfSaleSecondary as c with(nolock)
		on a.ASXCode = c.ASXCode
		and a.SaleDateTime = c.SaleDateTime
		and a.Price = c.Price
		and c.ObservationDate = @dtObservationDate
		and a.ObservationDate = @dtObservationDate
		and b.ObservationDate = @dtObservationDate
		where 1 = 1
		and c.ActBuySellInd is null
		
		insert into [StockData].[CourseOfSaleSecondary]
		(
			[SaleDateTime],
			[Price],
			[Quantity],
			[ASXCode],
			ExChange,
			SpecialCondition,
			[CreateDate],
			ActBuySellInd,
			DerivedInstitute,
			ObservationDate
		)
		select
			[SaleDateTime],
			[Price],
			[Quantity],
			[ASXCode],
			ExChange,
			SpecialCondition,
			[CreateDate],
			ActBuySellInd,
			DerivedInstitute,
			ObservationDate
		from #TempCourseOfSaleSecondary as a
		where not exists
		(
			select 1
			from [StockData].[CourseOfSaleSecondary] with(nolock)
			where SaleDateTime = a.SaleDateTime
			and ASXCode = a.ASXCode
			and Price = a.Price
			and Quantity = a.Quantity
			and ExChange = a.ExChange
			and ObservationDate = a.ObservationDate
		)

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
