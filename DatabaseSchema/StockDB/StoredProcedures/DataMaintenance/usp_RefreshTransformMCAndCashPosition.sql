-- Stored procedure: [DataMaintenance].[usp_RefreshTransformMCAndCashPosition]





create PROCEDURE [DataMaintenance].[usp_RefreshTransformMCAndCashPosition]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformMCAndCashPosition.sql
Stored Procedure Name: usp_RefreshTransformMCAndCashPosition
Overview
-----------------
usp_RefreshTransformMCAndCashPosition

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
Date:		2018-02-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformMCAndCashPosition'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		
		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
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

		delete a
		from #TempCashPosition as a
		where datediff(day, AnnDateTime, getdate()) > 105

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select MC, CashPosition/1000.0 as CashPosition, AnnDateTime, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode

		update a
		set CashPosition = case when CashPosition > 10*MC then CashPosition/1000.0 else CashPosition end
		from #TempCashVsMC as a
		
		update a
		set CashPosition = case when CashPosition > 2*MC then null else CashPosition end
		from #TempCashVsMC as a
			
		if object_id(N'Transform.StockMCAndCashPosition') is not null
			drop table Transform.StockMCAndCashPosition

		select a.*, b.FloatingShares, b.FloatingSharesPerc, b.SharesIssued, c.BusinessDetails, c.IndustrySubGroup, c.LastValidateDate, d.[Close], d.ObservationDate
		into Transform.StockMCAndCashPosition
		from #TempCashVsMC as a
		inner join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode
		inner join StockData.CompanyInfo as c
		on a.ASXCode = c.ASXCode
		inner join StockData.PriceHistoryCurrent as d
		on a.ASXCode = d.ASXCode
		where a.MC is not null
		--and a.ASXCode = 'GED.AX'
		and exists
		(
			select 1
			from StockData.PriceHistory
			where ASXCode = a.ASXCode
			and ObservationDate > dateadd(day, -5, getdate()) 
			and Volume > 0
		)
		and d.[Close] > 0.01
		order by a.MC - isnull(CashPosition, 0) asc

				
		
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
