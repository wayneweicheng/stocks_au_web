-- Stored procedure: [Utility].[usp_SendEmail]





CREATE PROCEDURE [Utility].[usp_SendEmail]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_SendEmail.sql
Stored Procedure Name: usp_SendEmail
Overview
-----------------
usp_SendEmail

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
Date:		2017-04-26
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddEmail'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Utility'
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
		declare	@intEmailHistoryID as int
		declare	@vchEmailRecipient as varchar(200)
		declare	@vchEmailSubject as varchar(2000)
		declare	@vchEmailBody as varchar(max)
		
		declare curEmailHistory cursor for
		select
			EmailHistoryID,
			EmailRecipient,
			EmailSubject,
			EmailBody
		from Utility.EmailHistory
		where StatusID = 'Q'
		
		open curEmailHistory

		fetch curEmailHistory into @intEmailHistoryID, @vchEmailRecipient, @vchEmailSubject, @vchEmailBody

		while @@fetch_status = 0
		begin
			select @intEmailHistoryID, @vchEmailRecipient, @vchEmailSubject, @vchEmailBody

			DECLARE @pvchEmailRecipient varchar(200) = @vchEmailRecipient
			DECLARE @pvchEmailSubject varchar(2000) = @vchEmailSubject
			DECLARE @pvchEmailBody varchar(max) = @vchEmailBody
			
			-- TODO: Set parameter values here.
			begin try
				exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
				@recipients = @vchEmailRecipient,
				@subject = @vchEmailSubject,
				@body = @vchEmailBody

				update a
				set StatusID = 'C',
					ErrorMessage = null,
					EmailSentDate = getdate()
				from Utility.EmailHistory as a
				where EmailHistoryID = @intEmailHistoryID
			end try
			begin catch
				update a
				set StatusID = 'E',
					ErrorMessage = @@ERROR
				from Utility.EmailHistory as a
				where EmailHistoryID = @intEmailHistoryID
			end catch

			fetch curEmailHistory into @intEmailHistoryID, @vchEmailRecipient, @vchEmailSubject, @vchEmailBody
		end

		close curEmailHistory
		deallocate curEmailHistory


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
