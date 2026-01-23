-- Stored procedure: [StockData].[usp_GetS708Bid]



CREATE PROCEDURE [StockData].[usp_GetS708Bid]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10) = null,
@pvchDealType varchar(10) = null,
@pintLastNumOfDays int
AS
/******************************************************************************
File: usp_GetS708Deal.sql
Stored Procedure Name: usp_GetS708Deal
Overview
-----------------
usp_AddS708Deal

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
Date:		2022-11-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetS708Bid'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchObservationDate as varchar(20) = '20220617'
		
		--Code goes here 
		set dateformat ymd

		if not exists
		(
			select 1
			from StockData.S708Deal as b
			where (@pvchASXCode is null or b.ASXCode = @pvchASXCode + '.AX')
			and (@pvchDealType is null or b.DealType = @pvchDealType)
			and datediff(day, b.CreateDate, getdate()) < @pintLastNumOfDays
		)
		begin
			select @pvchDealType + ' Deal ' + @pvchASXCode + '.AX' + ' does not exist in the system for the last ' + cast(@pintLastNumOfDays as varchar(20)) + ' days.' as Response
		end
		else
		begin
			select
				a.S708DealID,
				b.ASXCode,
				b.DealType,
				b.OfferPrice,
				'***' as BidBy,
				format(a.BidAmount, 'N0') as BidAmount,
				c.AllocationPercBand as [Allocation %],
				b.CreateDate as DealCreateDate,
				a.CreateDate as BidDate
			from StockData.S708Bid as a
			inner join StockData.S708Deal as b
			on a.S708DealID = b.S708DealID
			left join StockData.S708Allocation as c
			on a.S708DealID = c.S708DealID
			and 
			(
				a.CreatedBy = c.CreatedBy
				or
				a.CreatedByUserID = c.CreatedByUserID
			)
			where (@pvchASXCode is null or b.ASXCode = @pvchASXCode + '.AX')
			and (@pvchDealType is null or b.DealType = @pvchDealType)
			and datediff(day, b.CreateDate, getdate()) < @pintLastNumOfDays
			order by b.CreateDate desc, a.CreateDate desc
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
