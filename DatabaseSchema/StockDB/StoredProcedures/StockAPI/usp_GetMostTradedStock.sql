-- Stored procedure: [StockAPI].[usp_GetMostTradedStock]


CREATE PROCEDURE [StockAPI].[usp_GetMostTradedStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetMostTradedStock.sql
Stored Procedure Name: usp_GetMostTradedStock
Overview
-----------------
usp_GetMostTradedStock

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
Date:		2021-06-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MostTradedSmallCap'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
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
		--declare @pdtObservationDate as date = getdate()
		if object_id(N'Transform.MostTradedStock') is not null
			drop table Transform.MostTradedStock
		
		select top 200
			[ASXCode],
			substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			MedianTradeValueDaily
		into Transform.MostTradedStock
		from (		
			select c.MC, a.ASXCode, a.MedianTradeValue, a.MedianTradeValueDaily, a.MedianPriceChangePerc 
			--into #TempHighVolumeSmallCap
			from StockData.MedianTradeValue as a
			inner join StockData.PriceHistoryCurrent as b
			on a.ASXCode = b.ASXCode
			inner join StockData.v_CompanyFloatingShare as c
			on a.ASXCode = c.ASXCode
			where MedianPriceChangePerc > 1
			--and c.MC < 4000
			--and [Close] < 1
			--order by MedianTradeValue desc;
			--and a.ASXCode = 'PLS.AX'
		) as a
		where charindex('.', a.ASXCode, 0) > 0
		order by MedianTradeValueDaily desc;
		
		select *
		from Transform.MostTradedStock
		order by MedianTradeValueDaily desc;
		
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
