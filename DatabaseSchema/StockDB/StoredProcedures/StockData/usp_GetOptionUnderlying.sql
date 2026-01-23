-- Stored procedure: [StockData].[usp_GetOptionUnderlying]






CREATE PROCEDURE [StockData].[usp_GetOptionUnderlying]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetOptionUnderlying.sql
Stored Procedure Name: usp_GetOptionUnderlying
Overview
-----------------
usp_GetOptionUnderlying

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
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetOptionUnderlying'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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
		
		select 
			a.[ASXCode] as ASXCode,
			substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			isnull(b.Num, 0) as Num
		from Stock.ASXCompany as a
		inner join 
		(
			select ASXCode, count(*) as Num
			from StockData.OptionTrade
			where ObservationDateLocal > dateadd(day, -60, getdate())
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		where isnull(a.IsDisabled, 0) = 0
		and charindex('.', a.ASXCode, 0) > 0
		and ASX300 = 1
		--and a.ASXCode in ('STO.AX', 'NST.AX', 'PRU.AX', 'PLS.AX', 'AKE.AX', 'LTR.AX', 'CBA.AX', 'EVN.AX', 'RMS.AX', 'EVN.AX', 'RRL.AX', 'NCM.AX', 'WGX.AX', 'WDS.AX', 'WHC.AX')
		--and left(ASXCode, 3) in ('AKE', 'LTR', 'PLS', 'SYA', 'CXO', 'NVX', 'RNU', 'PRU', 'DEG', 'FLT', 'CHN', 'BRN', 'SLR', 'BGL', 'GRR', 'STX', 'AGY', 'PNV', 'SYR', 'ZIP', 'LLL', 'PBH', 'NWE', 'ARU', 'TER')
		--and left(ASXCode, 3) in ('CBA')
		order by isnull(b.Num, 0) desc;

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

	--	IF @@TRANCOUNT > 0
	--	BEGIN
	--		ROLLBACK TRANSACTION
	--	END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
