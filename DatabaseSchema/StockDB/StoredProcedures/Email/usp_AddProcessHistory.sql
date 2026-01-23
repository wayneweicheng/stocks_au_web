-- Stored procedure: [Email].[usp_AddProcessHistory]


CREATE PROCEDURE [Email].[usp_AddProcessHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchAppName varchar(200),
@pvchEmailSubject varchar(500),
@pvchEmailFrom varchar(200),
@pvchEmailTo varchar(200),
@pvchEmailBody varchar(max),
@pdtEmailDate datetime,
@pvchSuggestedStocks varchar(max)
AS
/******************************************************************************
File: usp_AddProcessHistory.sql
Stored Procedure Name: usp_AddProcessHistory
Overview
-----------------
usp_AddProcessHistory

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
Date:		2021-07-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddProcessHistory'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Email'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		insert into Email.ProcessHistory
		(
		   [AppName]
		  ,[EmailSubject]
		  ,[EmailFrom]
		  ,[EmailTo]
		  ,[EmailBody]
		  ,[EmailDate]
		  ,[CreateDate]
		  ,SuggestedStocks
		)
		select
		   @pvchAppName as [AppName]
		  ,@pvchEmailSubject as [EmailSubject]
		  ,@pvchEmailFrom as [EmailFrom]
		  ,@pvchEmailTo as [EmailTo]
		  ,@pvchEmailBody as [EmailBody]
		  ,@pdtEmailDate as [EmailDate]
		  ,getdate() as [CreateDate]
		  ,@pvchSuggestedStocks as SuggestedStocks
		where not exists
		(
			select 1
			from Email.ProcessHistory
			where EmailSubject = @pvchEmailSubject
			and EmailFrom = @pvchEmailFrom
			and EmailDate = @pdtEmailDate
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