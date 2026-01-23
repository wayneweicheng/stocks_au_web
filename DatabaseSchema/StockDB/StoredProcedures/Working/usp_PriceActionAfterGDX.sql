-- Stored procedure: [Working].[usp_PriceActionAfterGDX]


CREATE PROCEDURE [Working].[usp_PriceActionAfterGDX]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchObservationDate as varchar(20)
AS
/******************************************************************************
File: usp_SelectPriceReverse.sql
Stored Procedure Name: usp_SelectPriceReverse
Overview
-----------------
usp_SelectPriceReverse

Input Parameters
----------------2
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_SelectPriceReverse'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Working'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		select top 1000 
			cast((a.[Close] - c.[Close])*100.0/c.[Close] as decimal(10, 2)) as GDXDrop, 
			cast((b.[Close] - d.[Close])*100.0/d.[Close] as decimal(10, 2)) as GoldStockDrop, 
			case when b.[Open] > b.[Close] then 'Open > Close'
				 when b.[Open] = b.[Close] then 'Open > Close'
				 else 'Open < Close'
			end, 
			*
		from StockData.PriceHistory as a
		inner join StockData.PriceHistory as b
		on a.ObservationDate = [Common].[DateAddBusinessDay](-1, b.ObservationDate)
		inner join StockData.PriceHistory as c
		on a.ObservationDate = [Common].[DateAddBusinessDay](1, c.ObservationDate)
		and a.ASXCode = c.ASXCode
		and (a.[Close] - c.[Close])*100.0/c.[Close] < -3.00
		inner join StockData.PriceHistory as d
		on b.ObservationDate = [Common].[DateAddBusinessDay](1, d.ObservationDate)
		and b.ASXCode = d.ASXCode
		where a.ASXCode = 'GDX:US.US'
		and b.ASXCode = 'EVN.AX'

		select top 1000 
			sum(
			case when b.[Open] < d.[Close] then 1
				 when b.[Open] = d.[Close] then 0
				 else 0
			end)*100.0/count(*) as GoldStockDrop,
			sum(
			case when b.[Open] > b.[Close] then 1
				 when b.[Open] = b.[Close] then 0
				 else 0
			end)*100.0/count(*) as [b.Open > b.Close]
		from StockData.PriceHistory as a
		inner join StockData.PriceHistory as b
		on a.ObservationDate = [Common].[DateAddBusinessDay](-1, b.ObservationDate)
		inner join StockData.PriceHistory as c
		on a.ObservationDate = [Common].[DateAddBusinessDay](1, c.ObservationDate)
		and a.ASXCode = c.ASXCode
		and (a.[Close] - c.[Close])*100.0/c.[Close] < -5.00
		inner join StockData.PriceHistory as d
		on b.ObservationDate = [Common].[DateAddBusinessDay](1, d.ObservationDate)
		and b.ASXCode = d.ASXCode
		where a.ASXCode = 'GDX:US.US'
		and b.ASXCode = 'M7T.AX'


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