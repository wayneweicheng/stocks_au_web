-- Stored procedure: [Report].[usp_Top20Shareholder]


CREATE PROCEDURE [Report].[usp_Top20Shareholder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10) = null
AS
/******************************************************************************
File: usp_Top20Shareholder.sql
Stored Procedure Name: usp_Top20Shareholder
Overview
-----------------
usp_Top20Shareholder

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
Date:		2020-07-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Top20Shareholder'
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
		select *
		from
		(
			select 
				a.[ASXCode],
				a.[NumberOfSecurity],
				a.[HolderName] as ShareHolder,
				a.[CurrDate],
				a.[PrevDate],
				a.[CurrRank],
				a.[PrevRank],
				a.[CurrShares],
				a.[PrevShares],
				a.[CurrSharesPerc],
				a.[PrevSharesPerc],
				a.[ShareDiffPerc],	
				b.RecentPerformance,
				b.NoStocks,
				b.WorstStockPerformance,
				b.BestStockPerformance,
				b.ReportPeriod,
				c.RecentPerformance as LongTermRecentPerformance,
				c.NoStocks as LongTermNoStocks,
				c.WorstStockPerformance as LongTermWorstStockPerformance,
				c.BestStockPerformance as LongTermBestStockPerformance,
				c.ReportPeriod as LongTermReportPeriod
			from StockData.v_Top20HolderLatest as a
			left join StockData.v_ShareHolderRatingLatest as b
			on a.HolderName = b.ShareHolder
			and b.StockType = 'All'
			and b.DaysGoBack = 20
			left join StockData.v_ShareHolderRatingLatest as c
			on a.HolderName = c.ShareHolder
			and c.StockType = 'All'
			and c.DaysGoBack = 120
			where ASXCode = @pvchStockCode
			union
			select 
				a.[ASXCode],
				null as [NumberOfSecurity],
				'N/A' as ShareHolder,
				a.[CurrDate],
				a.[PrevDate],
				999 as [CurrRank],
				null as [PrevRank],
				sum(a.[CurrShares]) as [CurrShares],
				sum(a.[PrevShares]) as [PrevShares],
				sum(a.[CurrSharesPerc]) as [CurrSharesPerc],
				sum(a.[PrevSharesPerc]) as [PrevSharesPerc],
				cast(case when sum(a.[PrevShares]) > 0 then (sum(a.[CurrShares]) - sum(a.[PrevShares]))*100.0/sum(a.[PrevShares]) else null end as decimal(20, 2)) as [ShareDiffPerc],	
				null as RecentPerformance,
				null as NoStocks,
				null as WorstStockPerformance,
				null as BestStockPerformance,
				null as ReportPeriod,
				null as LongTermRecentPerformance,
				null as LongTermNoStocks,
				null as LongTermWorstStockPerformance,
				null as LongTermBestStockPerformance,
				null as LongTermReportPeriod
			from StockData.v_Top20HolderLatest as a
			where ASXCode = @pvchStockCode
			group by ASXCode, [CurrDate], PrevDate
		) as x
		order by CurrRank, isnull(ShareHolder, 'zzz')

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
