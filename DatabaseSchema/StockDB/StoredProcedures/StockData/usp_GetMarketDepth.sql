-- Stored procedure: [StockData].[usp_GetMarketDepth]






CREATE PROCEDURE [StockData].[usp_GetMarketDepth]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pdtmObservationTime datetime = null,
@pvchStockCode varchar(20) = null,
@pintCourseOfSaleID int = null
AS
/******************************************************************************
File: usp_AddMarketDepth.sql
Stored Procedure Name: usp_AddMarketDepth
Overview
-----------------
usp_AddMarketDepth

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
Date:		2016-05-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMarketDepth'
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
		if (@pvchStockCode is null and @pdtmObservationTime is null and @pintCourseOfSaleID is null)
		begin
			raiserror('Insuffcient parameters are provided.', 16, 0)
		end
		
		if (@pvchStockCode is null and @pdtmObservationTime is null and @pintCourseOfSaleID is not null)
		begin
			select 
				@pvchStockCode = ASXCode,
				@pdtmObservationTime = SaleDateTime
			from StockData.CourseOfSale
			where CourseOfSaleID = @pintCourseOfSaleID
		end

		select 
			x.ASXCode,
			x.Buyer_Position as [Buyer Position],
			x.Buyer_NumberOfOrder as [Buyer NumberOfOrder],
			x.Buyer_Volume as [Buyer Volume],
			x.Buyer_Price as [BuyerPrice],
			x.Buyer_DateFrom as [Buyer DateFrom],
			x.Buyer_DateTo as [Buyer DateTo],
			y.Seller_Position as [Seller Position],
			y.Seller_NumberOfOrder as [Seller NumberOfOrder],
			y.Seller_Volume as [Seller Volume],
			y.Seller_Price as [SellerPrice],
			y.Seller_DateFrom as [Seller DateFrom],
			y.Seller_DateTo as [Seller DateTo]
		from
		(
			select 
			   a.[ASXCode]
			  ,a.OrderPosition as Position
			  ,a.[OrderPosition] as Buyer_Position
			  ,a.[NumberOfOrder] as Buyer_NumberOfOrder
			  ,a.[Volume] as Buyer_Volume
			  ,a.[Price] as Buyer_Price
			  ,a.DateFrom as Buyer_DateFrom
			  ,a.DateTo as Buyer_DateTo
			from [StockData].[MarketDepth] as a
			where ASXCode = @pvchStockCode
			and OrderTypeID = 1
			and isnull(DateTo, '2050-01-01') > dateadd(second, -60, @pdtmObservationTime)
			and DateFrom < dateadd(second, -60, @pdtmObservationTime)
			and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
			and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
		) as x
		left join 
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
			from [StockData].[MarketDepth] as a
			where ASXCode = @pvchStockCode
			and OrderTypeID = 2
			and isnull(DateTo, '2050-01-01') > dateadd(second, -60, @pdtmObservationTime)
			and DateFrom < dateadd(second, -60, @pdtmObservationTime)
			and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
			and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
		) as y
		on x.Position = y.Position
		order by x.Position

		select 
			x.ASXCode,
			x.Buyer_Position as [Buyer Position],
			x.Buyer_NumberOfOrder as [Buyer NumberOfOrder],
			x.Buyer_Volume as [Buyer Volume],
			x.Buyer_Price as [BuyerPrice],
			x.Buyer_DateFrom as [Buyer DateFrom],
			x.Buyer_DateTo as [Buyer DateTo],
			y.Seller_Position as [Seller Position],
			y.Seller_NumberOfOrder as [Seller NumberOfOrder],
			y.Seller_Volume as [Seller Volume],
			y.Seller_Price as [SellerPrice],
			y.Seller_DateFrom as [Seller DateFrom],
			y.Seller_DateTo as [Seller DateTo]
		from
		(
			select 
			   a.[ASXCode]
			  ,a.OrderPosition as Position
			  ,a.[OrderPosition] as Buyer_Position
			  ,a.[NumberOfOrder] as Buyer_NumberOfOrder
			  ,a.[Volume] as Buyer_Volume
			  ,a.[Price] as Buyer_Price
			  ,a.DateFrom as Buyer_DateFrom
			  ,a.DateTo as Buyer_DateTo
			from [StockData].[MarketDepth] as a
			where ASXCode = @pvchStockCode
			and OrderTypeID = 1
			and isnull(DateTo, '2050-01-01') > dateadd(second, -30, @pdtmObservationTime)
			and DateFrom < dateadd(second, -30, @pdtmObservationTime)
			and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
			and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
		) as x
		left join 
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
			from [StockData].[MarketDepth] as a
			where ASXCode = @pvchStockCode
			and OrderTypeID = 2
			and isnull(DateTo, '2050-01-01') > dateadd(second, -30, @pdtmObservationTime)
			and DateFrom < dateadd(second, -30, @pdtmObservationTime)
			and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
			and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
		) as y
		on x.Position = y.Position
		order by x.Position

		select 
			x.ASXCode,
			x.Buyer_Position as [Buyer Position],
			x.Buyer_NumberOfOrder as [Buyer NumberOfOrder],
			x.Buyer_Volume as [Buyer Volume],
			x.Buyer_Price as [BuyerPrice],
			x.Buyer_DateFrom as [Buyer DateFrom],
			x.Buyer_DateTo as [Buyer DateTo],
			y.Seller_Position as [Seller Position],
			y.Seller_NumberOfOrder as [Seller NumberOfOrder],
			y.Seller_Volume as [Seller Volume],
			y.Seller_Price as [SellerPrice],
			y.Seller_DateFrom as [Seller DateFrom],
			y.Seller_DateTo as [Seller DateTo]
		from
		(
			select 
			   a.[ASXCode]
			  ,a.OrderPosition as Position
			  ,a.[OrderPosition] as Buyer_Position
			  ,a.[NumberOfOrder] as Buyer_NumberOfOrder
			  ,a.[Volume] as Buyer_Volume
			  ,a.[Price] as Buyer_Price
			  ,a.DateFrom as Buyer_DateFrom
			  ,a.DateTo as Buyer_DateTo
			from [StockData].[MarketDepth] as a
			where ASXCode = @pvchStockCode
			and OrderTypeID = 1
			and isnull(DateTo, '2050-01-01') > @pdtmObservationTime
			and DateFrom < @pdtmObservationTime
			and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
			and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
		) as x
		left join 
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
			from [StockData].[MarketDepth] as a
			where ASXCode = @pvchStockCode
			and OrderTypeID = 2
			and isnull(DateTo, '2050-01-01') > @pdtmObservationTime
			and DateFrom < @pdtmObservationTime
			and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
			and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
		) as y
		on x.Position = y.Position
		order by x.Position

		select 
			x.ASXCode,
			x.Buyer_Position as [Buyer Position],
			x.Buyer_NumberOfOrder as [Buyer NumberOfOrder],
			x.Buyer_Volume as [Buyer Volume],
			x.Buyer_Price as [BuyerPrice],
			x.Buyer_DateFrom as [Buyer DateFrom],
			x.Buyer_DateTo as [Buyer DateTo],
			y.Seller_Position as [Seller Position],
			y.Seller_NumberOfOrder as [Seller NumberOfOrder],
			y.Seller_Volume as [Seller Volume],
			y.Seller_Price as [SellerPrice],
			y.Seller_DateFrom as [Seller DateFrom],
			y.Seller_DateTo as [Seller DateTo]
		from
		(
			select 
				 [ASXCode]
				,Position
				,Buyer_Position
				,Buyer_NumberOfOrder
				,Buyer_Volume
				,Buyer_Price
				,Buyer_DateFrom
				,Buyer_DateTo
			from
			(
				select 
					a.[ASXCode]
					,a.OrderPosition as Position
					,a.[OrderPosition] as Buyer_Position
					,a.[NumberOfOrder] as Buyer_NumberOfOrder
					,a.[Volume] as Buyer_Volume
					,a.[Price] as Buyer_Price
					,a.DateFrom as Buyer_DateFrom
					,a.DateTo as Buyer_DateTo
					,row_number() over (partition by a.ASXCode, a.OrderPosition order by  a.DateFrom asc) as RowNumber
				from [StockData].[MarketDepth] as a
				where ASXCode = @pvchStockCode
				and OrderTypeID = 1
				and DateFrom > dateadd(second, 10, @pdtmObservationTime)
				and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
				and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
			) as x
			where RowNumber = 1
		) as x
		left join 
		(
			select 
				 [ASXCode]
				,Position
				,Seller_Position
				,Seller_NumberOfOrder
				,Seller_Volume
				,Seller_Price
				,Seller_DateFrom
				,Seller_DateTo
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
					,row_number() over (partition by a.ASXCode, a.OrderPosition order by  a.DateFrom asc) as RowNumber
				from [StockData].[MarketDepth] as a
				where ASXCode = @pvchStockCode
				and OrderTypeID = 2
				and DateFrom > dateadd(second, 10, @pdtmObservationTime)
				and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
				and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
			) as x
			where RowNumber = 1
		) as y
		on x.Position = y.Position
		order by x.Position

		select 
			x.ASXCode,
			x.Buyer_Position as [Buyer Position],
			x.Buyer_NumberOfOrder as [Buyer NumberOfOrder],
			x.Buyer_Volume as [Buyer Volume],
			x.Buyer_Price as [BuyerPrice],
			x.Buyer_DateFrom as [Buyer DateFrom],
			x.Buyer_DateTo as [Buyer DateTo],
			y.Seller_Position as [Seller Position],
			y.Seller_NumberOfOrder as [Seller NumberOfOrder],
			y.Seller_Volume as [Seller Volume],
			y.Seller_Price as [SellerPrice],
			y.Seller_DateFrom as [Seller DateFrom],
			y.Seller_DateTo as [Seller DateTo]
		from
		(
			select 
				 [ASXCode]
				,Position
				,Buyer_Position
				,Buyer_NumberOfOrder
				,Buyer_Volume
				,Buyer_Price
				,Buyer_DateFrom
				,Buyer_DateTo
			from
			(
				select 
					a.[ASXCode]
					,a.OrderPosition as Position
					,a.[OrderPosition] as Buyer_Position
					,a.[NumberOfOrder] as Buyer_NumberOfOrder
					,a.[Volume] as Buyer_Volume
					,a.[Price] as Buyer_Price
					,a.DateFrom as Buyer_DateFrom
					,a.DateTo as Buyer_DateTo
					,row_number() over (partition by a.ASXCode, a.OrderPosition order by  a.DateFrom asc) as RowNumber
				from [StockData].[MarketDepth] as a
				where ASXCode = @pvchStockCode
				and OrderTypeID = 1
				and DateFrom > dateadd(second, 60, @pdtmObservationTime)
				and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
				and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
			) as x
			where RowNumber = 1
		) as x
		left join 
		(
			select 
				 [ASXCode]
				,Position
				,Seller_Position
				,Seller_NumberOfOrder
				,Seller_Volume
				,Seller_Price
				,Seller_DateFrom
				,Seller_DateTo
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
					,row_number() over (partition by a.ASXCode, a.OrderPosition order by  a.DateFrom asc) as RowNumber
				from [StockData].[MarketDepth] as a
				where ASXCode = @pvchStockCode
				and OrderTypeID = 2
				and DateFrom > dateadd(second, 60, @pdtmObservationTime)
				and cast(@pdtmObservationTime as date) = cast(DateFrom as date)
				and (cast(@pdtmObservationTime as date) = cast(DateTo as date) or DateTo is null)
			) as x
			where RowNumber = 1
		) as y
		on x.Position = y.Position
		order by x.Position

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
