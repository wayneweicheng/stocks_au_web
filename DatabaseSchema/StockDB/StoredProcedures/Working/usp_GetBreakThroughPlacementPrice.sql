-- Stored procedure: [Working].[usp_GetBreakThroughPlacementPrice]


create PROCEDURE [Working].[usp_GetBreakThroughPlacementPrice]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetBreakThroughPlacementPrice.sql
Stored Procedure Name: usp_GetBreakThroughPlacementPrice
Overview
-----------------
usp_GetBreakThroughPlacementPrice

Input Parameters
----------------
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
Date:		2018-08-22
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetBreakThroughPlacementPrice'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Working'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pintLookupNumDay as int = 5
		--declare @pvchBrokerCode as varchar(20) = 'pershn'
		--Code goes here 		

		select a.ASXCode, a.ObservationDate, b.PlacementDate, b.OfferPrice, a.[close], c.[Close], a.Volume, c.[Close]*a.Volume as TradeValue, a.MovingAverage5dVol
		from [StockData].[v_StockStatsHistoryPlus] as a
		inner join StockData.v_PlaceHistory_Latest as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate > dateadd(day, 20, b.PlacementDate)
		and a.[Close] > b.OfferPrice
		inner join [StockData].[v_StockStatsHistoryPlus] as c
		on a.ASXCode = c.ASXCode
		and a.DateSeq = c.DateSeq + 1
		and c.[Close] < b.OfferPrice
		and not exists
		(
			select 1
			from [StockData].[v_StockStatsHistoryPlus]
			where ASXCode = a.ASXCode
			and ObservationDate < a.ObservationDate
			and ObservationDate >= dateadd(day, -3, a.ObservationDate)
			and [Close] > b.OfferPrice
		)
		where a.Volume > a.MovingAverage5dVol
		--order by a.ASXCode, a.ObservationDate desc;
		order by a.ObservationDate desc;


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