-- Stored procedure: [StockData].[usp_IfAlreadyProcessedBrokerReportForStock]



CREATE PROCEDURE [StockData].[usp_IfAlreadyProcessedBrokerReportForStock]
@pbitDebug AS BIT = 0,
@pdtObservationDate as date,
@pvchASXCode varchar(10),
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_IfAlreadyProcessedBrokerReportForStock.sql
Stored Procedure Name: usp_IfAlreadyProcessedBrokerReportForStock
Overview
-----------------
usp_IfAlreadyProcessedBrokerReportForStock

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockData].[usp_IfAlreadyProcessedBrokerReportForStock]
@pdtObservationDate = '2023-09-22',
@pbitBackSeriesMode = 1,
@pbitGetAllStocks = 1

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_IfAlreadyProcessedBrokerReportForStock'
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
		--declare @pdtObservationDate as date = '2024-12-27'
		--declare @pvchASXCode as varchar(10) = 'EMR.AX'

		select distinct x.ASXCode, x.ObservationDate as ObservationDate
		from StockData.BrokerReport as x
		inner join
		(
			select ASXCode, ObservationDate, sum(BuyVolume) + -1*sum(SellVolume) as NetVolume
			from StockData.BrokerReport
			group by ASXCode, ObservationDate
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		where x.ObservationDate = @pdtObservationDate
		and x.ASXCode = @pvchASXCode
		and y.NetVolume = 0
		
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
