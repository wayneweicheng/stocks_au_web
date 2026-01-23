-- Stored procedure: [StockData].[usp_GetQU100Stock]


CREATE PROCEDURE [StockData].[usp_GetQU100Stock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pdtObservationDate as date
AS
/******************************************************************************
File: usp_GetMonitorStock.sql
Stored Procedure Name: usp_GetMonitorStock
Overview
-----------------
usp_GetMonitorStock

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMonitorStock'
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
		--declare @pdtObservationDate as date = '2022-10-03'
		declare @dtCompareDate as date = [Common].[DateAddBusinessDay](0, @pdtObservationDate)
		
		if @dtCompareDate != @pdtObservationDate
		begin
			select
				[ASXCode],
				substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
				null as LastUpdateDate
			from
			(
				select 'SPY.US' as ASXCode
				union
				select 'QQQ.US' as ASXCode
				union
				select 'IWM.US' as ASXCode
				union
				select 'DIA.US' as ASXCode
				union
				select 'GDX.US' as ASXCode
				union
				select 'TQQQ.US' as ASXCode
				union
				select 'SQQQ.US' as ASXCode
				union
				select 'TSLA.US' as ASXCode
				union
				select 'AAPL.US' as ASXCode
				union
				select 'VXX.US' as ASXCode
				union
				select 'UVXY.US' as ASXCode
			) as i			
			where 1 != 1
		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempObDate') is not null
				drop table #TempObDate

			select top 3 ObservationDate 
			into #TempObDate
			from
			(
				select ObservationDate 
				from StockData.QU100Parsed
				where ObservationDate <= @pdtObservationDate
				and TimeFrame = 'daily'
				group by ObservationDate 
			) as a
			order by ObservationDate desc;

			select
				[ASXCode],
				substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
				null as LastUpdateDate
			from
			(
				select 'SPY.US' as ASXCode
				union
				select 'QQQ.US' as ASXCode
				union
				select 'IWM.US' as ASXCode
				union
				select 'DIA.US' as ASXCode
				union
				select 'GDX.US' as ASXCode
				union
				select 'TQQQ.US' as ASXCode
				union
				select 'SQQQ.US' as ASXCode
				union
				select 'TSLA.US' as ASXCode
				union
				select 'AAPL.US' as ASXCode
				union
				select 'VXX.US' as ASXCode
				union
				select 'UVXY.US' as ASXCode
			) as i
			union
			select 
				distinct ASXCode, Ticker as StockCode, null as LastUpdateDate
			from StockData.QU100Parsed
			where ObservationDate in (select ObservationDate from #TempObDate)
			and timeframe = 'daily'
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
