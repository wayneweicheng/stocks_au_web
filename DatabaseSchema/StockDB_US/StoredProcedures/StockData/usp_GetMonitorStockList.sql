-- Stored procedure: [StockData].[usp_GetMonitorStockList]


--EXEC [StockData].[usp_GetMonitorStockList]
--@pintPriceSummaryStock = 0

CREATE PROCEDURE [StockData].[usp_GetMonitorStockList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchMonitorTypeID as char(1) = 'C',
@pintPriceSummaryStock as int = 0
AS
/******************************************************************************
File: usp_GetMonitorStockList.sql
Stored Procedure Name: usp_GetMonitorStockList
Overview
-----------------
usp_GetMonitorStockList

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMonitorStockList'
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
		
		if @pintPriceSummaryStock = 1
		begin
			SELECT a.ASXCode as ASXCode
				  ,case when b.ASXCode is null then substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) else substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) + ' - ' + b.ASXCompanyName + isnull(' - ' + cast(c.CleansedMarketCap as varchar(100)), '') end as CompanyName
				  ,null as [CreateDate]
				  ,null as [LastUpdateDate]
				  ,null as [UpdateStatus]	
				  ,999 as PriorityLevel
			FROM [StockData].[MonitorStock] as a
			left join Stock.ASXCompany as b
			on a.ASXCode = b.ASXCode
			left join StockData.CompanyInfo as c
			on a.ASXCode = c.ASXCode
			where MonitorTypeID = @pvchMonitorTypeID
			union
			SELECT a.ASXCode as ASXCode
				  ,case when b.ASXCode is null then substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) else substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) + ' - ' + b.ASXCompanyName + isnull(' - ' + cast(c.CleansedMarketCap as varchar(100)), '') end as CompanyName
				  ,null as [CreateDate]
				  ,null as [LastUpdateDate]
				  ,null as [UpdateStatus]	
				  ,999 as PriorityLevel
			FROM [StockData].[WatchListStock] as a
			left join Stock.ASXCompany as b
			on a.ASXCode = b.ASXCode
			left join StockData.CompanyInfo as c
			on a.ASXCode = c.ASXCode
		end
		else
		begin
			SELECT a.ASXCode as ASXCode
				  ,case when a.PriorityLevel > 1000 then '--*' else '' end + case when b.ASXCode is null then substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) else substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) + ' - ' + b.ASXCompanyName + isnull('-' + a.StockSource, '') + isnull(' - ' + cast(c.CleansedMarketCap as varchar(100)), '') end as CompanyName
				  ,a.[CreateDate]
				  ,[LastUpdateDate]
				  ,[UpdateStatus]	
				  ,isnull(a.PriorityLevel, 999) as PriorityLevel
			FROM [StockData].[MonitorStock] as a
			left join Stock.ASXCompany as b
			on a.ASXCode = b.ASXCode
			left join StockData.CompanyInfo as c
			on a.ASXCode = c.ASXCode
			where MonitorTypeID = @pvchMonitorTypeID
			order by isnull(a.PriorityLevel, 999), a.ASXCode
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
