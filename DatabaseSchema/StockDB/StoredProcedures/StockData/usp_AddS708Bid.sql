-- Stored procedure: [StockData].[usp_AddS708Bid]




CREATE PROCEDURE [StockData].[usp_AddS708Bid]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(200),
@pvchDealType varchar(10),
@pdecBidAmount decimal(20, 4),
@pvchCreatedBy varchar(200),
@pvchCreatedByUserID varchar(50),
@pvchOutputMessage varchar(2000) output
AS
/******************************************************************************
File: usp_AddS708Deal.sql
Stored Procedure Name: usp_AddS708Deal
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddS708Bid'
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

		if object_id(N'Tempdb.dbo.#TempS708Bid') is not null
			drop table #TempS708Bid

		select
			@pvchASXCode + '.AX' as ASXCode,
			@pvchDealType as DealType,
			@pdecBidAmount as BidAmount,
			getdate() as CreateDate,
			@pvchCreatedBy as CreatedBy,
			@pvchCreatedByUserID as CreatedByUserID
		into #TempS708Bid

		declare @intS708DealID as int = 0

		select @intS708DealID = S708DealID
		from StockData.S708Deal
		where ASXCode = @pvchASXCode + '.AX'
		and DealType = @pvchDealType
		and datediff(day, CreateDate, getdate()) < case when @pvchDealType = 'CR' then 20 else 60 end

		if isnull(@intS708DealID, 0) = 0
		begin
			select @pvchOutputMessage = @pvchDealType + ' Deal' + ' for ' + @pvchASXCode + ' could not be found. Please check if it exists, or the valid bid period already passed for this deal.'
		end
		else
		begin
			if exists
			(
				select 1
				from StockData.S708Bid
				where S708DealID = @intS708DealID
				and CreatedBy = @pvchCreatedBy
			)
			begin
				if @pdecBidAmount = 0
				begin
					delete a
					from StockData.S708Bid as a
					where S708DealID = @intS708DealID
					and CreatedBy = @pvchCreatedBy

					select @pvchOutputMessage = ' Your existing bid record for this deal is removed now.'

				end
				else
				begin
					update a
					set a.BidAmount = @pdecBidAmount
					from StockData.S708Bid as a
					where S708DealID = @intS708DealID
					and CreatedBy = @pvchCreatedBy

					select @pvchOutputMessage = ' You have an existing bid record for this deal, and details are updated now.'
				end
			end
			else
			begin
				insert into StockData.S708Bid
				(
					S708DealID,
					BidAmount,
					CreateDate,
					CreatedBy,
					CreatedByUserID
				)
				select
					@intS708DealID as S708DealID,
					BidAmount,
					CreateDate,
					CreatedBy,
					CreatedByUserID
				from #TempS708Bid
			
				select @pvchOutputMessage = @pvchDealType + ' Deal ' + ' for ' + @pvchASXCode + '. Your bid has been added successfully.'
			end
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
