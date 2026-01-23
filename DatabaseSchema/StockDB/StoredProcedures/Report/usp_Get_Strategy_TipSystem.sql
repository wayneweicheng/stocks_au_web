-- Stored procedure: [Report].[usp_Get_Strategy_TipSystem]


CREATE PROCEDURE [Report].[usp_Get_Strategy_TipSystem]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_TipSystem.sql
Stored Procedure Name: usp_Get_Strategy_TipSystem
Overview
-----------------
usp_Get_Strategy_TipSystem

Input Parameters
----------------
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
Date:		2021-05-07
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_TipSystem'
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
		declare @dtObservationDate as date 
		if cast(Common.DateAddBusinessDay(0, getdate()) as date) > getdate()
		begin
			select @dtObservationDate = cast(Common.DateAddBusinessDay(-1, getdate()) as date)
		end
		else
		begin
			select @dtObservationDate = cast(Common.DateAddBusinessDay(0, getdate()) as date)
		end

		--select @dtObservationDate
		--select @dtObservationDatePrev1 
		--select @dtObservationDatePrevN 

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

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		select 
			'Tip System' as ReportType,
			a.TipUser,
			a.ASXCode, 
			@dtObservationDate as ObservationDate,
			Recent10dBuyBroker as RecentTopBuyBroker,
			Recent10dSellBroker as RecentTopSellBroker,
			ttsu.FriendlyNameList,
			cast(coalesce(f.SharesIssued*a.[Close]*1.0, g.MC) as decimal(8, 2)) as MC,
			cast(g.CashPosition as decimal(8, 2)) CashPosition,
			a.[Close] as CurrentClose,
			a.PriceChange,
			a.TipDateTime,
			AdditionalNotes
		from (
			select 
				a.TipUser,
				a.ASXCode,
				TipType,
				a.PriceAsAtTip as TipPrice,
				coalesce(b.[Close], c.[Close]) as [Close],
				cast(cast(case when a.PriceAsAtTip > 0 then (coalesce(b.[Close], c.[Close]) - a.PriceAsAtTip)*100.0/a.PriceAsAtTip else null end as decimal(10, 2)) as varchar(50)) + '%' as PriceChange,
				a.TipDateTime,
				AdditionalNotes,
				m2.BrokerCode as Recent10dBuyBroker,
				n2.BrokerCode as Recent10dSellBroker
			from StockData.StockTip as a
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtObservationDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtObservationDate as date)
			and n2.NetBuySell = 'S'
			left join StockData.v_PriceSummary_Latest_Today as b
			on a.ASXCode = b.ASXCode
			left join StockData.PriceHistory as c
			on a.ASXCode = c.ASXCode
			where 1 = 1
			and datediff(day, a.TipDateTime, getdate()) < 365
			and right(a.ASXCode, 3) = '.AX'
			union
			select 
				a.TipUser,
				a.ASXCode,
				TipType,
				a.PriceAsAtTip,
				b.[Close] as CurrentClose,
				cast(cast(case when a.PriceAsAtTip > 0 then (b.[Close] - a.PriceAsAtTip)*100.0/a.PriceAsAtTip else null end as decimal(10, 2)) as varchar(50)) + '%' as PriceChangePerc,
				a.TipDateTime,
					AdditionalNotes,
				null as Recent10dBuyBroker,
				null as Recent10dSellBroker
			from StockData.StockTip as a
			left join StockDB_US.StockData.PriceHistoryCurrent as b
			on a.ASXCode = b.ASXCode
			where 1 = 1
			and datediff(day, a.TipDateTime, getdate()) < 365
			and right(a.ASXCode, 3) = '.US'
		) as a
		left join StockData.v_CompanyFloatingShare as f
		on a.ASXCode = f.ASXCode
		left join #TempCashVsMC as g
		on a.ASXCode = g.ASXCode
		left join StockData.MedianTradeValue as j
		on a.ASXCode = j.ASXCode
		left join [Transform].[BrokerReportList] as m
		on a.ASXCode = m.ASXCode
		and m.LookBackNoDays = 0
		and m.ObservationDate = cast(@dtObservationDate as date)
		and m.NetBuySell = 'B'
		left join [Transform].[BrokerReportList] as n
		on a.ASXCode = n.ASXCode
		and n.LookBackNoDays = 0
		and n.ObservationDate = cast(@dtObservationDate as date)
		and n.NetBuySell = 'S'
		left join [Transform].[BrokerReportList] as m2
		on a.ASXCode = m2.ASXCode
		and m2.LookBackNoDays = 10
		and m2.ObservationDate = cast(@dtObservationDate as date)
		and m2.NetBuySell = 'B'
		left join [Transform].[BrokerReportList] as n2
		on a.ASXCode = n2.ASXCode
		and n2.LookBackNoDays = 10
		and n2.ObservationDate = cast(@dtObservationDate as date)
		and n2.NetBuySell = 'S'
		left join Transform.TTSymbolUser as ttsu
		on a.ASXCode = ttsu.ASXCode
		where 1 = 1
		order by a.TipDateTime desc
		

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