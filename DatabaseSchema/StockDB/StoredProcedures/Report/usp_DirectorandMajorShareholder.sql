-- Stored procedure: [Report].[usp_DirectorandMajorShareholder]


CREATE PROCEDURE [Report].[usp_DirectorandMajorShareholder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10) = null,
@pvchDirectorName as varchar(200) = null
AS
/******************************************************************************
File: usp_DirectorandMajorShareholder.sql
Stored Procedure Name: usp_DirectorandMajorShareholder
Overview
-----------------
usp_DirectorandMajorShareholder

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
Date:		2017-03-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_DirectorandMajorShareholder'
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
		if object_id(N'Tempd.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition
		) as x
		where RowNumber = 1

		if @pvchStockCode is not null
		begin
			select 
				a.ASXCode, 
				a.Name, 
				a.Since, 
				a.Position,
				b.ASXCode as XRefASXCode,
				b.Name as XRefName,
				b.Since as XRefSince,
				b.Position as XRefPosition,
				c.CleansedMarketCap as XRefMarketCap,
				c.CleansedShareOnIssue as XRefSOI,
				cast(e.CashPosition/1000.0 as decimal(20, 3)) as CashPosition,
				d.ASXCompanyName,
				dense_rank() over (partition by a.ASXCode order by a.Name) as DirRank
			from StockData.DirectorCurrent as a
			inner join StockData.DirectorCurrent as b
			on a.DedupeKey = b.DedupeKey
			left join StockData.StockOverview as c
			on b.ASXCode = c.ASXCode
			and c.DateTo is null
			left join #TempCashPosition as e
			on b.ASXCode = e.ASXCode
			left join Stock.ASXCompany as d
			on b.ASXCode = d.ASXCode
			where a.ASXCode = @pvchStockCode
			order by a.Name, b.ASXCode
		end

		if @pvchDirectorName is not null
		begin
			select 
				a.ASXCode, 
				a.Name, 
				a.Since, 
				a.Position,
				c.CleansedMarketCap as MarketCap,
				c.CleansedShareOnIssue as SOI,
				cast(e.CashPosition/1000000.0 as decimal(20, 3)) as CashPosition,
				d.ASXCompanyName,
				dense_rank() over (partition by a.ASXCode order by a.Name) as DirRank
			from StockData.DirectorCurrent as a
			left join StockData.StockOverview as c
			on a.ASXCode = c.ASXCode
			and c.DateTo is null
			left join #TempCashPosition as e
			on a.ASXCode = e.ASXCode
			left join Stock.ASXCompany as d
			on a.ASXCode = d.ASXCode
			where a.Name like '%' + @pvchDirectorName + '%'
			order by a.Name, a.ASXCode
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