-- Stored procedure: [StockData].[usp_PurgeData]






CREATE PROCEDURE [StockData].[usp_PurgeData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_PurgeData.sql
Stored Procedure Name: usp_PurgeData
Overview
-----------------
usp_PurgeData

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
Date:		2016-05-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_PurgeData'
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
		delete a
		from StockData.RawData as a
		where datediff(hour, CreateDate, getdate()) > 6

		delete a
		from StockData.MarketDepth as a
		where datediff(day, DateFrom, getdate()) > 90

		if object_id(N'Tempdb.dbo.#TempMarketDepth') is not null
			drop table #TempMarketDepth

		select distinct ASXCode
		into #TempMarketDepth
		from StockData.MarketDepth

		delete a
		from StockData.CourseOfSale as a
		where datediff(day, CreateDate, getdate()) > 365
		or 
		(
			not exists
			(
				select 1
				from #TempMarketDepth
				where ASXCode = a.ASXCode			
			)
			and datediff(day, CreateDate, getdate()) > 90
		)		

		delete a
		from HC.CommonStockHistory as a
		inner join
		(
			select 
				CreateDate,
				row_number() over (partition by cast(CreateDate as date) order by CreateDate desc) as RowNumber
			from 
			(
				select distinct CreateDate
				from HC.CommonStockHistory
			) as x
		) as b
		on a.CreateDate = b.CreateDate
		where b.RowNumber > 1

		delete a
		from HC.CommonStockPlusHistory as a
		inner join
		(
			select 
				CreateDate,
				row_number() over (partition by cast(CreateDate as date) order by CreateDate desc) as RowNumber
			from 
			(
				select distinct CreateDate
				from HC.CommonStockPlusHistory
			) as x
		) as b
		on a.CreateDate = b.CreateDate
		where b.RowNumber > 1

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