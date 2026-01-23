-- Stored procedure: [StockData].[usp_GetMostActiveOptionContract_NextTradeTime]



CREATE PROCEDURE [StockData].[usp_GetMostActiveOptionContract_NextTradeTime]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchOptionSymbol as varchar(100),
@pvchObservationDate as varchar(50)
AS
/******************************************************************************
File: usp_GetMostActiveOptionContract_NextTradeTime.sql
Stored Procedure Name: usp_GetMostActiveOptionContract_NextTradeTime
Overview
-----------------
usp_GetMostActiveOptionContract_NextTradeTime

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockData].[usp_GetMostActiveOptionContract_NextTradeTime]
@pvchOptionSymbol = 'SPY230209P00411000',
@pvchObservationDate = '2023-02-08'

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMostActiveOptionContract_NextTradeTime'
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
		select 
			OptionSymbol,
			CONVERT(datetime, SWITCHOFFSET(ObservationTime, DATEPART(TZOFFSET, ObservationTime AT TIME ZONE 'AUS Eastern Standard Time'))) as StartDateTime,
			getdate() as EndDateTime
		into #TempOptionSymbol
		from
		(
			select OptionSymbol, max(SaleTime) as ObservationTime 
			from StockData.OptionTrade with(nolock)
			where OptionSymbol = @pvchOptionSymbol
			and ObservationDateLocal = @pvchObservationDate
			group by OptionSymbol
		) as a

		if exists
		(
			select 1
			from #TempOptionSymbol
		)
		begin
			select * from #TempOptionSymbol
		end
		else
		begin
			select 
				@pvchOptionSymbol as OptionSymbol,
				CONVERT(DATETIME, cast(@pvchObservationDate + ' ' + '10:00:00' as datetime) AT TIME ZONE 'AUS Eastern Standard Time') as StartDateTime,
				getdate() as EndDateTime
		end

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
