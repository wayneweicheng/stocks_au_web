-- Stored procedure: [StockAPI].[usp_AddIBMarketDepthForStock]


CREATE PROCEDURE [StockAPI].[usp_AddIBMarketDepthForStock]
@pvchASXCode as varchar(10),
@pdtCurrentTime as datetime,
@pdecPrice as decimal(20, 4),
@pintVolume as int,
@pintOrderTypeId as smallint,
@pintOrderPosition as smallint,
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddIBMarketDepthForStock.sql
Stored Procedure Name: usp_AddIBMarketDepthForStock
Overview
-----------------
usp_AddIBMarketDepthForStock

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
Date:		2021-06-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddIBMarketDepthForStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
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
		if object_id(N'Tempdb.dbo.#TempStockDataMarketDepth') is not null
			drop table #TempStockDataMarketDepth

		select
		   @pintOrderTypeId as [OrderTypeID]
		  ,@pintOrderPosition as [OrderPosition]
		  ,-1 as [NumberOfOrder]
		  ,@pintVolume as [Volume]
		  ,@pdecPrice as [Price]
		  ,@pvchASXCode as [ASXCode]
		  ,@pdtCurrentTime as [DateFrom]
		  ,null as [DateTo]
		into #TempStockDataMarketDepth

		update a
		set a.DateTo = dateadd(second, 5, @pdtCurrentTime)
		from [StockData].[MarketDepth] as a
		inner join #TempStockDataMarketDepth as c
		on a.OrderPosition = c.OrderPosition
		and a.ASXCode = c.ASXCode
		and a.OrderTypeID = c.OrderTypeID
		left join #TempStockDataMarketDepth as b
		on a.OrderPosition = b.OrderPosition
		--and a.NumberOfOrder = b.NumTraders
		and a.Volume = b.volume
		and a.Price = b.price
		and a.ASXCode = b.ASXCode
		and a.OrderTypeID = b.OrderTypeID
		and b.price > 0 
		and b.Volume > 0
		where a.ASXCode = @pvchASXCode
		and a.DateTo is null
		and b.ASXCode is null
		
		insert into [StockData].[MarketDepth]
		(
		   [OrderTypeID]
		  ,[OrderPosition]
		  ,[NumberOfOrder]
		  ,[Volume]
		  ,[Price]
		  ,[ASXCode]
		  ,[DateFrom]
		  ,[DateTo]
		)
		select
		   OrderTypeID as [OrderTypeID]
		  ,OrderPosition as [OrderPosition]
		  ,-1 as [NumberOfOrder]
		  ,volume as [Volume]
		  ,price as [Price]
		  ,@pvchASXCode as [ASXCode]
		  ,dateadd(second, 5, @pdtCurrentTime) as [DateFrom]
		  ,null as [DateTo]
		from #TempStockDataMarketDepth  as a
		where not exists
		(
			select 1
			from [StockData].[MarketDepth]
			where ASXCode = a.ASXCode
			and OrderPosition = a.OrderPosition
			--and NumberOfOrder = a.NumTraders
			and Volume = a.Volume
			and Price = a.Price
			and OrderTypeID = a.OrderTypeId
			and DateTo is null
		)
		and a.Price > 0
		and a.Volume > 0
		and a.ASXCode = @pvchASXCode;

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

	--	IF @@TRANCOUNT > 0
	--	BEGIN
	--		ROLLBACK TRANSACTION
	--	END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
