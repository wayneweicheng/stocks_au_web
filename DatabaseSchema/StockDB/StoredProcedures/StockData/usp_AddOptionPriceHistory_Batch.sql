-- Stored procedure: [StockData].[usp_AddOptionPriceHistory_Batch]



create PROCEDURE [StockData].[usp_AddOptionPriceHistory_Batch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTradeBar varchar(max)
AS
/******************************************************************************
File: usp_AddOptionPriceHistory_Batch.sql
Stored Procedure Name: usp_AddOptionPriceHistory_Batch
Overview
-----------------
usp_AddOptionPriceHistory_Batch

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
Date:		2022-07-31
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOptionPriceHistory_Batch'
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

		--if object_id(N'Working.TradeBar') is not null
		--	drop table Working.TradeBar

		--select @pvchTradeBar as TradeBar
		--into Working.TradeBar

		if object_id(N'Tempdb.dbo.#TempOptionTradeBar') is not null
			drop table #TempOptionTradeBar

		select
			@pvchTradeBar as TradeBar
		into #TempOptionTradeBar

		if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
			drop table #TempOptionTrade

		create table #TempOptionTrade
		(
			OptionTradeID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			Underlying varchar(10) not null,
			OptionSymbol varchar(100) not null,
			ObservationDateTime smalldatetime,
			[Open] decimal(20, 4),
			[High] decimal(20, 4),
			[Low] decimal(20, 4),
			[Close] decimal(20, 4),
			Volume bigint,
			Average decimal(20, 4),
			Trades int
		)

		insert into #TempOptionTrade
		(
			ASXCode,
			Underlying,
			OptionSymbol,
			ObservationDateTime,
			[Open],
			[High],
			[Low],
			[Close],
			Volume,
			[Average],
			Trades
		)
		select distinct
			json_value(b.value, '$.underlying') +'.US' as ASXCode,
			json_value(b.value, '$.underlying') as Underlying, 
			json_value(b.value, '$.OptionSymbol') as OptionSymbol,
			json_value(b.value, '$.ObservationDateTime') as ObservationDateTime, 
			json_value(b.value, '$.Open') as [Open],
			json_value(b.value, '$.High') as [High],
			json_value(b.value, '$.Low') as [Low],
			json_value(b.value, '$.Close') as [Close],
			json_value(b.value, '$.Volume') as Volume,
			json_value(b.value, '$.Average') as Average,
			json_value(b.value, '$.Trades') as Trades
		--from #TempOptionTradeBar as a
		from #TempOptionTradeBar as a
		cross apply openjson(TradeBar) as b

		insert into StockData.OptionPriceHistory
		(
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[ObservationDateTime]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[Value]
		  ,[Trades]
		  ,[CreateDate]
		  ,[ModifyDate]
		)
		select
		  [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[ObservationDateTime]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,Average*Volume as [Value]
		  ,[Trades]
		  ,getdate() as [CreateDate]
		  ,getdate() as [ModifyDate]
		from #TempOptionTrade as a
		where not exists
		(
			select 1
			from StockData.OptionPriceHistory
			where ASXCode = a.ASXCode
			and Underlying = a.Underlying
			and OptionSymbol = a.OptionSymbol
			and isnull(ObservationDateTime, '2050-12-12') = isnull(a.ObservationDateTime, '2050-12-12')
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
