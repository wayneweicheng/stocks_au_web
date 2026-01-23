-- Stored procedure: [StockData].[usp_AddOverview]






CREATE PROCEDURE [StockData].[usp_AddOverview]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchMarketCap as varchar(50),
@pvchShareOnIssue as varchar(50)
AS
/******************************************************************************
File: usp_AddOverview.sql
Stored Procedure Name: usp_AddOverview
Overview
-----------------
usp_AddOverview

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
Date:		2017-02-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOverview'
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
		if len(@pvchMarketCap) > 0 or len(@pvchShareOnIssue) > 0
		begin
			print 'OK'
		end
		else
		begin
			raiserror('Values not populated', 16, 0)
		end

		if object_id(N'Tempdb.dbo.#TempOverview') is not null
			drop table #TempOverview

		create table #TempOverview
		(
			StockOverviewID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			MarketCap varchar(50) null,
			ShareOnIssue varchar(50) null,
			CreateDate smalldatetime
		)

		insert into #TempOverview
		(
			ASXCode,
			MarketCap,
			ShareOnIssue,
			CreateDate
		)
		select
			@pvchASXCode as ASXCode,
			@pvchMarketCap as MarketCap,
			@pvchShareOnIssue as ShareOnIssue,
			getdate() as CreateDate
		
		update a
		set a.DateTo = getdate()
		from StockData.StockOverview as a
		inner join #TempOverview as c
		on a.ASXCode = c.ASXCode
		left join #TempOverview as b
		on isnull(a.MarketCap, '') = isnull(b.MarketCap, '')
		and isnull(a.ShareOnIssue, '') = isnull(b.ShareOnIssue, '')
		where b.ASXCode is null
		and a.DateTo is null

		insert into StockData.StockOverview
		(
		   [ASXCode]
		  ,[MarketCap]
		  ,[ShareOnIssue]
		  ,[DateFrom]
		  ,[DateTo]
		)
		select
		   [ASXCode]
		  ,[MarketCap]
		  ,[ShareOnIssue]
		  ,getdate() as [DateFrom]
		  ,null as [DateTo]
		from #TempOverview as a
		where not exists
		(
			select 1
			from StockData.StockOverview
			where ASXCode = a.ASXCode
			and isnull(MarketCap, '') = isnull(a.MarketCap, '')
			and isnull(ShareOnIssue, '') = isnull(a.ShareOnIssue, '')
			and DateTo is null
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
