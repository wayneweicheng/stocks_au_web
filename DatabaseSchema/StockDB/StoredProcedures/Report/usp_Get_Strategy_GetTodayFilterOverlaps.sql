-- Stored procedure: [Report].[usp_Get_Strategy_GetTodayFilterOverlaps]



CREATE PROCEDURE [Report].[usp_Get_Strategy_GetTodayFilterOverlaps]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0
AS
/******************************************************************************
File: usp_Get_Strategy_GetTodayFilterOverlaps.sql
Stored Procedure Name: usp_Get_Strategy_GetTodayFilterOverlaps
Overview
-----------------
usp_Get_Strategy_GetTodayFilterOverlaps

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
Date:		2020-11-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_GetTodayFilterOverlaps'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		--declare @pintNumPrevDay as int = 8

		select distinct
			'Stock that meets multiple filters' as ReportType,
			b.CustomFilter, 
			a.ASXCode, 
			cast(b.CreateDate as date) as ObservationDate, 
			c.ReportScore,
			ttsu.FriendlyNameList
		from StockData.CustomFilterDetail as a
		inner join StockData.CustomFilter as b
		on a.CustomFilterID = b.CustomFilterID
		inner join 
		(
			select a.ASXCode, sum(c.ReportScore) as ReportScore
			from 
			(
				select distinct CustomFilterID, ASXCode
				from StockData.CustomFilterDetail as a
			) as a
			inner join StockData.CustomFilter as b
			on a.CustomFilterID = b.CustomFilterID
			inner join LookupRef.CustomReport as c
			on b.CustomFilter = c.ReportName
			group by a.ASXCode
			having sum(c.ReportScore) > 20
		) as c
		on a.ASXCode = c.ASXCode
		and 
		(
			b.CustomFilter not like 'Monitor Stock - %'
			and
			b.CustomFilter not like 'Sector - %'
		)
		left join Transform.TTSymbolUser as ttsu
		on a.ASXCode = ttsu.ASXCode
		where 1 = 1
		--and a.ASXCode = 'NAE.AX'
		order by c.ReportScore desc, a.ASXCode;	

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
