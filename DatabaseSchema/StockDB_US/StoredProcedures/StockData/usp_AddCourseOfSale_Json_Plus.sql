-- Stored procedure: [StockData].[usp_AddCourseOfSale_Json_Plus]






CREATE PROCEDURE [StockData].[usp_AddCourseOfSale_Json_Plus]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchCourseOfSale as varchar(max),
@pvchCountryCode as varchar(10) = 'AX'
AS
/******************************************************************************
File: usp_AddCourseOfSale_Json_Plus.sql
Stored Procedure Name: usp_AddCourseOfSale_Json_Plus
Overview
-----------------
usp_AddCourseOfSale_Json

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
Date:		2020-07-14
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCourseOfSale_Json_Plus'
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
		--declare @pvchCourseOfSale as varchar(max)
		--select @pvchCourseOfSale = RawData
		--from StockData.RawData
		--where RawDataID = 54326

		declare @jsonCourseOfSale as varchar(max)
		select @jsonCourseOfSale = @pvchCourseOfSale

		select @jsonCourseOfSale = [value]
		from openjson(@jsonCourseOfSale)
		where [key] = 'd'

		declare @vchTimeString as varchar(200)
		declare @vchQuote as varchar(max)
		declare @vchCOS as varchar(max)

		select 
			@vchTimeString = PropertiesElement.TimeString
		from openjson(@jsonCourseOfSale)
		with
		(
			Responses nvarchar(max) as json
		) as ResponsesDict
		cross apply openjson(ResponsesDict.Responses)
		with
		(
			Properties nvarchar(max) as json
		) as Properties
		cross apply openjson(Properties.Properties)
		with
		(
			TimeString varchar(200),
			Quote nvarchar(max) as json,
			[COS] nvarchar(max) as json
		) as PropertiesElement
		where len(PropertiesElement.TimeString) > 0

		select 
			@vchQuote = PropertiesElement.Quote
		from openjson(@jsonCourseOfSale)
		with
		(
			Responses nvarchar(max) as json
		) as ResponsesDict
		cross apply openjson(ResponsesDict.Responses)
		with
		(
			Properties nvarchar(max) as json
		) as Properties
		cross apply openjson(Properties.Properties)
		with
		(
			TimeString varchar(200),
			Quote nvarchar(max) as json,
			[COS] nvarchar(max) as json
		) as PropertiesElement
		where len(PropertiesElement.Quote) > 0

		select 
			@vchCOS = PropertiesElement.[COS]
		from openjson(@jsonCourseOfSale)
		with
		(
			Responses nvarchar(max) as json
		) as ResponsesDict
		cross apply openjson(ResponsesDict.Responses)
		with
		(
			Properties nvarchar(max) as json
		) as Properties
		cross apply openjson(Properties.Properties)
		with
		(
			TimeString varchar(200),
			Quote nvarchar(max) as json,
			[COS] nvarchar(max) as json
		) as PropertiesElement
		where len(PropertiesElement.[COS]) > 0

		declare @vchModifiedDateTime as varchar(100) = Convert(varchar(200), cast(getdate() as smalldatetime), 121)

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
			convert(datetime, @vchModifiedDateTime, 121) as SourceSystemDate
		
		declare @vchStockCode as varchar(20)
		
		select @vchStockCode = value
		from openjson(@vchQuote)
		where [key] = 'Code'

		select @vchStockCode = @vchStockCode + '.' + @pvchCountryCode

		if len(@vchStockCode) > 0
		begin
			if object_id(N'Tempdb.dbo.#TempSaleList') is not null
				drop table #TempSaleList

			select 
				try_cast(replace(json_value(b.value, '$.T'), ',', '') as varchar(200)) as [Time],
				try_cast(replace(json_value(b.value, '$.Q'), ',', '') as int) as Quantity,
				try_cast(replace(json_value(b.value, '$.P'), ',', '') as decimal(20, 4)) as price
			into #TempSaleList
			from openjson(@vchCOS) as a
			cross apply openjson(a.value) as b
			where a.[Key] = 'Trades'

			insert into StockData.CourseOfSale
			(
				SaleDateTime,
				Price,
				Quantity,
				ASXCode,
				CreateDate
			)
			select distinct
				cast(cast(cast(convert(datetime, @vchModifiedDateTime, 121) as date) as varchar(50)) + ' ' + [time] as datetime) as SaleDateTime,
				Price,
				Quantity,
				@vchStockCode as ASXCode,
				convert(datetime, @vchModifiedDateTime, 121) as CreateDate	
			from #TempSaleList as a
			where not exists
			(
				select 1
				from StockData.CourseOfSale
				where SaleDateTime = cast(cast(cast(convert(datetime, @vchModifiedDateTime, 121) as date) as varchar(50)) + ' ' + [time] as datetime)
				and Price = a.price
				and quantity = a.quantity
				and ASXCode = @vchStockCode
			)
			and cast(cast(cast(convert(datetime, @vchModifiedDateTime, 121) as date) as varchar(50)) + ' ' + [time] as datetime) <= dateadd(hour, 1, convert(datetime, @vchModifiedDateTime, 121))

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
			and CreateDate = convert(datetime, @vchModifiedDateTime, 121)

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
