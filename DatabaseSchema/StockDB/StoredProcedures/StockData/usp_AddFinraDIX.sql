-- Stored procedure: [StockData].[usp_AddFinraDIX]



CREATE PROCEDURE [StockData].[usp_AddFinraDIX]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchObservationDate varchar(20),
@pvchSymbol varchar(20),
@pvchShortVolume varchar(20),
@pvchShortExemptVolume varchar(20),
@pvchTotalVolume varchar(20),
@pvchMarket varchar(50)
AS
/******************************************************************************
File: usp_AddFinraDIX.sql
Stored Procedure Name: usp_AddFinraDIX
Overview
-----------------
usp_AddFinraDIX

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
Date:		2022-05-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddFinraDIX'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchObservationDate as varchar(20) = '20220617'
		
		--Code goes here 
		set dateformat ymd

		if object_id(N'Tempdb.dbo.#TempFinraDIX') is not null
			drop table #TempFinraDIX

		select
			cast(substring(@pvchObservationDate, 0, 5) + '-' + substring(@pvchObservationDate, 5, 2) + '-' + substring(@pvchObservationDate, 7, 2) as date) as ObservationDate,
			@pvchSymbol as Symbol,
			cast(replace(@pvchShortVolume, ',', '') as bigint) as ShortVolume,
			cast(replace(@pvchShortExemptVolume, ',', '') as bigint) as ShortExemptVolume,
			cast(replace(@pvchTotalVolume, ',', '') as bigint) as TotalVolume,
			replace(@pvchMarket, char(13), '') as Market
		into #TempFinraDIX

		delete a
		from StockData.FinraDIX as a
		inner join #TempFinraDIX as b
		on a.Symbol = b.Symbol
		and a.ObservationDate = b.ObservationDate
		--and a.ObservationDate > dateadd(day, -5, getdate())

		insert into StockData.FinraDIX
		(
			ObservationDate,
			Symbol,
			ShortVolume,
			ShortExemptVolume,
			TotalVolume,
			Market,
			CreateDate
		)
		select
			ObservationDate,
			Symbol,
			ShortVolume,
			ShortExemptVolume,
			TotalVolume,
			Market,
			getdate() as CreateDate
		from #TempFinraDIX as a
		where not exists
		(
			select 1
			from StockData.FinraDIX
			where ObservationDate = a.ObservationDate
			and Symbol = a.Symbol
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
