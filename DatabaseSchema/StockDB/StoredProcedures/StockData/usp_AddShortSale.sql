-- Stored procedure: [StockData].[usp_AddShortSale]



CREATE PROCEDURE [StockData].[usp_AddShortSale]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchCompanyName as varchar(200), 
@pvchShareClass as varchar(50), 
@pvchShareSales as varchar(50), 
@pvchIssuedCapital as varchar(50), 
@pvchObservationDate as varchar(20)
AS
/******************************************************************************
File: usp_AddCompanyInfo.sql
Stored Procedure Name: usp_AddCompanyInfo
Overview
-----------------
usp_AddCompanyInfo

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
Date:		2021-06-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddShortSale'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchASXCode as varchar(100) = 'PLS.AX'
		--declare @pvchCompanyInfo as varchar(100) = '{}'

		--Code goes here 
		--create table StockData.ShortSale
		--(
		--	ShortSaleID int identity(1, 1) not null,
		--	ASXCode varchar(10),
		--	CompanyName varchar(200), 
		--	ShareClass varchar(50), 
		--	ShareSales int, 
		--	IssuedCapital bigint, 
		--	ObservationDate date,
		--	CreateDateTime smalldatetime
		--)

		set dateformat dmy

		--delete a
		--from StockData.ShortSale as a
		--where ObservationDate = cast(@pvchObservationDate as date)
		--and ASXCode = @pvchASXCode

		insert into StockData.ShortSale
		(
			ASXCode,
			CompanyName, 
			ShareClass, 
			ShareSales, 
			IssuedCapital, 
			ObservationDate,
			CreateDateTime
		)
		select *
		from
		(
			select
				@pvchASXCode as ASXCode,
				@pvchCompanyName as CompanyName, 
				@pvchShareClass as ShareClass, 
				cast(replace(@pvchShareSales, ',', '') as int) as ShareSales, 
				cast(replace(@pvchIssuedCapital, ',', '') as bigint) as IssuedCapital, 
				cast(@pvchObservationDate as date) as ObservationDate,
				getdate() as CreateDateTime
		) as a
		where not exists
		(
			select 1
			from StockData.ShortSale
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
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
