-- Stored procedure: [StockAPI].[usp_GetIBCOSForStock]


CREATE PROCEDURE [StockAPI].[usp_GetIBCOSForStock]
@pbitDebug AS BIT = 0,
@pdtObservationDate as date = null,
@pbitBackSeriesMode as bit = 0,
@pintProcessID as int = null,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetIBCOSForStock.sql
Stored Procedure Name: usp_GetIBCOSForStock
Overview
-----------------
usp_GetIBCOSForStock

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockAPI].[usp_GetIBCOSForStock]
@pdtObservationDate = '2025-01-10',
@pbitBackSeriesMode = 0,
@pintProcessID = -1

*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2022-07-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetIBCOSForStock'
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

		if @pdtObservationDate is null
			select @pdtObservationDate = cast(getdate() as date)

		if @pintProcessID = -1
			select @pintProcessID = null

		if @pbitBackSeriesMode = 1
		begin
			print 100
		end
		else
		begin	
			if object_id(N'Tempdb.dbo.#TempASXCode2') is not null
				drop table #TempASXCode2
				
			--declare @pdtObservationDate as date = '2025-01-10'
			
			select 
				identity(int, 1, 1) as UniqueKey,
				a.[ASXCode],
				substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
				isnull(b.SaleDateTime, dateadd(hour, 4, cast(@pdtObservationDate as datetime))) as LastSaleDateTime,
				isnull(c.BidAskDateTime, dateadd(hour, 4, cast(@pdtObservationDate as datetime))) as LastBidAskDateTime,
				checksum(a.ASXCode + cast(b.SaleDateTime as varchar(100))) as HashKey
			into #TempASXCode2
			from 
			(
				--declare @pdtObservationDate as date = '2023-11-14'
				select 'VXX.US' as ASXCode
				union
				select 'QQQ.US' as ASXCode
			) as a 
			left join 
			(
				select ASXCode, dateadd(second, 1, max(SaleDateTime)) as SaleDateTime
				from StockData.CourseOfSaleSecondaryToday
				where ObservationDate = @pdtObservationDate
				group by ASXCode
			) as b
			on a.ASXCode = b.ASXCode
			left join 
			(
				select ASXCode, dateadd(second, 1, max(ObservationTime)) as BidAskDateTime
				from StockData.StockBidAsk
				where ObservationDate = @pdtObservationDate
				group by ASXCode
			) as c
			on a.ASXCode = c.ASXCode
			and 1 = 1
			order by a.ASXCode

			select *
			from #TempASXCode2
			where (abs(UniqueKey)%5 = @pintProcessID or @pintProcessID is null)			
			
		end

		return

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
