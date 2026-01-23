-- Stored procedure: [StockAPI].[usp_UpdateCurrentHoldings]

CREATE PROCEDURE [StockAPI].[usp_UpdateCurrentHoldings]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchCurrentHoldings as varchar(max),
@pvchTradeAccountName as varchar(100),
@pvchSourceSystem varchar(50)
AS
/******************************************************************************
File: usp_UpdateCurrentHoldings.sql
Stored Procedure Name: usp_UpdateCurrentHoldings
Overview
-----------------
usp_UpdateCurrentHoldings

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
Date:		2021-04-11
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_UpdateCurrentHoldings'
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
		if not exists
		(
			select 1
			from LookupRef.TradingAccount
			where TradingPlatform in ('IB', 'CMC')
			and TradeAccountName = @pvchTradeAccountName
		)
		begin
			raiserror('TradeAccountName supplied not valid', 16, 0)
		end

		insert into StockData.RawData
		(
		   [DataTypeID]
		  ,[RawData]
		  ,[CreateDate]
		  ,[SourceSystemDate]
		  ,[WatchListName]
		)
		select
	       135 as [DataTypeID]
		  ,@pvchCurrentHoldings as [RawData]
		  ,getdate() as [CreateDate]
		  ,getdate() as [SourceSystemDate]
		  ,null as [WatchListName]

		--declare @pvchCurrentHoldings as varchar(max)
		--select @pvchCurrentHoldings = RawData
		--from StockData.RawData
		--where RawDataID = 75285

		if object_id(N'Tempdb.dbo.#TempCurrentHoldings') is not null
			drop table #TempCurrentHoldings

		select 
			json_value([holdings], '$.ASXCode') as ASXCode,
			cast(json_value([holdings], '$.HeldPrice') as decimal(20, 2)) as HeldPrice,
			cast(cast(json_value([holdings], '$.HeldVolume') as decimal(10, 2)) as int) as HeldVolume
		into #TempCurrentHoldings
		from
		(
			select [value] as holdings
			from openjson(@pvchCurrentHoldings)
		) as a

		--declare @pvchSourceSystem as varchar(50) = 'IB'
		--declare @pvchTradeAccountName as varchar(100) = 'huanw2114'

		delete a
		from StockData.CurrentHoldings as a
		where SourceSystem = @pvchSourceSystem
		and AccountName = @pvchTradeAccountName
		and not exists
		(
			select 1
			from #TempCurrentHoldings
			where ASXCode = a.ASXCode
		)

		insert into StockData.CurrentHoldings 
		(
			ASXCode,
			HeldPrice,
			HeldVolume,
			CreateDate,
			SourceSystem,
			AccountName
		)
		select
			ASXCode,
			cast(HeldPrice as decimal(20, 2)) as HeldPrice,
			cast(cast(HeldVolume as decimal(10, 2)) as int) as HeldVolume,
			getdate() as CreateDate,
			@pvchSourceSystem as SourceSystem,
			@pvchTradeAccountName as AccountName
		from #TempCurrentHoldings as a
		where not exists
		(
			select 1
			from StockData.CurrentHoldings
			where SourceSystem = @pvchSourceSystem
			and AccountName = @pvchTradeAccountName
			and ASXCode = a.ASXCode
		)

		--select *
		--into Working.TempCurrentHoldings
		--from #TempCurrentHoldings

		update a
		set a.HeldPrice = b.HeldPrice,
			a.HeldVolume = b.HeldVolume
		from StockData.CurrentHoldings as a
		inner join #TempCurrentHoldings as b
		on a.ASXCode = b.ASXCode
		where SourceSystem = @pvchSourceSystem
		and AccountName = @pvchTradeAccountName
		and 
		(
			a.HeldPrice != b.HeldPrice
			or
			a.HeldVolume != b.HeldVolume
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