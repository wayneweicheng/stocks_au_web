-- Stored procedure: [StockData].[usp_GetIntraDaySaleFromDetails]






CREATE PROCEDURE [StockData].[usp_GetIntraDaySaleFromDetails]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pdtObservationDate smalldatetime = null, 
--@pdtObservationDate date = '2016-05-19',
@pvchStockCode varchar(20)
AS
/******************************************************************************
File: usp_GetIntraDaySale.sql
Stored Procedure Name: usp_GetIntraDaySale
Overview
-----------------
usp_GetIntraDaySale

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
Date:		2016-08-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetIntraDaySale'
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
		if @pdtObservationDate is null
		begin
			select @pdtObservationDate = getdate()
		end
		
		--declare @pvchStockCode as varchar(20) = 'ADA.AX'
		--declare @pdtObservationDate as date = '2016-08-12'

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
		  ,case when b.Price is not null then 'Sell' when c.Price is not null then 'Buy' else 'Indetermined' end as BuySellIndicator
		into #TempDetail
		from StockData.CourseOfSale as a
		left join [StockData].[MarketDepth] as b
		on a.ASXCode = @pvchStockCode
		and b.ASXCode = @pvchStockCode
		and b.OrderTypeID = 1
		and isnull(b.DateTo, '2050-01-01') > a.SaleDateTime
		and b.DateFrom < a.SaleDateTime
		and a.Price = b.Price
		and cast(a.SaleDateTime as date) = cast(b.DateFrom as date)
		and (cast(a.SaleDateTime as date) = cast(b.DateTo as date) or b.DateTo is null)
		left join [StockData].[MarketDepth] as c
		on a.ASXCode = @pvchStockCode
		and c.ASXCode = @pvchStockCode
		and c.OrderTypeID = 2
		and isnull(c.DateTo, '2050-01-01') > a.SaleDateTime
		and c.DateFrom < a.SaleDateTime
		and a.Price = c.Price
		and cast(a.SaleDateTime as date) = cast(c.DateFrom as date)
		and (cast(a.SaleDateTime as date) = cast(c.DateTo as date) or c.DateTo is null)
		where cast(SaleDateTime as date) = cast(@pdtObservationDate as date)
		and SaleDateTime < @pdtObservationDate
		and a.ASXCode = @pvchStockCode
		order by a.SaleDateTime desc

		declare @bitSaleUpToDate as bit = 0

		if exists(
			select 1
			from [StockData].[MonitorStock]
			where ASXCode = @pvchStockCode
			and datediff(second, [LastUpdateDate], getdate()) < 1800
		) or
		   exists(
		   select 1
		   from StockData.CourseOfSale
		   where ASXCode = @pvchStockCode
		   and SaleDateTime > @pdtObservationDate
		   and cast(SaleDateTime as date) = cast(@pdtObservationDate as date)
		)
			select @bitSaleUpToDate = 1
		else
			select @bitSaleUpToDate = 0

		select 
			x.ASXCode,
			x.MinPrice,
			x.MaxPrice,
			x.Quantity,
			y.Price as OpenPrice,
			z.Price as ClosePrice,
			convert(varchar(30), @pdtObservationDate, 103) as TodayDate
		from
		(
			select 
				ASXCode,
				min(Price) as MinPrice,
				max(Price) as MaxPrice,
				sum(Quantity) as Quantity
			from #TempDetail as a
			group by ASXCode
		) as x
		inner join 
		(
			select
				ASXCode,
				Price,
				row_number() over (partition by ASXCode order by SaleDateTime asc) as RowNumber
			from #TempDetail
		) as y
		on x.ASXCode = y.ASXCode
		and y.RowNumber = 1
		inner join 
		(
			select
				ASXCode,
				Price,
				row_number() over (partition by ASXCode order by SaleDateTime desc) as RowNumber
			from #TempDetail
		) as z
		on x.ASXCode = z.ASXCode
		and z.RowNumber = 1
		where @bitSaleUpToDate = 1

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
