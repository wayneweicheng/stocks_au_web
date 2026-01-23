-- Stored procedure: [StockData].[usp_RefreshBuySellIndicator]





CREATE PROCEDURE [StockData].[usp_RefreshBuySellIndicator]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshBuySellIndicator.sql
Stored Procedure Name: usp_RefreshBuySellIndicator
Overview
-----------------
usp_GetAlertTypeID

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
Date:		2016-03-23
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBuySellIndicator'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--update a
		--set ActBuySellInd = null
		--from StockData.CourseOfSale as a
		--where ActBuySellInd is not null

		if object_id(N'Tempdb.dbo.#TempDistinctPrice') is not null
			drop table #TempDistinctPrice

		select 
			ASXCode,
			Price,
			SaleDateTime
		into #TempDistinctPrice
		from StockData.CourseOfSale as a
		where 1 = 1
		group by
			ASXCode,
			Price,
			SaleDateTime

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		select
			a.*,
			row_number() over (partition by ASXCode order by SaleDateTime desc) as RowNumber,
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
		inner join StockData.CourseOfSale as c
		on a.ASXCode = c.ASXCode
		and a.SaleDateTime = c.SaleDateTime
		and a.Price = c.Price
		where a.ActBuySellInd is null
		and 
		(
			cast(a.SaleDateTime as time) < cast('10:12:00' as time)
			or
			cast(a.SaleDateTime as time) > cast('16:00:00' as time)	
		)

		if object_id(N'Tempdb.dbo.#TempMarketDepth') is not null
			drop table #TempMarketDepth

		select a.*, b.CourseOfSaleID, b.Price as SalePrice
		into #TempMarketDepth
		from StockData.MarketDepth as a
		inner join StockData.CourseOfSale as b
		on a.ASXCode = b.ASXCode
		and a.DateFrom <= b.SaleDateTime 
		and isnull(a.DateTo, '2030-01-12') > b.SaleDateTime 
		and b.ActBuySellInd is null
		
		--if object_id(N'Tempdb.dbo.#TempMDInd') is not null
		--	drop table #TempMDInd

		--select
		--	x.CourseOfSaleID,
		--	case when x.BuyVolume > y.SellVolume then 'B'
		--			when x.BuyVolume < y.SellVolume then 'S'
		--			else null
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
		and cast(SaleDateTime as time) > cast('10:12:00' as time)
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
		and cast(SaleDateTime as time) > cast('10:12:00' as time)
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
		and cast(SaleDateTime as time) > cast('10:12:00' as time)
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
		and cast(SaleDateTime as time) > cast('10:12:00' as time)
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
		and cast(SaleDateTime as time) > cast('10:12:00' as time)
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
		and cast(SaleDateTime as time) > cast('10:12:00' as time)
		and cast(SaleDateTime as time) < cast('16:00:00' as time)	

		--select top 100 ActBuySellInd, count(*) from StockData.CourseOfSale
		--where datediff(day, SaleDateTime, getdate()) < 30
		--group by ActBuySellInd

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
