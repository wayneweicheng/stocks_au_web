-- Stored procedure: [HC].[usp_GetPosterSummary]

CREATE PROCEDURE [HC].[usp_GetPosterSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintMinNumStock int = 8,
@pvchSortBy as varchar(50) = 'CloseBalance',
@pvchPoster as varchar(200) = null
AS
/******************************************************************************
File: usp_GetPosterSummary.sql
Stored Procedure Name: usp_GetPosterSummary
Overview
-----------------
usp_GetPosterSummary

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
Date:		2018-01-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetPosterSummary'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'HC'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if @pvchSortBy = 'CloseBalance' 
		begin
			select 
			   [Poster]
			  ,[NumStock]
			  ,[OpenBalance]
			  ,[InitialAmountPerStock]
			  ,[CloseBalance]
			  ,[TotalHeldDays]
			  ,[SuccessRate]
			  ,[OverallPerf]			 
			from HC.PosterSummary
			where NumStock >= @pintMinNumStock
			and (Poster = @pvchPoster or @pvchPoster is null)
			order by CloseBalance desc
		end

		if @pvchSortBy = 'OverallPerf' 
		begin
			select 
			   [Poster]
			  ,[NumStock]
			  ,[OpenBalance]
			  ,[InitialAmountPerStock]
			  ,[CloseBalance]
			  ,[TotalHeldDays]
			  ,[SuccessRate]
			  ,[OverallPerf]			 
			from HC.PosterSummary
			where NumStock >= @pintMinNumStock
			and (Poster = @pvchPoster or @pvchPoster is null)
			order by OverallPerf desc
		end

		if @pvchSortBy = 'SuccessRate' 
		begin
			select 
			   [Poster]
			  ,[NumStock]
			  ,[OpenBalance]
			  ,[InitialAmountPerStock]
			  ,[CloseBalance]
			  ,[TotalHeldDays]
			  ,[SuccessRate]
			  ,[OverallPerf]			 
			from HC.PosterSummary
			where NumStock >= @pintMinNumStock
			and (Poster = @pvchPoster or @pvchPoster is null)
			order by SuccessRate desc
		end

		if @pvchSortBy = 'NumStock' 
		begin
			select 
			   [Poster]
			  ,[NumStock]
			  ,[OpenBalance]
			  ,[InitialAmountPerStock]
			  ,[CloseBalance]
			  ,[TotalHeldDays]
			  ,[SuccessRate]
			  ,[OverallPerf]			 
			from HC.PosterSummary
			where NumStock >= @pintMinNumStock
			and (Poster = @pvchPoster or @pvchPoster is null)
			order by NumStock desc
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
