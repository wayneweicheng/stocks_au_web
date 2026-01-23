-- Stored procedure: [StockData].[usp_AddCourseOfSale]






CREATE PROCEDURE [StockData].[usp_AddCourseOfSale]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchCourseOfSale as varchar(max),
@pvchDateTime as varchar(100),
@pdecBid decimal(20, 4) = null,
@pdecOffer decimal(20, 4) = null,
@pdecOpen decimal(20, 4) = null,
@pdecHigh decimal(20, 4) = null,
@pdecLow decimal(20, 4) = null,
@pdecClose decimal(20, 4) = null,
@pintVolume bigint = null,
@pdecValue decimal(20, 4) = null,
@pintTrades int = null,
@pdecVWAP decimal(20, 4) = null,
@pvchIsEOD as varchar(1) = null
AS
/******************************************************************************
File: usp_AddCourseOfSale.sql
Stored Procedure Name: usp_AddCourseOfSale
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCourseOfSale'
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

		if isnull(@pvchIsEOD, 'N') != 'Y'
			select @pvchIsEOD = 'N'

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
			20 as DataTypeID,
			@pvchCourseOfSale as RawData,
			getdate() as CreateDate,
			convert(datetime, @vchModifiedDateTime, 113) as SourceSystemDate
		
		declare @vchStockCode as varchar(20)
		declare @xmlCourseOfSale as xml
		--select @xmlMarketDepth = cast(RawData as xml) from StockData.RawData
		--where RawDataID = 9
		select @xmlCourseOfSale = cast(@pvchCourseOfSale as xml)

		select @vchStockCode = @xmlCourseOfSale.value('(/CourseOfSale/stockCode)[1]', 'varchar(20)')

		if object_id(N'Tempdb.dbo.#TempSaleList') is not null
			drop table #TempSaleList

		select 
			x.si.value('time[1]', 'varchar(100)') as [time],
			x.si.value('price[1]', 'varchar(100)') as price,
			x.si.value('quantity[1]', 'varchar(100)') as quantity
		into #TempSaleList
		from @xmlCourseOfSale.nodes('/CourseOfSale/saleList/SaleItem') as x(si)
		
		declare @intCourseOfSaleID as int

		if @pvchIsEOD = 'N'
		begin

			insert into StockData.CourseOfSale
			(
				SaleDateTime,
				Price,
				Quantity,
				ASXCode,
				CreateDate
			)
			select
				cast(cast(cast(convert(datetime, @vchModifiedDateTime, 113) as date) as varchar(50)) + ' ' + [time] as datetime) as SaleDateTime,
				Price,
				Quantity,
				@vchStockCode as ASXCode,
				convert(datetime, @vchModifiedDateTime, 113) as CreateDate	
			from #TempSaleList as a
			where not exists
			(
				select 1
				from StockData.CourseOfSale
				where SaleDateTime = cast(cast(cast(convert(datetime, @vchModifiedDateTime, 113) as date) as varchar(50)) + ' ' + [time] as datetime)
				and Price = a.price
				and quantity = a.quantity
				and ASXCode = @vchStockCode
			)
			and cast(cast(cast(convert(datetime, @vchModifiedDateTime, 113) as date) as varchar(50)) + ' ' + [time] as datetime) <= dateadd(hour, 1, convert(datetime, @vchModifiedDateTime, 113))

		end

		--if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
		--	drop table #TempPriceSummary

		--select
		--	@vchStockCode as ASXCode,
		--	@pdecBid as Bid,
		--	@pdecOffer as Offer,
		--	@pdecOpen as [Open],
		--	@pdecHigh as High,
		--	@pdecLow as Low,
		--	@pdecClose as [Close],
		--	@pintVolume as Volume,
		--	@pdecValue as Value,
		--	@pintTrades as Trades,
		--	@pdecVWAP as VWAP,
		--	convert(datetime, @vchModifiedDateTime, 113) as CreateDate
		--into #TempPriceSummary

		--update a
		--set a.DateTo = b.CreateDate
		--from StockData.PriceSummary as a
		--inner join #TempPriceSummary as b
		--on a.ASXCode = b.ASXCode
		--and cast(a.DateFrom as date) = cast(b.CreateDate as date)
		--left join #TempPriceSummary as c
		--on a.ASXCode = c.ASXCode
		--and cast(a.DateFrom as date) = cast(c.CreateDate as date)
		--and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		--and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		--and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		--and isnull(a.[High], -1) = isnull(c.[High], -1)
		--and isnull(a.Low, -1) = isnull(c.Low, -1)
		--and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		--and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		--and isnull(a.Value, -1) = isnull(c.Value, -1)
		--and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--where a.DateTo is null
		--and c.ASXCode is null

		--update a
		--set a.LastVerifiedDate = c.CreateDate
		--from StockData.PriceSummary as a
		--inner join #TempPriceSummary as c
		--on a.ASXCode = c.ASXCode
		--and cast(a.DateFrom as date) = cast(c.CreateDate as date)
		--and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		--and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		--and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		--and isnull(a.[High], -1) = isnull(c.[High], -1)
		--and isnull(a.Low, -1) = isnull(c.Low, -1)
		--and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		--and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		--and isnull(a.Value, -1) = isnull(c.Value, -1)
		--and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--where a.DateTo is null
		--and isnull(a.LastVerifiedDate, '2050-01-12') != c.CreateDate

		--insert into StockData.PriceSummary
		--(
		--	[ASXCode]
		--	,[Bid]
		--	,[Offer]
		--	,[Open]
		--	,[High]
		--	,[Low]
		--	,[Close]
		--	,[Volume]
		--	,[Value]
		--	,[Trades]
		--	,[VWAP]
		--	,[DateFrom]
		--	,[DateTo]
		--	,LastVerifiedDate
		--)
		--select
		--	[ASXCode]
		--	,[Bid]
		--	,[Offer]
		--	,[Open]
		--	,[High]
		--	,[Low]
		--	,[Close]
		--	,[Volume]
		--	,[Value]
		--	,[Trades]
		--	,[VWAP]
		--	,CreateDate as [DateFrom]
		--	,null as [DateTo]
		--	,CreateDate as LastVerifiedDate
		--from #TempPriceSummary as a
		--where not exists
		--(
		--	select 1
		--	from StockData.PriceSummary as c
		--	where a.ASXCode = c.ASXCode
		--	and cast(a.CreateDate as date) = cast(c.DateFrom as date)
		--	and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		--	and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		--	and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		--	and isnull(a.[High], -1) = isnull(c.[High], -1)
		--	and isnull(a.Low, -1) = isnull(c.Low, -1)
		--	and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		--	and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		--	and isnull(a.Value, -1) = isnull(c.Value, -1)
		--	and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--	and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--	and c.DateTo is null
		--)

		if @pvchIsEOD = 'N'
		begin

			update a
			set a.LastCourseOfSaleDate = b.SaleDateTime
			from StockData.MonitorStock as a
			inner join
			(
				select a.ASXCode, max(SaleDateTime) as SaleDateTime
				from StockData.CourseOfSale as a
				where a.ASXCode = @vchStockCode
				group by a.ASXCode
			) as b
			on a.ASXCode = b.ASXCode
			and a.ASXCode = @vchStockCode
			and isnull(a.LastCourseOfSaleDate, '1910-01-12') != b.SaleDateTime

			--UPDATE BUYSELLINDICATOR
			--declare @pvchDateTime as varchar(100) = '30 Jan 12:25:30 PM'

			--declare @vchModifiedDateTime as varchar(100) = left(@pvchDateTime, 7) + cast(year(getdate()) as varchar(4)) + ' ' + parsename(replace(@pvchDateTime, ' ', '.'), 2) + ' ' + parsename(replace(@pvchDateTime, ' ', '.'), 1)

			--declare @vchModifiedDateTime as varchar(100) = '30/01/2017 12:25:30'
			--select convert(datetime, @vchModifiedDateTime, 113)

			--select * from StockData.CourseOfSale
			--where ASXCode = 'KDR.AX'
			--order by 1 desc

			--declare @vchStockCode as varchar(50) = 'KDR.AX'
		
			declare @decSaleTime as datetime
			select @decSaleTime = max(SaleDateTime)
			from StockData.CourseOfSale
			where ASXCode = @vchStockCode

			if object_id(N'Tempdb.dbo.#TempDistinctPrice') is not null
				drop table #TempDistinctPrice

			select 
				ASXCode,
				Price,
				SaleDateTime
			into #TempDistinctPrice
			from StockData.CourseOfSale as a
			where ASXCode = @vchStockCode
			and dateadd(day, 5, SaleDateTime) > @decSaleTime
			group by
				ASXCode,
				Price,
				SaleDateTime

			if object_id(N'Tempdb.dbo.#TempAddedCOS') is not null
				drop table #TempAddedCOS

			select CourseOfSaleID
			into #TempAddedCOS
			from StockData.CourseOfSale as a
			where ASXCode = @vchStockCode
			and CreateDate = convert(datetime, @vchModifiedDateTime, 113)

			if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
				drop table #TempCourseOfSale

			select
				a.*,
				row_number() over (partition by ASXCode order by SaleDateTime desc, Price asc) as RowNumber,
				cast(null as char(1)) as [ActBuySellInd]
			into #TempCourseOfSale
			from #TempDistinctPrice as a

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
			inner join StockData.CourseOfSale as c
			on a.ASXCode = c.ASXCode
			and a.SaleDateTime = c.SaleDateTime
			and a.Price = c.Price
			inner join #TempAddedCOS as d
			on c.CourseOfSaleID = d.CourseOfSaleID
			where 1 = 1
			and c.ActBuySellInd is null
			and 
			(
				--cast(a.SaleDateTime as time) < cast('10:12:00' as time)
				(
					left(a.ASXCode, 1) in ('A', 'B') and cast(a.SaleDateTime as time) <= cast('10:00:15' as time)
					or
					left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(a.SaleDateTime as time) <= cast('10:02:30' as time)
					or
					left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(a.SaleDateTime as time) <= cast('10:04:45' as time)
					or
					left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(a.SaleDateTime as time) <= cast('10:07:00' as time)
					or
					left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(a.SaleDateTime as time) <= cast('10:09:15' as time)
				)
				or
				cast(a.SaleDateTime as time) > cast('16:00:00' as time)	
			)

			if object_id(N'Tempdb.dbo.#TempCourseOfSale2') is not null
				drop table #TempCourseOfSale2

			select b.*
			into #TempCourseOfSale2
			from StockData.CourseOfSale as b
			inner join #TempAddedCOS as d
			on b.CourseOfSaleID = d.CourseOfSaleID

			if object_id(N'Tempdb.dbo.#TempMarketDepth') is not null
				drop table #TempMarketDepth

			select a.*, b.CourseOfSaleID, b.Price as SalePrice
			into #TempMarketDepth
			from StockData.MarketDepth as a
			inner join #TempCourseOfSale2 as b
			on a.ASXCode = b.ASXCode
			and a.DateFrom <= b.SaleDateTime 
			and isnull(a.DateTo, '2030-01-12') > b.SaleDateTime 

			--if object_id(N'Tempdb.dbo.#TempMDInd') is not null
			--	drop table #TempMDInd

			--select
			--	x.CourseOfSaleID,
			--	case when x.BuyVolume > y.SellVolume then 'B'
			--		 when x.BuyVolume < y.SellVolume then 'S'
			--		 else null
			--	end as ActBuySellInd
			--into #TempMDInd
			--from
			--(
			--	select CourseOfSaleID, sum(Volume) as BuyVolume
			--	from #TempMarketDepth as a
			--	where OrderTypeID = 1
			--	and Price >= SalePrice
			--	group by CourseOfSaleID
			--) as x
			--inner join
			--(
			--	select CourseOfSaleID, sum(Volume) as SellVolume
			--	from #TempMarketDepth as a
			--	where OrderTypeID = 2
			--	and Price <= SalePrice
			--	group by CourseOfSaleID
			--) as y
			--on x.CourseOfSaleID = y.CourseOfSaleID

			--update a
			--set a.ActBuySellInd = b.ActBuySellInd
			--from StockData.CourseOfSale as a
			--inner join #TempMDInd as b
			--on a.CourseOfSaleID = b.CourseOfSaleID
			--and a.ActBuySellInd is null

			update a
			set a.ActBuySellInd = 'S'
			from StockData.CourseOfSale as a
			inner join #TempMarketDepth as b
			on a.CourseOfSaleID = b.CourseOfSaleID
			and b.OrderTypeID = 1
			and a.Price = b.Price
			and a.ActBuySellInd is null
			and b.OrderPosition in (1)
			and 
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
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

			update a
			set a.ActBuySellInd = 'B'
			from StockData.CourseOfSale as a
			inner join #TempMarketDepth as b
			on a.CourseOfSaleID = b.CourseOfSaleID
			and b.OrderTypeID = 2
			and a.Price = b.Price
			and a.ActBuySellInd is null
			and b.OrderPosition in (1)
			and 
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
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

			update a
			set a.ActBuySellInd = 'S'
			from StockData.CourseOfSale as a
			inner join #TempMarketDepth as b
			on a.CourseOfSaleID = b.CourseOfSaleID
			and b.OrderTypeID = 1
			and a.Price = b.Price
			and a.ActBuySellInd is null
			and b.OrderPosition in (2)
			and 
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
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

			update a
			set a.ActBuySellInd = 'B'
			from StockData.CourseOfSale as a
			inner join #TempMarketDepth as b
			on a.CourseOfSaleID = b.CourseOfSaleID
			and b.OrderTypeID = 2
			and a.Price = b.Price
			and a.ActBuySellInd is null
			and b.OrderPosition in (2)
			and 
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
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

			update a
			set a.ActBuySellInd = 'S'
			from StockData.CourseOfSale as a
			inner join #TempMarketDepth as b
			on a.CourseOfSaleID = b.CourseOfSaleID
			and b.OrderTypeID = 1
			and a.Price = b.Price
			and a.ActBuySellInd is null
			and b.OrderPosition in (3)
			and 
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
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

			update a
			set a.ActBuySellInd = 'B'
			from StockData.CourseOfSale as a
			inner join #TempMarketDepth as b
			on a.CourseOfSaleID = b.CourseOfSaleID
			and b.OrderTypeID = 2
			and a.Price = b.Price
			and a.ActBuySellInd is null
			and b.OrderPosition in (3)
			and 
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(SaleDateTime as time) > cast('10:00:15' as time)
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
