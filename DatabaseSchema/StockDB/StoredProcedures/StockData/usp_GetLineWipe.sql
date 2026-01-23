-- Stored procedure: [StockData].[usp_GetLineWipe]






CREATE PROCEDURE [StockData].[usp_GetLineWipe]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@intNumPrevDay int = 0, 
@pvchStockCode varchar(20) = null
AS
/******************************************************************************
File: usp_GetLIneWipe.sql
Stored Procedure Name: usp_GetLineWipe
Overview
-----------------
usp_GetLineWipe

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetLineWipe'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @intNumPrevDay as int = 0
		declare @dtEnqDate as date = dateadd(day, -1 * @intNumPrevDay, cast(getdate() as date))

		--Code goes here 
		--begin transaction
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
			,case when a.ActBuySellInd = 'S' then 'Sell' when a.ActBuySellInd = 'B' then 'Buy' else 'Indetermined' end as BuySellIndicator
		into #TempDetail
		from StockData.CourseOfSale as a
		--left join [StockData].[MarketDepth] as b
		--on a.ASXCode = b.ASXCode
		--and b.OrderTypeID = 1
		--and isnull(b.DateTo, '2050-01-01') > a.SaleDateTime
		--and b.DateFrom < a.SaleDateTime
		--and a.Price = b.Price
		--and cast(a.SaleDateTime as date) = cast(b.DateFrom as date)
		--and (cast(a.SaleDateTime as date) = cast(b.DateTo as date) or b.DateTo is null)
		--left join [StockData].[MarketDepth] as c
		--on a.ASXCode = c.ASXCode
		--and c.OrderTypeID = 2
		--and isnull(c.DateTo, '2050-01-01') > a.SaleDateTime
		--and c.DateFrom < a.SaleDateTime
		--and a.Price = c.Price
		--and cast(a.SaleDateTime as date) = cast(c.DateFrom as date)
		--and (cast(a.SaleDateTime as date) = cast(c.DateTo as date) or c.DateTo is null)
		where cast(SaleDateTime as date) = cast(@dtEnqDate as date)
		and a.Price < 1.00
		order by a.SaleDateTime desc

		if object_id(N'Tempdb.dbo.#TempDetailPlus') is not null
			drop table #TempDetailPlus

		select
			min(a.CourseOfSaleID) as CourseOfSaleID,
			a.SaleDateTime,
			a.Price,
			sum([Quantity]) as [Quantity],
			sum(a.QuantityInK) as QuantityInK,
			sum(a.SaleValue) as SaleValue,
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

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		select 
			a.[CourseOfSaleID]
			,a.[SaleDateTime] as [Sale DateTime]
			,a.[Price]
			,a.[Quantity]
			,QuantityInK as [Quantity '000]
			,SaleValue as [Sale Value]
			,a.[ASXCode]
			,a.[CreateDate] as [Create Date]
			,a.BuySellIndicator as [Buy Sell Indicator]
		into #TempCourseOfSale
		from #TempDetailPlus as a
		order by a.SaleDateTime desc

		declare @pvchASXCode as varchar(10) = @pvchStockCode --'EYM.AX'

		select 
			x.ASXCode,
			x.[Sale DateTime],
			format(x.Quantity, 'N0') as Quantity,
			format(x.[Sale Value], 'N0') as [Sale Value],
			--x.Seller_Position,
			x.Seller_NumberOfOrder as [Number of Orders Wiped],
			format(x.Seller_Volume, 'N0') as [Sale Volume],
			format(x.Seller_Price, 'N5') as [Sale Price] 
		from
		(
			select
				 [ASXCode]
				,[Sale DateTime]
				,CourseOfSaleID
				,Quantity
				,[Sale Value]
				--,Position
				,Seller_Position
				,Seller_NumberOfOrder
				,Seller_Volume
				,Seller_Price
				--,Seller_DateFrom
				--,Seller_DateTo
			from
			(
				select 
					 a.[ASXCode]
					,a.OrderPosition as Position
					,a.[OrderPosition] as Seller_Position
					,a.[NumberOfOrder] as Seller_NumberOfOrder
					,a.[Volume] as Seller_Volume
					,a.[Price] as Seller_Price
					,a.DateFrom as Seller_DateFrom
					,a.DateTo as Seller_DateTo
					,b.[Sale DateTime]
					,b.Quantity
					,b.[Sale Value]
					,b.CourseOfSaleID
					,row_number() over (partition by a.ASXCode, b.[Sale DateTime], a.OrderPosition order by a.DateFrom desc) as RowNumber
				from [StockData].[MarketDepth] as a
				inner join #TempCourseOfSale as b
				on a.ASXCode = b.ASXCode
				where (a.ASXCode = @pvchASXCode or @pvchASXCode is null)
				--where a.ASXCode = 'ADV.AX'
				and OrderTypeID = 2
				and a.OrderPosition = 1
				and DateFrom < dateadd(second, -10, b.[Sale DateTime])
				and cast(b.[Sale DateTime] as date) = cast(DateFrom as date)
				and (cast(b.[Sale DateTime] as date) = cast(DateTo as date) or DateTo is null)
				and b.[Sale Value] > 30000
				and a.NumberOfOrder > 5
				and 
				(
					cast(b.[Sale DateTime] as time) > cast('10:12:00' as time)
					and
					cast(b.[Sale DateTime] as time) < cast('16:00:00' as time)			
				)
			) as c
			where RowNumber = 1
		) as x
		inner join
		(
			select
				 [ASXCode]
				,[Sale DateTime]
				,CourseOfSaleID
				--,Quantity
				--,[Sale Value]
				--,Position
				--,Seller_Position
				,Seller_NumberOfOrder
				,Seller_Volume
				,Seller_Price
				--,Seller_DateFrom
				--,Seller_DateTo
			from
			(
				select 
					 a.[ASXCode]
					,a.OrderPosition as Position
					,a.[OrderPosition] as Seller_Position
					,a.[NumberOfOrder] as Seller_NumberOfOrder
					,a.[Volume] as Seller_Volume
					,a.[Price] as Seller_Price
					,a.DateFrom as Seller_DateFrom
					,a.DateTo as Seller_DateTo
					,b.[Sale DateTime]
					,b.Quantity
					,b.[Sale Value]
					,b.CourseOfSaleID
					,row_number() over (partition by a.ASXCode, b.[Sale DateTime], a.OrderPosition order by a.DateFrom asc) as RowNumber
				from [StockData].[MarketDepth] as a
				inner join #TempCourseOfSale as b
				on a.ASXCode = b.ASXCode
				where OrderTypeID = 2
				and a.OrderPosition = 1
				and DateFrom > dateadd(second, 10, b.[Sale DateTime])
				and cast(b.[Sale DateTime] as date) = cast(DateFrom as date)
				and (cast(b.[Sale DateTime] as date) = cast(DateTo as date) or DateTo is null)
				and b.[Sale Value] > 30000
				--and a.NumberOfOrder > 6
			) as c
			where RowNumber = 1
		) as y
		on x.ASXCode = y.ASXCode
		and x.CourseOfSaleID = y.CourseOfSaleID
		and x.Seller_Price < y.Seller_Price
		order by x.[Sale DateTime] desc

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
