-- Stored procedure: [Alert].[usp_AddTradingAlert]


CREATE PROCEDURE [Alert].[usp_AddTradingAlert]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10),
@pintUserID int,
@pintTradingAlertTypeID int,
@pdecAlertPrice decimal(20, 4),
@pintAlertVolume bigint,
@pvchAlertPriceType varchar(100),
@pintBoost int = null,
@pvchMessage as varchar(200) output
AS
/******************************************************************************
File: usp_AddTradingAlert.sql
Stored Procedure Name: usp_AddTradingAlert
Overview
-----------------
usp_AddTradingAlert

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddTradingAlert'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Alert'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		select @pvchMessage = ''

		insert into [Alert].[TradingAlert]
		(
		   [ASXCode]
		  ,[UserID]
		  ,[TradingAlertTypeID]
		  ,[AlertPrice]
		  ,[AlertVolume]
		  ,[ActualPrice]
		  ,[ActualVolume]
		  ,[CreateDate]
		  ,[AlertTriggerDate]
		  ,[NotificationSentDate]
		  ,AlertPriceType
		  ,Boost
		)
		select
		   @pvchASXCode as [ASXCode]
		  ,@pintUserID as [UserID]
		  ,@pintTradingAlertTypeID as [TradingAlertTypeID]
		  ,@pdecAlertPrice as [AlertPrice]
		  ,case when @pintAlertVolume > 0 then @pintAlertVolume else null end as [AlertVolume]
		  ,null as [ActualPrice]
		  ,null as [ActualVolume]
		  ,getdate() as [CreateDate]
		  ,null as [AlertTriggerDate]
		  ,null as [NotificationSentDate]
		  ,@pvchAlertPriceType as AlertPriceType
		  ,@pintBoost as Boost

		  select @pvchMessage = 'Trading alert on ' + @pvchASXCode + ' successfully added.'

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