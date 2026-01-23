-- Stored procedure: [StockData].[usp_GetLargeSale]


--exec [StockData].[usp_GetLargetSale]
--@intNumPrevDay = 7



CREATE PROCEDURE [StockData].[usp_GetLargeSale]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@intNumPrevDay int = 0
AS
/******************************************************************************
File: usp_GetLargetSale.sql
Stored Procedure Name: usp_GetLargetSale
Overview
-----------------
usp_GetLargetSale

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetLargetSale'
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
		--declare @intNumPrevDay as int = 2
		declare @dtEnqDate as date = dateadd(day, -1 * @intNumPrevDay, cast(getdate() as date))

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		select *
		into #TempCourseOfSale
		from StockData.v_CourseOfSale as a
		where cast(SaleDateTime as date) = @dtEnqDate
		and datepart(hour, SaleDateTime) < 16
		and 
		(
			datepart(hour, SaleDateTime) > 10 
			or
			(datepart(hour, SaleDateTime) = 10 and datepart(minute, SaleDateTime) > 12)
		)
		and a.Price < 0.90

		if object_id(N'Tempdb.dbo.#TempLargeSale') is not null
			drop table #TempLargeSale
		
		select identity(int, 1, 1) as TimeSlot, a.*, a.Price*a.Quantity as SaleValue, b.AvgSaleValue, case when b.AvgSaleValue > 0 then a.Price*a.Quantity/b.AvgSaleValue else null end as PriceToAvgRatio
		into #TempLargeSale
		from #TempCourseOfSale as a
		inner join StockData.v_LastTenDayAvgSaleValue as b
		on a.ASXCode = b.ASXCode
		and case when b.AvgSaleValue > 0 then a.Price*a.Quantity/b.AvgSaleValue else null end > 0
		where Price*Quantity > 2000
		and ActBuySellInd in ('B', 'S')
		order by SaleDateTime asc

		declare @intCount as int = 1

		while @intCount > 0
		begin
			select @intCount = 0

			update b
			set SaleDateTime = a.SaleDateTime
			from #TempLargeSale as a
			inner join #TempLargeSale as b
			on a.ASXCode = b.ASXCode
			and a.ActBuySellInd = b.ActBuySellInd
			and a.Price = b.Price
			and datediff(second, a.SaleDateTime, b.SaleDateTime) <= 90
			and a.SaleDateTime < b.SaleDateTime

			select @intCount = @@ROWCOUNT
		end

		if object_id(N'Tempdb.dbo.#TempLargeSalePlus') is not null
			drop table #TempLargeSalePlus

		select 
			a.ASXCode, 
			SaleDateTime, 
			Price, 
			ActBuySellInd, 
			format(AvgSaleValue, 'N2') as AvgSaleValue, 
			format(sum(Quantity), 'N0') as Quantity, 
			format(sum(SaleValue), 'N0') as SaleValue, 
			sum(SaleValue)*1.0/AvgSaleValue as PriceToAvgRatio,
			sum(SaleValue)*1.0/(b.MarketCap*1000000.0) as PercOfMC
		into #TempLargeSalePlus
		from #TempLargeSale as a
		left join StockData.StockOverview as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		group by a.ASXCode, SaleDateTime, Price, ActBuySellInd, AvgSaleValue, b.MarketCap
		having 
		(
			sum(SaleValue)*1.0/AvgSaleValue > 7.5 
			or
			sum(SaleValue)*1.0/(b.MarketCap*1000000.0) > 0.005
		)
		and sum(SaleValue) > 15000
		
		select 
			ASXCode, 
			SaleDateTime, 
			Price, 
			ActBuySellInd, 
			AvgSaleValue, 
			Quantity, 
			SaleValue, 
			format(PriceToAvgRatio, 'N2') as PriceToAvgRatio,
			format(PercOfMC*100.0, 'N2') as [Percentage of MC],
			case when a.ActBuySellInd = 'S' then 'Sell' when a.ActBuySellInd = 'B' then 'Buy' else 'Indetermined' end as BuySellIndicator
		from #TempLargeSalePlus as a
		--left join [StockData].[MarketDepth] as b
		--on b.ASXCode = a.ASXCode
		--and b.OrderTypeID = 1
		--and isnull(b.DateTo, '2050-01-01') > a.SaleDateTime
		--and b.DateFrom < a.SaleDateTime
		--and a.Price = b.Price
		--and cast(a.SaleDateTime as date) = cast(b.DateFrom as date)
		--and (cast(a.SaleDateTime as date) = cast(b.DateTo as date) or b.DateTo is null)
		--left join [StockData].[MarketDepth] as c
		--on c.ASXCode = a.ASXCode
		--and c.OrderTypeID = 2
		--and isnull(c.DateTo, '2050-01-01') > a.SaleDateTime
		--and c.DateFrom < a.SaleDateTime
		--and a.Price = c.Price
		--and cast(a.SaleDateTime as date) = cast(c.DateFrom as date)
		--and (cast(a.SaleDateTime as date) = cast(c.DateTo as date) or c.DateTo is null)
		where 1 = 1
		and datepart(hour, SaleDateTime) < 16
		and 
		(
			datepart(hour, SaleDateTime) > 10 
			or
			(datepart(hour, SaleDateTime) = 10 and datepart(minute, SaleDateTime) > 12)
		)
		and a.Price < 0.90
		order by PercOfMC desc, a.PriceToAvgRatio desc	
			
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
