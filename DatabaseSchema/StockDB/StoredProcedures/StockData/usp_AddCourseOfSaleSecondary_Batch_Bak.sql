-- Stored procedure: [StockData].[usp_AddCourseOfSaleSecondary_Batch_Bak]






CREATE PROCEDURE [StockData].[usp_AddCourseOfSaleSecondary_Batch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
--@pvchStockCode as varchar(10),
@pvchCourseOfSaleBar as varchar(max)
AS
/******************************************************************************
File: usp_AddCourseOfSaleSecondary_Batch.sql
Stored Procedure Name: usp_AddCourseOfSaleSecondary_Batch
Overview
-----------------
usp_AddCourseOfSaleSecondary_Batch

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
	SET LOCK_TIMEOUT 300000;

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCourseOfSaleSecondary_Batch'
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
		if object_id(N'Tempdb.dbo.#TempCOSSecondaryBar') is not null
			drop table #TempCOSSecondaryBar

		select
			@pvchCourseOfSaleBar as CourseOfSaleBar
		into #TempCOSSecondaryBar

		if object_id(N'Tempdb.dbo.#TempCOS') is not null
			drop table #TempCOS

		create table #TempCOS
		(
			COSID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			SaleDateTime datetime not null,
			Price decimal(20, 4),
			Quantity decimal(20,4),
			Exchange varchar(20),
			SpecialCondition varchar(50),
			ObservationDate date
		)

		insert into #TempCOS
		(
			ASXCode,
			SaleDateTime,
			Price,
			Quantity,
			Exchange,
			SpecialCondition,
			ObservationDate 
		)
		select 
			json_value(b.value, '$.ASXCode') as ASXCode,
			cast(json_value(b.value, '$.SaleDateTime') as datetime) as SaleDateTime,
			cast(json_value(b.value, '$.Price') as decimal(20, 4)) as Price,
			floor(cast(json_value(b.value, '$.Quantity') as decimal(20,4))) as Quantity,
			json_value(b.value, '$.Exchange') as Exchange,
			json_value(b.value, '$.SpecialCondition') as SpecialCondition,
			cast(cast(json_value(b.value, '$.SaleDateTime') as datetime) as date) as ObservationDate
		from #TempCOSSecondaryBar as a
		cross apply openjson(CourseOfSaleBar) as b

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
			from [StockData].[CourseOfSaleSecondaryToday] with(nolock)
			where SaleDateTime = a.SaleDateTime
			and ASXCode = a.ASXCode
			and Price = a.Price
			and Quantity = a.Quantity
			and ExChange = a.ExChange
			and ObservationDate = a.ObservationDate
		)

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
				from StockData.PriceSummaryToday as a with(nolock)
				where ObservationDate = @dtMaxDate
				and exists
				(
					select 1
					from #TempCOS
					where ASXCode = a.ASXCode
				)
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
				from StockData.v_PriceSummary as a with(nolock)
				where ObservationDate = @dtMaxDate
				and exists
				(
					select 1
					from #TempCOS
					where ASXCode = a.ASXCode
				)
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
			--and a.ASXCode = @pvchStockCode
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
			--and a.ASXCode = @pvchStockCode
		end

		if object_id(N'Tempdb.dbo.#TempStockBidAsk') is not null
			drop table #TempStockBidAsk

		select *
		into #TempStockBidAsk
		from [StockData].[v_StockBidAsk] as a
		where ObservationDate = @dtMaxDate
		and exists
		(
			select 1
			from #TempCOS
			where ASXCode = a.ASXCode
		)

		update a
		set a.ActBuySellInd = 
		case when b.PriceBid < b.PrevPriceBid then 'S'
			 when b.PriceAsk > b.PrevPriceAsk then 'B'
			 else case when a.Price <= b.PriceBid then 'S' 
					   when a.Price >= b.PriceAsk then 'B' 
					   else null
				  end
		end
		from #TempCourseOfSaleSecondary as a
		inner join #TempStockBidAsk as b
		on a.SaleDateTime > b.DateFrom and a.SaleDateTime <= b.DateTo
		and a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

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
			left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
			or
			left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('10:02:30' as time)
			or
			left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('10:04:45' as time)
			or
			left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('10:07:00' as time)
			or
			left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('10:09:15' as time)
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
			left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
			or
			left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('10:02:30' as time)
			or
			left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('10:04:45' as time)
			or
			left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('10:07:00' as time)
			or
			left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('10:09:15' as time)
		)
		and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		and a.ObservationDate = @dtObservationDate

		--update a
		--set a.ActBuySellInd = 'S'
		--from #TempCourseOfSaleSecondary as a
		--inner join #TempMarketDepth as b
		--on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		--and b.OrderTypeID = 1
		--and a.Price = b.Price
		--and a.ActBuySellInd is null
		--and b.OrderPosition in (2)
		--and 
		--(
		--	left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
		--	or
		--	left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('10:02:30' as time)
		--	or
		--	left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('10:04:45' as time)
		--	or
		--	left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('10:07:00' as time)
		--	or
		--	left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('10:09:15' as time)
		--)
		--and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		--and a.ObservationDate = @dtObservationDate

		--update a
		--set a.ActBuySellInd = 'B'
		--from #TempCourseOfSaleSecondary as a
		--inner join #TempMarketDepth as b
		--on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		--and b.OrderTypeID = 2
		--and a.Price = b.Price
		--and a.ActBuySellInd is null
		--and b.OrderPosition in (2)
		--and 
		--(
		--	left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
		--	or
		--	left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('10:02:30' as time)
		--	or
		--	left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('10:04:45' as time)
		--	or
		--	left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('10:07:00' as time)
		--	or
		--	left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('10:09:15' as time)
		--)
		--and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		--and a.ObservationDate = @dtObservationDate

		--update a
		--set a.ActBuySellInd = 'S'
		--from #TempCourseOfSaleSecondary as a
		--inner join #TempMarketDepth as b
		--on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		--and b.OrderTypeID = 1
		--and a.Price = b.Price
		--and a.ActBuySellInd is null
		--and b.OrderPosition in (3)
		--and 
		--(
		--	left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
		--	or
		--	left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('10:02:30' as time)
		--	or
		--	left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('10:04:45' as time)
		--	or
		--	left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('10:07:00' as time)
		--	or
		--	left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('10:09:15' as time)
		--)
		--and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		--and a.ObservationDate = @dtObservationDate

		--update a
		--set a.ActBuySellInd = 'B'
		--from #TempCourseOfSaleSecondary as a
		--inner join #TempMarketDepth as b
		--on a.CourseOfSaleSecondaryID = b.CourseOfSaleSecondaryID
		--and b.OrderTypeID = 2
		--and a.Price = b.Price
		--and a.ActBuySellInd is null
		--and b.OrderPosition in (3)
		--and 
		--(
		--	left(a.ASXCode, 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
		--	or
		--	left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(SaleDateTime as time) > cast('10:02:30' as time)
		--	or
		--	left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(SaleDateTime as time) > cast('10:04:45' as time)
		--	or
		--	left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(SaleDateTime as time) > cast('10:07:00' as time)
		--	or
		--	left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(SaleDateTime as time) > cast('10:09:15' as time)
		--)
		--and cast(SaleDateTime as time) < cast('16:00:00' as time)	
		--and a.ObservationDate = @dtObservationDate

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
		
		--if object_id(N'Tempdb.dbo.#TempDeriveInstitute') is not null
		--	drop table #TempDeriveInstitute

		--select ASXCode, SaleDateTime, isnull(ActBuySellInd, 'U') as ActBuySellInd, Price, ExChange, sum(Quantity) as Quantity
		--into #TempDeriveInstitute
		--from #TempCourseOfSaleSecondary as a
		--where 1 = 1
		--and a.ObservationDate = @dtObservationDate
		--group by ASXCode, SaleDateTime, ActBuySellInd, Price, ExChange

		--update a
		--set a.DerivedInstitute = 1
		--from #TempCourseOfSaleSecondary as a
		--inner join
		--(
		--	select
		--		a.ASXCode,
		--		a.SaleDateTime, 
		--		a.ActBuySellInd, 
		--		a.Price, 
		--		sum(a.Quantity) + sum(b.Quantity) as Quantity,
		--		sum(a.Quantity)*a.Price + sum(b.Quantity)*a.Price as TradeValue
		--	from #TempDeriveInstitute as a
		--	inner join #TempDeriveInstitute as b
		--	on a.ExChange = 'CHIXAU'
		--	and b.ExChange = 'ASX'
		--	and a.SaleDateTime = b.SaleDateTime
		--	and a.ActBuySellInd = b.ActBuySellInd
		--	and a.Price = b.Price
		--	group by a.ASXCode, a.SaleDateTime, a.ActBuySellInd, a.Price
		--) as b
		--on a.ASXCode = b.ASXCode
		--and a.SaleDateTime = b.SaleDateTime
		--and a.Price = b.Price
		--and isnull(a.ActBuySellInd, 'U') = isnull(b.ActBuySellInd, 'U')
		--and a.ObservationDate = @dtObservationDate
		--where a.DerivedInstitute is null

		declare @dtMaxObservationDate as date
		select @dtMaxObservationDate = max(ObservationDate)
		from #TempCourseOfSaleSecondary

		--if object_id(N'Tempdb.dbo.#TempStockTickSaleVsBidAsk_All') is not null
		--	drop table #TempStockTickSaleVsBidAsk_All

		--select *
		--into #TempStockTickSaleVsBidAsk_All
		--from StockData.v_StockTickSaleVsBidAsk_All as a
		--where ObservationDate = @dtMaxObservationDate
		--and ASXCode = @pvchStockCode

		--if object_id(N'Tempdb.dbo.#TempStockTickSaleVsBidAsk_All') is not null
		--	DROP TABLE #TempStockTickSaleVsBidAsk_All

		--CREATE TABLE #TempStockTickSaleVsBidAsk_All(
		--	[SaleDateTime] [datetime] NULL,
		--	[ObservationDate] [date] NULL,
		--	[Price] [decimal](20, 4) NULL,
		--	[Quantity] [bigint] NULL,
		--	[SaleValue] [int] NULL,
		--	[FormatedSaleValue] [nvarchar](4000) NULL,
		--	[ASXCode] [varchar](10) NOT NULL,
		--	[Exchange] [varchar](5) NULL,
		--	[SpecialCondition] [int] NULL,
		--	[ActBuySellInd] [int] NULL,
		--	[DerivedBuySellInd] [varchar](1) NULL,
		--	[DerivedInstitute] [bit] NULL,
		--	[PriceBid] [decimal](20, 4) NULL,
		--	[SizeBid] [bigint] NULL,
		--	[PriceAsk] [decimal](20, 4) NULL,
		--	[SizeAsk] [bigint] NULL,
		--	[DateFrom] [datetime] NULL,
		--	[DateTo] [datetime] NULL
		--)

		--declare @dtMaxObservationDate as date = '2023-10-16'
		--declare @@pvchStockCode as varchar(10) = 'PMT.AX'
--		declare @nvchGenericQuery as nvarchar(max)

--		select @nvchGenericQuery = '
--insert into #TempStockTickSaleVsBidAsk_All
--select *
--from StockData.v_StockTickSaleVsBidAsk_All as a
--where ObservationDate = ''' + cast(@dtMaxObservationDate as varchar(50)) + '''
--and ASXCode = ''' + @pvchStockCode + '''
--		'

		--print (@nvchGenericQuery)
		--exec sp_executesql @nvchGenericQuery	
		
		insert into [StockData].[CourseOfSaleSecondaryToday]
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
			from [StockData].[CourseOfSaleSecondaryToday] with(nolock)
			where SaleDateTime = a.SaleDateTime
			and ASXCode = a.ASXCode
			and Price = a.Price
			and Quantity = a.Quantity
			and ExChange = a.ExChange
			and ObservationDate = a.ObservationDate
			and ObservationDate = @dtMaxObservationDate
		)

		--update a
		--set a.DerivedInstitute =
		--case when SizeBid > SizeAsk*1.2 and DerivedBuySellInd = 'S' then 1 
		--	 when SizeAsk > SizeBid*1.2 and DerivedBuySellInd = 'B' then 1 
		--	 when SizeBid*1.2 < SizeAsk and DerivedBuySellInd = 'S' then 0 
		--	 when SizeAsk*1.2 < SizeBid and DerivedBuySellInd = 'B' then 0 
		--	 else null
		--end
		--from [StockData].[CourseOfSaleSecondaryToday] as a
		--inner join #TempStockTickSaleVsBidAsk_All as b
		--on a.ASXCode = b.ASXCode
		--and a.SaleDateTime = b.SaleDateTime
		--and a.Price = b.Price
		----and a.ASXCode = 'LLI.AX'
		----and a.ObservationDate = '2023-09-12'
		--and a.ObservationDate = @dtMaxObservationDate
		--and b.ObservationDate = @dtMaxObservationDate
		--and a.ASXCode = @pvchStockCode
		--and b.ASXCode = @pvchStockCode
		--and exists
		--(
		--	select 1
		--	from #TempCourseOfSaleSecondary
		--	where ASXCode = a.ASXCode
		--	and Price = a.Price
		--	and Quantity = a.Quantity
		--	and ExChange = a.ExChange
		--	and SaleDateTime = a.SaleDateTime
		--	and ObservationDate = a.ObservationDate
		--	and ObservationDate = @dtMaxObservationDate
		--)

		if object_id(N'Tempdb.dbo.#TempCOS') is not null
			drop table #TempCOS

		if object_id(N'Tempdb.dbo.#TempCourseOfSaleSecondary') is not null
			drop table #TempCourseOfSaleSecondary

		if object_id(N'Tempdb.dbo.#TempDistinctPrice') is not null
			drop table #TempDistinctPrice

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		if object_id(N'Tempdb.dbo.#TempCourseOfSale2') is not null
			drop table #TempCourseOfSale2

		if object_id(N'Tempdb.dbo.#TempMarketDepth') is not null
			drop table #TempMarketDepth

		if object_id(N'Tempdb.dbo.#TempPriceSummaryToday') is not null
			drop table #TempPriceSummaryToday

		if object_id(N'Tempdb.dbo.#TempDeriveInstitute') is not null
			drop table #TempDeriveInstitute

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
