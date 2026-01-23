-- Stored procedure: [DataMaintenance].[usp_AddToReportResultHistory]





CREATE PROCEDURE [DataMaintenance].[usp_AddToReportResultHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_AddToReportResultHistory.sql
Stored Procedure Name: usp_AddToReportResultHistory
Overview
-----------------
usp_AddToReportResultHistory

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
Date:		2021-05-16
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddToReportResultHistory'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--declare @pintNumPrevDay as int = 3

		if object_id(N'Tempdb.dbo.#TempReportResult') is not null
			drop table #TempReportResult

		create table #TempReportResult
		(
			ASXCode varchar(10) not null,
			DisplayOrder int,
			ObservationDate date,
			ReportProc varchar(200) not null
		)

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_BrokerNewBuy]
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_BrokerBuy]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_GetTodayTradeBuyvsSell]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pvchSortBy = 'BuyvsMC',
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_GetTodayTradeBuyvsSell]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pvchSortBy = 'Match Volume out of Free Float',
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_BreakoutRetrace]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_DirectorSubscribeSPP]
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_LongBullishBar]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_OvercomeBigSell]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_PriceBreakThroughPlacementPrice]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_RetreatToWeeklyMA10]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_TreeShakeMorningMarket]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_VolumeVolatilityContraction]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		insert into #TempReportResult
		exec [Report].[usp_Get_Strategy_AdvancedHBXF]
		@pintNumPrevDay = @pintNumPrevDay,
		@pbitASXCodeOnly = 1

		--insert into #TempReportResult
		--exec [Report].[usp_Get_Strategy_PriceNewHigh]
		--@pintNumPrevDay = @pintNumPrevDay,
		--@pbitASXCodeOnly = 1

		delete a
		from Report.ReportResultHistory as a
		inner join #TempReportResult as b
		on a.ObservationDate = b.ObservationDate
		and a.ReportProc = b.ReportProc

		insert into Report.ReportResultHistory
		(
			ReportProc,
			ASXCode,
			ObservationDate,
			DisplayOrder,
			CreateDate
		)
		select
			ReportProc,
			ASXCode,
			ObservationDate,
			DisplayOrder,
			getdate() as CreateDate
		from #TempReportResult as a

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