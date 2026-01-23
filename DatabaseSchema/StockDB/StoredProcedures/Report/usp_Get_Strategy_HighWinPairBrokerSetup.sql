-- Stored procedure: [Report].[usp_Get_Strategy_HighWinPairBrokerSetup]


CREATE PROCEDURE [Report].[usp_Get_Strategy_HighWinPairBrokerSetup]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0
AS
/******************************************************************************
File: usp_Get_Strategy_HighWinPairBrokerSetup.sql
Stored Procedure Name: usp_Get_Strategy_HighWinPairBrokerSetup
Overview
-----------------
usp_Get_Strategy_HighWinPairBrokerSetup

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
Date:		2020-12-14
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_HighWinPairBrokerSetup'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		--declare @pintNumPrevDay as int = 0
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -1, getdate()) as date)
		declare @dtObservationDatePrev20 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -6, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempPriceSummaryLatest') is not null
			drop table #TempPriceSummaryLatest

		select *
		into #TempPriceSummaryLatest
		from StockData.v_PriceSummary_Latest
		where ObservationDate >= @dtObservationDatePrev20
		and ObservationDate <= @dtObservationDate

		select top 50
			'Highest gain' as ReportType,			
			format(a.[Value], 'N0') as TradeValue,
			a.ASXCode, 
			a.ObservationDate,
			a.PriceChangeVsOpen,
			a.PriceChangeVsPrevClose,
			a.[Close],
			a.VWAP,
			case when a.VWAP > 0 then cast((a.[Close]*1.0/a.VWAP - 1)*100.0 as decimal(10, 2)) else null end as CloseAboveVWAP,
			b.TomorrowChange,
			b.TomorrowOpenChange,
			b.Next2DaysChange,
			b.Next5DaysChange,
			MinObservationDate,
			NoOb
		from #TempPriceSummaryLatest as a
		left join StockData.v_PriceHistory as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		inner join
		(
			select ASXCode, max(VWAP) as VWAP, count(*) as NoOb, Min(ObservationDate) as MinObservationDate
			from #TempPriceSummaryLatest
			where ObservationDate < @dtObservationDate
			group by ASXCode
		) as c
		on a.ASXCode = c.ASXCode
		and a.[Close] > c.VWAP
		where a.ObservationDate = @dtObservationDate
		and a.[Value] > 300000 
		and a.[Close] >= a.VWAP
		and c.NoOb > 3
		and a.PriceChangeVsPrevClose >= 3
		order by PriceChangeVsPrevClose desc

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
