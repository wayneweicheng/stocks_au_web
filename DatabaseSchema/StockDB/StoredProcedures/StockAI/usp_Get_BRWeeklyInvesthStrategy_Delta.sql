-- Stored procedure: [StockAI].[usp_Get_BRWeeklyInvesthStrategy_Delta]


CREATE PROCEDURE [StockAI].[usp_Get_BRWeeklyInvesthStrategy_Delta]
@pbitDebug AS BIT = 0,
@pdtObservationDate as date,
@pvchTier as varchar(50) = 'Tier 1',
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_Get_BRWeeklyInvesthStrategy_Delta.sql
Stored Procedure Name: usp_Get_BRWeeklyInvesthStrategy_Delta
Overview
-----------------
exec StockAI.usp_Get_BRWeeklyInvesthStrategy_Delta
@pdtObservationDate = '2025-09-03'

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_refresh_BRWeeklyInvesthStrategy_Delta'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAI'
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

		if object_id(N'Tempdb.dbo.#TempInvest') is not null
			drop table #TempInvest
		select *, [Common].[DateAddBusinessDay_Plus](3, EndDate) as ObservationDate
		into #TempInvest
		from StockDB.StockAI.BRWeeklyInvesthStrategy_Delta
		
		select *
		from
		(
			select a.*, b.TodayChange, b.Next2DaysChange, b.Next5DaysChange, b.Next10DaysChange
			from #TempInvest as a
			left join Transform.PriceHistory24Month as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			--where StartDate = (select max(StartDate) from StockDB.StockAI.BRWeeklyInvesthStrategy_Delta)
			where [Common].[DateAddBusinessDay_Plus](3, EndDate) = @pdtObservationDate
			and Buyer in ('CLSA', 'Taylor Collison', 'Petra Capital', 'Virtu ITG', 'Virtu Financial', 'Vivienne Court')
			and @pvchTier = 'Tier 1'
			union
			select a.*, b.TodayChange, b.Next2DaysChange, b.Next5DaysChange, b.Next10DaysChange
			from #TempInvest as a
			left join Transform.PriceHistory24Month as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			--where StartDate = (select max(StartDate) from StockDB.StockAI.BRWeeklyInvesthStrategy_Delta)
			where [Common].[DateAddBusinessDay_Plus](3, EndDate) = @pdtObservationDate
			and Buyer in ('Wilsons Advisory', 'Jefferies', 'Euroz Hartleys', 'Argonaut Securities', 'State One Stockbroking')
			and @pvchTier = 'Tier 2'
			union
			select a.*, b.TodayChange, b.Next2DaysChange, b.Next5DaysChange, b.Next10DaysChange
			from #TempInvest as a
			left join Transform.PriceHistory24Month as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			--where StartDate = (select max(StartDate) from StockDB.StockAI.BRWeeklyInvesthStrategy_Delta)
			where [Common].[DateAddBusinessDay_Plus](3, EndDate) = @pdtObservationDate
			and Buyer in ('Macquarie Securities', 'Canaccord Genuity', 'Instinet', 'Commonwealth Securities', 'CMC Markets')
			and @pvchTier = 'Tier 3'
		) as x
		where 1 = 1
		--and Buyer in ('Virtu Financial')
		--and Buyer in ('Taylor Collison') --5, 10 days
		--and Buyer in ('Petra Capital') --5, 10 days
		--and Buyer in ('Virtu ITG') --5 days
		--and Buyer in ('CLSA') --5 days
		--and Buyer in ('Vivienne Court') --5, 10 days
		--and Buyer in ('Wilsons Advisory') --10 days
		order by ChangeType, Buyer

		
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