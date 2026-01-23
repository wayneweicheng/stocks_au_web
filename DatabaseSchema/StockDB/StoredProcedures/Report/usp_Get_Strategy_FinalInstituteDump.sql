-- Stored procedure: [Report].[usp_Get_Strategy_FinalInstituteDump]


CREATE PROCEDURE [Report].[usp_Get_Strategy_FinalInstituteDump]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_FinalInstituteDump.sql
Stored Procedure Name: usp_Get_Strategy_FinalInstituteDump
Overview
-----------------
usp_Get_Strategy_AdvancedFRCS

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
Date:		2021-07-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_FinalInstituteDump'
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
		--declare @pintNumPrevDay as int = 0

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 3, getdate()) as date)

		--select @dtObservationDate
		--select @dtObservationDatePrev1 
		--select @dtObservationDatePrevN 

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate >= Common.DateAddBusinessDay(-8, @dtObservationDate)
		and ObservationDate <= @dtObservationDate
		group by ASXCode, b.DisplayBrokerCode

		if object_id(N'Tempdb.dbo.#TempBrokerReportListLastNDay') is not null
			drop table #TempBrokerReportListLastNDay

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListLastNDay
		from #TempBRAggregateLastNDay as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNegLastNDay') is not null
			drop table #TempBrokerReportListNegLastNDay

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNegLastNDay
		from #TempBRAggregateLastNDay as x

		if object_id(N'Tempdb.dbo.#TempBrokerDataSell') is not null
			drop table #TempBrokerDataSell

		select *
		into #TempBrokerDataSell
		from
		(
			select 
				BrokerCode,
				ASXCode,
				avg(BuyPrice) as BuyPrice,
				avg(SellPrice) as SellPrice,
				sum(NetValue) as NetValue,
				sum(NetVolume) as NetVolume,
				@dtObservationDate as ObservationDate,
				row_number() over (partition by ASXCode order by sum(NetVolume) asc) as RowNumber
			from StockData.BrokerReport
			where ObservationDate = @dtObservationDate
			and SellPrice > 0
			group by 
				BrokerCode,
				ASXCode
		) as x
		where x.RowNumber in (1)
		--and BrokerCode in ('ArgSec', 'BelPot', 'EurSec', 'Macqua', 'PerShn', 'CreSui', 'HarLim', 'InsAus', 'MorgFn', 'IntBro')

		if object_id(N'Tempdb.dbo.#TempBrokerDataBuy') is not null
			drop table #TempBrokerDataBuy

		select *
		into #TempBrokerDataBuy
		from
		(
			select 
				BrokerCode,
				ASXCode,
				avg(BuyPrice) as BuyPrice,
				avg(SellPrice) as SellPrice,
				sum(NetValue) as NetValue,
				sum(NetVolume) as NetVolume,
				@dtObservationDate as ObservationDate,
				row_number() over (partition by ASXCode order by sum(NetVolume) desc) as RowNumber
			from StockData.BrokerReport
			where ObservationDate = @dtObservationDate
			and BuyPrice > 0
			group by 
				BrokerCode,
				ASXCode
		) as x
		where x.RowNumber in (1)

		if @pbitASXCodeOnly = 0
		begin
			select 
				'Final Institute Dump' as ReportType, 
				a.BrokerCode, 
				a.ASXCode, 
				@dtObservationDate as ObservationDate,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				ttsu.FriendlyNameList,
				MC,
				CashPosition,
				cast(j.MedianTradeValue as int) as [MedianValue Wk],
				cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
				a.NetValue,
				a.NetVolume,
				AvgNetVolume
			from #TempBrokerDataSell as a
			inner join [Transform].[v_PriceHistoryNetVolume] as b
			on a.ASXCode = b.ASXCode
			and b.ObservationDate = @dtObservationDate
			inner join StockData.PriceHistory as c
			on a.ASXCode = c.ASXCode
			and c.ObservationDate = @dtObservationDate
			and c.Volume > 0
			inner join Transform.CashVsMC as d
			on a.ASXCode = d.ASXCode
			inner join #TempBrokerDataBuy as e
			on a.ASXCode = e.ASXCode
			and a.ObservationDate = e.ObservationDate
			left join #TempBrokerReportListLastNDay as m2
			on a.ASXCode = m2.ASXCode
			left join #TempBrokerReportListNegLastNDay as n2
			on a.ASXCode = n2.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			left join StockData.MedianTradeValue as j
			on a.ASXCode = j.ASXCode
			where 1 = 1
			and abs(a.NetVolume) > 2*b.AvgNetVolume
			and abs(a.NetValue) > 80000
			and not exists
			(
				select 1
				from #TempBrokerDataBuy as x
				inner join LookupRef.BrokerName as y
				on x.BrokerCode = y.BrokerCode
				where x.ASXCode = a.ASXCode
				and y.BrokerScore <= 0.50
			)
			order by abs(a.NetVolume)*1.0/b.AvgNetVolume desc
		end
		else
		begin
			--print 'skip'
			
			if object_id(N'Tempdb.dbo.#TempOutput') is not null
				drop table #TempOutput

			select 
			identity(int, 1, 1) as DisplayOrder,
			*
			into #TempOutput
			from
			(
				select 
					'Final Institute Dump' as ReportType, 
					a.BrokerCode, 
					a.ASXCode, 
					@dtObservationDate as ObservationDate,
					m2.BrokerCode as RecentTopBuyBroker,
					n2.BrokerCode as RecentTopSellBroker,
					ttsu.FriendlyNameList,
					MC,
					CashPosition,
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day],
					a.NetValue,
					a.NetVolume,
					AvgNetVolume
				from #TempBrokerDataSell as a
				inner join [Transform].[v_PriceHistoryNetVolume] as b
				on a.ASXCode = b.ASXCode
				and b.ObservationDate = @dtObservationDate
				inner join StockData.PriceHistory as c
				on a.ASXCode = c.ASXCode
				and c.ObservationDate = @dtObservationDate
				and c.Volume > 0
				inner join Transform.CashVsMC as d
				on a.ASXCode = d.ASXCode
				inner join #TempBrokerDataBuy as e
				on a.ASXCode = e.ASXCode
				and a.ObservationDate = e.ObservationDate
				left join #TempBrokerReportListLastNDay as m2
				on a.ASXCode = m2.ASXCode
				left join #TempBrokerReportListNegLastNDay as n2
				on a.ASXCode = n2.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on a.ASXCode = ttsu.ASXCode
				left join StockData.MedianTradeValue as j
				on a.ASXCode = j.ASXCode
				where 1 = 1
				and abs(a.NetVolume) > 2*b.AvgNetVolume
				and abs(a.NetValue) > 80000
				and not exists
				(
					select 1
					from #TempBrokerDataBuy as x
					inner join LookupRef.BrokerName as y
					on x.BrokerCode = y.BrokerCode
					where x.ASXCode = a.ASXCode
					and y.BrokerScore <= 0.50
				)
			) as x
			order by ASXCode desc;
			
			select
				distinct
				ASXCode,
				DisplayOrder,
				ObservationDate,
				OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) as ReportProc
			from #TempOutput

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