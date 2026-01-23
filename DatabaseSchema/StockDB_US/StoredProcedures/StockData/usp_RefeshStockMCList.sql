-- Stored procedure: [StockData].[usp_RefeshStockMCList]






CREATE PROCEDURE [StockData].[usp_RefeshStockMCList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshStockMCList.sql
Stored Procedure Name: usp_RefeshStockMCList
Overview
-----------------
usp_RefeshStockMCList

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
Date:		2017-05-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshStockMCList'
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
		if object_id(N'Tempdb.dbo.#TempStockKeyToken') is not null
			drop table #TempStockKeyToken

		select distinct
		   b.[Token]
		  ,a.[ASXCode]
		  ,null as [TokenCount]
		  ,null as [AnnCount]
		  ,null as [TokenPerAnn]
		  ,getdate() as [CreateDate]
		  ,null as [AnnWithTokenPerc]
		into #TempStockKeyToken  			
		from StockData.StockOverviewCurrent as a
		inner join LookupRef.KeyToken as b
		on case when a.CleansedMarketCap <= 20 then 'MC <= 20m'
				when a.CleansedMarketCap > 20 and a.CleansedMarketCap <= 50 then 'MC 20 - 50m'
				when a.CleansedMarketCap > 50 and a.CleansedMarketCap <= 150 then 'MC 50m - 150m'
				when a.CleansedMarketCap > 150 and a.CleansedMarketCap <= 300 then 'MC 150m - 300m'
				when a.CleansedMarketCap > 300 and a.CleansedMarketCap <= 1000 then 'MC 300m - 1b'
				when a.CleansedMarketCap > 1000 then 'MC 1b+'
		   end = b.Token
		where b.TokenType = 'MC'

		delete a
		from StockData.StockKeyToken as a
		inner join LookupRef.KeyToken as c
		on a.Token = c.Token
		left join #TempStockKeyToken as b
		on a.Token = b.Token
		and a.ASXCode = b.ASXCode
		where b.ASXCode is null
		and c.TokenType = 'MC'

		insert into StockData.StockKeyToken
		(
		   [Token]
		  ,[ASXCode]
		  ,[TokenCount]
		  ,[AnnCount]
		  ,[TokenPerAnn]
		  ,[CreateDate]
		  ,[AnnWithTokenPerc]
		)
		select
		   [Token]
		  ,[ASXCode]
		  ,[TokenCount]
		  ,[AnnCount]
		  ,[TokenPerAnn]
		  ,[CreateDate]
		  ,[AnnWithTokenPerc]
		from #TempStockKeyToken as a
		where not exists
		(
			select 1
			from StockData.StockKeyToken as x
			inner join LookupRef.KeyToken as y
			on x.Token = y.Token
			and y.TokenType = 'MC'
			and x.Token = a.Token
			and x.ASXCode = a.ASXCode
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
