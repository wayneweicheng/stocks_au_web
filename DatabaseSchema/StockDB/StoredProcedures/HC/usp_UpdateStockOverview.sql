-- Stored procedure: [HC].[usp_UpdateStockOverview]

CREATE PROCEDURE [HC].[usp_UpdateStockOverview]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchMonthlyVisit as varchar(100),
@pvchNoOfPost varchar(100),
@pvchMarketCap varchar(100)
AS
/******************************************************************************
File: usp_UpdateStockOverview.sql
Stored Procedure Name: usp_UpdateStockOverview
Overview
-----------------
usp_UpdateStockOverview

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
Date:		2018-03-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_UpdateStockOverview'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'HC'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if object_id(N'#Tempdb.dbo.#TempHCStockOverview') is not null
			drop table #TempHCStockOverview

		create table #TempHCStockOverview
		(
			ASXCode varchar(10) not null,
			MonthlyVisit varchar(100) null,
			NoOfPost varchar(100) null,
			MarketCap varchar(100)
		)
	
		insert into #TempHCStockOverview
		(
			ASXCode,
			MonthlyVisit,
			NoOfPost,
			MarketCap
		)
		select
			@pvchASXCode as ASXCode,
			@pvchMonthlyVisit as MonthlyVisit,
			@pvchNoOfPost as NoOfPost,
			@pvchMarketCap as MarketCap		

		--if object_id(N'Working.TempHCStockOverview') is not null
		--	drop table Working.TempHCStockOverview

		--select *
		--into Working.TempHCStockOverview
		--from #TempHCStockOverview

		declare @dtmUpdateDate as smalldatetime
		select @dtmUpdateDate = getdate()

		update a
		set a.DateTo = @dtmUpdateDate
		from HC.StockOverview as a
		left join #TempHCStockOverview as b
		on a.ASXCode = b.ASXCode
		and isnull(a.MonthlyVisit, '') = isnull(b.MonthlyVisit, '')
		and isnull(a.NoOfPost, '') = isnull(b.NoOfPost, '')
		and isnull(a.MarketCap, '') = isnull(b.MarketCap, '')
		where a.ASXCode = @pvchASXCode
		and a.DateTo is null
		and b.ASXCode is null

		insert into HC.StockOverview
		(
			ASXCode,
			MonthlyVisit,
			NoOfPost,
			MarketCap,
			DateFrom,
			DateTo
		)
		select
			ASXCode,
			MonthlyVisit,
			NoOfPost,
			MarketCap,
			@dtmUpdateDate as DateFrom,
			null as DateTo
		from #TempHCStockOverview as a
		where not exists
		(
			select 1
			from HC.StockOverview as b
			where isnull(a.MonthlyVisit, '') = isnull(b.MonthlyVisit, '')
			and isnull(a.NoOfPost, '') = isnull(b.NoOfPost, '')
			and isnull(a.MarketCap, '') = isnull(b.MarketCap, '')
			and a.ASXCode = b.ASXCode
			and b.DateTo is null
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