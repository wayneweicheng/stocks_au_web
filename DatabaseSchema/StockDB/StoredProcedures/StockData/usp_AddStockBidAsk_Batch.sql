-- Stored procedure: [StockData].[usp_AddStockBidAsk_Batch]




CREATE PROCEDURE [StockData].[usp_AddStockBidAsk_Batch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchBidAsk varchar(max)
AS
/******************************************************************************
File: usp_AddStockBidAsk_Batch.sql
Stored Procedure Name: usp_AddStockBidAsk_Batch
Overview
-----------------
usp_AddStockBidAsk_Batch

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
Date:		2022-07-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddStockBidAsk_Batch'
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
		set dateformat ymd

		--if object_id(N'Working.BidAsk') is not null
		--	drop table Working.BidAsk

		--select @pvchBidAsk as BidAsk
		--into Working.BidAsk

		if object_id(N'Tempdb.dbo.#TempStockBidAskJson') is not null
			drop table #TempStockBidAskJson

		select
			@pvchBidAsk as BidAsk
		into #TempStockBidAskJson

		if object_id(N'Tempdb.dbo.#TempStockBidAsk') is not null
			drop table #TempStockBidAsk

		create table #TempStockBidAsk
		(
			StockBidAskID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			ObservationTime datetime,
			PriceBid decimal(20, 4),
			SizeBid bigint,
			PriceAsk decimal(20, 4),
			SizeAsk bigint
		)

		insert into #TempStockBidAsk
		(
			ASXCode,
			ObservationTime,
			PriceBid,
			SizeBid,
			PriceAsk,
			SizeAsk
		)
		select distinct
			json_value(b.value, '$.ASXCode') as ASXCode,
			left(json_value(b.value, '$.ObservationTime'), 19) as ObservationTime, 
			json_value(b.value, '$.PriceBid') as PriceBid,
			floor(try_cast(json_value(b.value, '$.SizeBid') as decimal(20, 4))) as SizeBid,
			json_value(b.value, '$.PriceAsk') as PriceAsk,
			floor(try_cast(json_value(b.value, '$.SizeAsk') as decimal(20, 4))) as SizeAsk
		--from #TempOptionTradeBar as a
		from #TempStockBidAskJson as a
		cross apply openjson(BidAsk) as b

		insert into StockData.StockBidAsk
		(
		   ASXCode
		  ,ObservationTime
		  ,ObservationDate
		  ,PriceBid
		  ,SizeBid
		  ,PriceAsk
		  ,SizeAsk
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		)
		select
		   ASXCode
		  ,ObservationTime
		  ,cast(ObservationTime as date) as ObservationDate
		  ,PriceBid
		  ,SizeBid
		  ,PriceAsk
		  ,SizeAsk
		  ,getdate() as [CreateDateTime]
		  ,getdate() as [UpdateDateTime]
		from #TempStockBidAsk as a
		where not exists
		(
			select 1
			from StockData.StockBidAsk
			where ASXCode = a.ASXCode
			and isnull(ObservationTime, '2050-12-12') = isnull(a.ObservationTime, '2050-12-12')
			and isnull(PriceBid, -1) = isnull(a.PriceBid, -1)
			and isnull(SizeBid, -1) = isnull(a.SizeBid, -1)
			and isnull(PriceAsk, -1) = isnull(a.PriceAsk, -1)
			and isnull(SizeAsk, -1) = isnull(a.SizeAsk, -1)
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
