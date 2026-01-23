-- Stored procedure: [StockData].[usp_GetPriceSummaryStockList]





CREATE PROCEDURE [StockData].[usp_GetPriceSummaryStockList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintCustomFilterID as int = 0
AS
/******************************************************************************
File: usp_GetPriceSummaryStockList.sql
Stored Procedure Name: usp_GetPriceSummaryStockList
Overview
-----------------
usp_GetPriceSummaryStockList

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetPriceSummaryStockList'
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

		if @pintCustomFilterID = 0
		begin
			select
				*
			from
			(
				select
						a.ASXCode as ASXCode
						,case when a.ASXCode is null then substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) else substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) + ' - ' + a.ASXCompanyName + isnull(' - ' + cast(c.[CleansedMarketCap] as varchar(20)) + 'MB', '') end as CompanyName
				from Stock.ASXCompany as a
				inner join
				(
					select ASXCode
					from StockData.PriceHistory with(nolock)
					where 1 = 1
					and charindex('.', ASXCode, 0) > 0
					and ObservationDate > dateadd(day, -30, getdate())
					group by ASXCode
				) as b
				on a.ASXCode = b.ASXCode
				left join [StockData].[CompanyInfo] as c
				on a.ASXCode = c.ASXCode
				where exists
				(
					select 1
					from StockData.MedianTradeValue
					where MedianTradeValueDaily > 10000
					and ASXCode = a.ASXCode
				)
				--and a.ASXCode = 'ALB.US'
			) as x
			where 1 = 1
			order by x.ASXCode asc
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
