-- Stored procedure: [Report].[usp_Get3BDetails]



CREATE PROCEDURE [Report].[usp_Get3BDetails]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10) = null
AS
/******************************************************************************
File: usp_Get3BDetails.sql
Stored Procedure Name: usp_Get3BDetails
Overview
-----------------
usp_Get3BDetails

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
Date:		2018-11-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get3BDetails'
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
		SELECT [AnnouncementID]
			  ,[ASXCode]
			  ,[AnnDateTime]
			  ,[AnnDescr]
			  ,[IssuePrice]
			  ,format([SharesIssued], 'N0') as [SharesIssued]
			  ,[IssueDate]
			  ,case when len(PurposeOfIssue) > 200 then left([PurposeOfIssue], 200) + '...' else [PurposeOfIssue] end as [PurposeOfIssue]
			  ,[TotalSharesOnASX]
			  ,isnull([IsPlacement], 0) as [IsPlacement]
			  ,case when len([IssuePriceRaw]) > 200 then left([IssuePriceRaw], 200) + '...' else [IssuePriceRaw] end as [IssuePriceRaw]
			  ,case when len([SharesIssuedRaw]) > 200 then left([SharesIssuedRaw], 200) + '...' else [SharesIssuedRaw] end as [SharesIssuedRaw]
			  ,case when len([IssueDateRaw]) > 200 then left([IssueDateRaw], 200) + '...' else [IssueDateRaw] end as [IssueDateRaw]
			  ,case when len([TotalSharesOnASXRaw]) > 200 then left([TotalSharesOnASXRaw], 200) + '...' else [TotalSharesOnASXRaw] end as [TotalSharesOnASXRaw]
		  FROM [StockData].[Appendix3B]
		  where ASXCode = @pvchStockCode
		  order by AnnDateTime desc		

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
