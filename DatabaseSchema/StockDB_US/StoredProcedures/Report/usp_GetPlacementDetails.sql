-- Stored procedure: [Report].[usp_GetPlacementDetails]



CREATE PROCEDURE [Report].[usp_GetPlacementDetails]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10) = null
AS
/******************************************************************************
File: usp_GetPlacementDetails.sql
Stored Procedure Name: usp_GetPlacementDetails
Overview
-----------------
usp_GetPlacementDetails

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
Date:		2020-12-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetPlacementDetails'
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
		  SELECT 
			   [ASXCode]
			  ,[PlacementDate]
			  ,[OfferPrice]
			  ,cast(case when [Discount] is null then case when [ClosePriorToPlacement] > 0 then ([ClosePriorToPlacement] - OfferPrice)*100.0/[ClosePriorToPlacement] end else [Discount] end as decimal(20, 2)) as [Discount]
			  ,[MarketCapAtRaise]
			  ,[ClosePriorToPlacement]
			  ,[Close5dAfterPlacementAnn]
			  ,cast(case when [OfferPrice]  > 0 then ([Close5dAfterPlacementAnn] - [OfferPrice])*100.0/[OfferPrice] else null end as decimal(20, 2)) as T5DaysPlacementPerformance
			  ,[Close30dAfterPlacementAnn]
			  ,cast(case when [OfferPrice]  > 0 then ([Close30dAfterPlacementAnn] - [OfferPrice])*100.0/[OfferPrice] else null end as decimal(20, 2)) as T30DaysPlacementPerformance
			  ,[Close60dAfterPlacementAnn]
			  ,cast(case when [OfferPrice]  > 0 then ([Close60dAfterPlacementAnn] - [OfferPrice])*100.0/[OfferPrice] else null end as decimal(20, 2)) as T60DaysPlacementPerformance
			  ,[OpenAfterPlacementAnn]
			  ,[CloseAfterPlacementAnn]
			  ,CreateDate
		  FROM StockData.PlaceHistory
		  where ASXCode = @pvchStockCode
		  order by PlacementDate desc		

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
