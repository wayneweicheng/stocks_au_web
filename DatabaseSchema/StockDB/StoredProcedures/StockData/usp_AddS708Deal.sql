-- Stored procedure: [StockData].[usp_AddS708Deal]



CREATE PROCEDURE [StockData].[usp_AddS708Deal]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(200),
@pvchDealType varchar(10),
@pdecOfferPrice decimal(10, 4),
@pvchBonusOptionDescr varchar(500),
@pvchAdditionalNotes varchar(2000),
@pvchCreatedBy varchar(200),
@pdtDealCreateDate smalldatetime = null,
@pbitEnableUpdate as bit = 1,
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddS708Deal'
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

		if object_id(N'Tempdb.dbo.#TempS708Deal') is not null
			drop table #TempS708Deal

		select
			upper(@pvchASXCode) + '.AX' as ASXCode,
			@pvchDealType as DealType,
			coalesce(@pdtDealCreateDate, getdate()) as CreateDate,
			@pdecOfferPrice as OfferPrice,
			isnull(@pvchBonusOptionDescr, 'n/a') as BonusOptionDescr,
			isnull(@pvchAdditionalNotes, 'n/a') as AdditionalNotes,
			@pvchCreatedBy as CreatedBy
		into #TempS708Deal

		if exists(
			select 1
			from #TempS708Deal as a
			where exists
			(
				select 1
				from StockData.S708Deal
				where ASXCode = @pvchASXCode + '.AX'
				and DealType = @pvchDealType
				and datediff(day, CreateDate, a.CreateDate) < 20
			)
		)
		begin
			if @pbitEnableUpdate = 1
			begin
				update a
				set a.OfferPrice = b.OfferPrice,
					a.BonusOptionDescr = b.BonusOptionDescr,
					a.AdditionalNotes = b.AdditionalNotes,
					a.UpdatedBy = b.CreatedBy
				from StockData.S708Deal as a
				inner join #TempS708Deal as b
				on a.ASXCode = b.ASXCode
				and a.DealType = b.DealType
				where a.ASXCode = @pvchASXCode + '.AX'
				and a.DealType = @pvchDealType

				select @pvchOutputMessage = @pvchDealType + ' Deal is updated successfully ' + '- ' + @pvchASXCode
			end
			else
			begin
				select @pvchOutputMessage = @pvchDealType + ' Deal update is skipped, deal already exists ' + '- ' + @pvchASXCode
			end
		end
		else
		begin
			insert into StockData.S708Deal
			(
				ASXCode,
				DealType,
				CreateDate,
				OfferPrice,
				BonusOptionDescr,
				AdditionalNotes,
				CreatedBy
			)
			select
				ASXCode,
				DealType,
				CreateDate,
				OfferPrice,
				BonusOptionDescr,
				AdditionalNotes,
				CreatedBy
			from #TempS708Deal
			
			select @pvchOutputMessage = @pvchDealType + ' Deal is added successfully ' + '- ' + @pvchASXCode  
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
