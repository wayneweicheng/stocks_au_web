-- Stored procedure: [StockData].[usp_AddOptionBidAsk_Batch]



CREATE PROCEDURE [StockData].[usp_AddOptionBidAsk_Batch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchBidAsk varchar(max)
AS
/******************************************************************************
File: usp_AddOptionBidAsk_Batch.sql
Stored Procedure Name: usp_AddOptionBidAsk_Batch
Overview
-----------------
usp_AddOptionBidAsk_Batch

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
Date:		2022-07-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOptionBidAsk_Batch'
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

		if object_id(N'Tempdb.dbo.#TempOptionBidAskJson') is not null
			drop table #TempOptionBidAskJson

		select
			@pvchBidAsk as BidAsk
		into #TempOptionBidAskJson

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

		create table #TempOptionBidAsk
		(
			OptionBidAskID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			Underlying varchar(10) not null,
			OptionSymbol varchar(100) not null,
			ObservationTime datetime,
			PriceBid decimal(20, 4),
			SizeBid bigint,
			PriceAsk decimal(20, 4),
			SizeAsk bigint,
			ObservationDateLocal date
		)

		insert into #TempOptionBidAsk
		(
			ASXCode,
			Underlying,
			OptionSymbol,
			ObservationTime,
			PriceBid,
			SizeBid,
			PriceAsk,
			SizeAsk
		)
		select distinct
			json_value(b.value, '$.underlying') +'.US' as ASXCode,
			json_value(b.value, '$.underlying') as Underlying, 
			json_value(b.value, '$.OptionSymbol') as OptionSymbol,
			left(json_value(b.value, '$.ObservationTime'), 19) as ObservationTime, 
			json_value(b.value, '$.PriceBid') as PriceBid,
			floor(json_value(b.value, '$.SizeBid')) as SizeBid,
			json_value(b.value, '$.PriceAsk') as PriceAsk,
			floor(json_value(b.value, '$.SizeAsk')) as SizeAsk
		--from #TempOptionTradeBar as a
		from #TempOptionBidAskJson as a
		cross apply openjson(BidAsk) as b

		update a
		set ObservationDateLocal = cast(CONVERT(datetime, SWITCHOFFSET(ObservationTime, DATEPART(TZOFFSET, ObservationTime AT TIME ZONE 'Eastern Standard Time'))) as date)
		from #TempOptionBidAsk as a

		declare @dtObservationDateLocal as date 
		select @dtObservationDateLocal = min(ObservationDateLocal)
		from #TempOptionBidAsk

		--if object_id(N'MAWork.dbo.TempOptionBidAsk') is not null
		--	drop table MAWork.dbo.TempOptionBidAsk

		--select *
		--into MAWork.dbo.TempOptionBidAsk
		--from #TempOptionBidAsk

		update a
		set OptionSymbol = replace(OptionSymbol, ' ', '')
		from #TempOptionBidAsk as a

		insert into StockData.OptionBidAsk
		(
		   ASXCode
		  ,Underlying
		  ,OptionSymbol
		  ,ObservationTime
		  ,PriceBid
		  ,SizeBid
		  ,PriceAsk
		  ,SizeAsk
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		  ,ObservationDateLocal
		)
		select
		   ASXCode
		  ,Underlying
		  ,replace(OptionSymbol, ' ', '')
		  ,ObservationTime
		  ,PriceBid
		  ,SizeBid
		  ,PriceAsk
		  ,SizeAsk
		  ,getdate() as [CreateDateTime]
		  ,getdate() as [UpdateDateTime]
		  ,ObservationDateLocal
		from #TempOptionBidAsk as a
		where not exists
		(
			select 1
			from StockData.OptionBidAsk
			where ObservationDateLocal >= @dtObservationDateLocal
			and OptionSymbol = a.OptionSymbol
			and ObservationTime = a.ObservationTime
			and isnull(PriceBid, -1) = isnull(a.PriceBid, -1)
			and isnull(SizeBid, -1) = isnull(a.SizeBid, -1)
			and isnull(PriceAsk, -1) = isnull(a.PriceAsk, -1)
			and isnull(SizeAsk, -1) = isnull(a.SizeAsk, -1)
		)
		
		if object_id(N'Tempdb.dbo.#TempOptionBidAskJson') is not null
			drop table #TempOptionBidAskJson

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

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
