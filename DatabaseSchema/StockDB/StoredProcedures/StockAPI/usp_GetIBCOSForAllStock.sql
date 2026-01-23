-- Stored procedure: [StockAPI].[usp_GetIBCOSForAllStock]


CREATE PROCEDURE [StockAPI].[usp_GetIBCOSForAllStock]
@pbitDebug AS BIT = 0,
@pdtObservationDate as date,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetIBCOSForAllStock.sql
Stored Procedure Name: usp_GetIBCOSForAllStock
Overview
-----------------
usp_GetIBCOSForAllStock

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
Date:		2021-06-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetIBCOSForAllStock'
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
		declare @dtObservationDate as date = getdate()

		if object_id(N'Tempdb.dbo.#TempAlertHistory') is not null
			drop table #TempAlertHistory

		select 
			identity(int, 1, 1) as UniqueKey,
			b.AlertTypeName,
			a.ASXCode,
			a.CreateDate,
			cast(a.CreateDate as date) as ObservationDate,
			c.[Value],
			c.Volume,
			c.[High],
			c.[Close],
			d.MedianTradeValue,
			d.MedianTradeValueDaily,
			d.MedianPriceChangePerc,
			case when b.AlertTypeName in ('Breakaway Gap') then 40 
				 when b.AlertTypeName in ('Break Through') then 30 
				 when b.AlertTypeName in ('Gain Momentum', 'Breakthrough Trading Range') then 15
				 else 10
			end as AlertTypeScore
		into #TempAlertHistory
		from 
		(
			select AlertTypeID, ASXCode, CreateDate
			from Stock.ASXAlertHistory
			group by AlertTypeID, ASXCode, CreateDate
		) as a
		inner join LookupRef.AlertType as b
		on a.AlertTypeID = b.AlertTypeID
		inner join StockData.PriceHistory as c
		on a.ASXCode = c.ASXCode
		and cast(a.CreateDate as date) = c.ObservationDate
		left join StockData.MedianTradeValue as d
		on a.ASXCode = d.ASXCode
		where cast(a.CreateDate as date) > cast(Common.DateAddBusinessDay(-1 * 25, @dtObservationDate) as date)
		and cast(a.CreateDate as date) <=  cast(Common.DateAddBusinessDay(-1 * 1, @dtObservationDate) as date)
		and b.AlertTypeName in
		(
			'Break Through',
			'Breakaway Gap',
			'Breakthrough Trading Range',
			'Gain Momentum',
			'High Volume Up Simple'
		)
		order by a.CreateDate desc

		if object_id(N'Tempdb.dbo.#TempAlertHistoryAggregate') is not null
			drop table #TempAlertHistoryAggregate

		select 
			x1.ASXCode,
			x1.AlertTypeName,
			x1.CreateDate,
			x1.ObservationDate,
			x1.MedianTradeValue,
			x1.MedianTradeValueDaily,
			x1.MedianPriceChangePerc,
			y.AlertTypeScore
		into #TempAlertHistoryAggregate
		from
		(
			select 
				x.ASXCode,
				x.CreateDate,
				x.ObservationDate,
				x.MedianTradeValue,
				x.MedianTradeValueDaily,
				x.MedianPriceChangePerc,
				stuff((
				select ',' + [AlertTypeName]
				from #TempAlertHistory as a
				where x.ASXCode = a.ASXCode
				order by AlertTypeScore desc
				for xml path('')), 1, 1, ''
				) as [AlertTypeName],
				row_number() over (partition by ASXCode order by AlertTypeScore desc) as RowNumber
			from #TempAlertHistory as x
		) as x1
		inner join 
		(
			select ASXCode, sum(AlertTypeScore) as AlertTypeScore
			from #TempAlertHistory 
			group by ASXCode
		) as y
		on x1.ASXCode = y.ASXCode
		where x1.RowNumber = 1
		
		if object_id(N'#TempPriceSummaryStock') is not null
			drop table #TempPriceSummaryStock

		select distinct a.ASXCode 
		into #TempPriceSummaryStock
		from StockData.PriceSummary as a
		where ObservationDate > dateadd(day, -5, getdate())

		select 
			a.[ASXCode],
			substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			isnull(c.SaleDateTime, dateadd(hour, 10, cast(@pdtObservationDate as datetime))) as LastDateTime
		from #TempPriceSummaryStock as a
		left join Transform.CashVsMC as b
		on a.ASXCode = b.ASXCode
		and isnull(MC, 100) < 1000
		left join 
		(
			select ASXCode, max(SaleDateTime) as SaleDateTime
			from StockData.CourseOfSaleSecondary
			where ObservationDate = @pdtObservationDate
			group by ASXCode
		) as c
		on a.ASXCode = c.ASXCode
		where 1 = 1
		--and a.ASXCode = '1MC.AX'
		and not exists
		(
			select 1
			from StockData.CompanyInfo
			where ASXCode = a.ASXCode
			and CleansedMarketCap >= 2000 
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
