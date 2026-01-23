-- Stored procedure: [Utility].[usp_AddAlertType]





CREATE PROCEDURE [Utility].[usp_AddAlertType]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddAlertType.sql
Stored Procedure Name: usp_AddAlertType
Overview
-----------------
usp_AddAlertType

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
Date:		2019-09-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddAlertType'
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
		insert into LookupRef.AlertType
		(
			AlertTypeID,
			AlertTypeName,
			CreateDate,
			IsDisabled
		)
		select
			15 as AlertTypeID,
			'Breakaway Gap' as AlertTypeName,
			getdate() as CreateDate,
			0 as IsDisabled

		insert into [Stock].[ASXAlertSetting]
		(
			   [ASXCode]
			  ,[AlertTypeID]
			  ,[CreateDate]
			  ,[StockUserID]
		)
		select
			   [ASXCode]
			  ,15 as [AlertTypeID]
			  ,getdate() as [CreateDate]
			  ,[StockUserID]
		from [Stock].[ASXAlertSetting]
		where AlertTypeID = 1

		insert into [BackTest].[Strategy]
		(
			   [StrategyName]
			  ,[StrategyDescription]
			  ,[MaxHoldDays]
			  ,[AlertTypeID]
			  ,[IsDisabled]
			  ,[CreateDate]
		)
		select
			  'Breakaway Gap' as [StrategyName]
			  ,'Breakaway Gap' as [StrategyDescription]
			  ,100 as [MaxHoldDays]
			  ,15 as [AlertTypeID]
			  ,0 as [IsDisabled]
			  ,getdate() as [CreateDate]

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
