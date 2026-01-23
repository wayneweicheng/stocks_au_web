-- Stored procedure: [Report].[usp_Get_Strategy_ChiXVolumeSurge]


CREATE PROCEDURE [Report].[usp_Get_Strategy_ChiXVolumeSurge]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_ChiXVolumeSurge.sql
Stored Procedure Name: usp_Get_Strategy_ChiXVolumeSurge
Overview
-----------------
usp_Get_Strategy_ChiXVolumeSurge

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
Date:		2021-03-23
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_ChiXVolumeSurge'
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
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 2, getdate()) as date)
		declare @dtObservationDatePrevNMinur60 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 62, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempChixAnalysisRaw') is not null
			drop table #TempChixAnalysisRaw

		select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
		into #TempChixAnalysisRaw
		from
		(
			select 
				a.ASXCode, 
				cast(a.ObservationDate as varchar(50)) as ObservationDate, 
				a.[Close], 
				a.VWAP as TotalVWAP,
				null as ChiXvwap,
				b.VWAP as ASXVWAP,
				format(a.Volume, 'N0') as TotalVolume, 
				format(b.Volume, 'N0') as ASXVolume, 
				format(a.VWAP*a.Volume, 'N0') as TotalValue,
				format(b.[Value], 'N0') as ASXValue,
				b.PriceChangeVsPrevClose, 
				b.PriceChangeVsOpen, 
				cast((a.Volume - b.Volume)*100.0/a.Volume as decimal(10, 2)) as CHIXPerc,
				avg(cast((a.Volume - b.Volume)*100.0/a.Volume as decimal(10, 2))) over (partition by a.ASXCode order by a.ObservationDate asc rows 9 preceding) as AvgCHIXPerc
				--c.AnnDescr
			from StockData.PriceHistorySecondary as a
			inner join Transform.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where 1 = 1
			and a.Exchange = 'SMART'
			and a.Volume > b.Volume
			and a.Volume > 0
			and b.Volume > 0
			and a.ObservationDate >= @dtObservationDatePrevNMinur60
			and a.ObservationDate <= @dtObservationDate
		) as x
		order by x.ObservationDate desc;

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate >= Common.DateAddBusinessDay(-8, getdate())
		and ObservationDate <= getdate()
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

		if @pbitASXCodeOnly = 0
		begin
			select 
				'ChiX Analysis' as ReportType,
				d.AvgCHIXPerc, 
				a.ASXCode, 
				o.ObservationDate,
				a.NumHighVolume, 
				--b.NumHighVWAP,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				ttsu.FriendlyNameList,
				c.[MC],
				c.[CashPosition],
				c.[AnnDateTime],
				c.[ASXCode],
				c.[FloatingShares],
				c.[FloatingSharesPerc],
				c.[SharesIssued],
				c.[IndustrySubGroup],
				c.[LastValidateDate],
				c.[Close]
			from
			(
				select ASXCode, count(*) as NumHighVolume
				from #TempChixAnalysisRaw as a
				where RowNumber <= 5
				and CHIXPerc > AvgCHIXPerc*1.1
				group by ASXCode
				having count(*) >= 3
			) as a
			--inner join
			--(
			--	select ASXCode, count(*) as NumHighVWAP
			--	from #TempChixAnalysisRaw as a
			--	where RowNumber < 10
			--	and TotalVWAP > ASXVWAP
			--	group by ASXCode
			--	having count(*) > 2
			--) as b
			--on a.ASXCode = b.ASXCode
			inner join Transform.StockMCAndCashPosition as c
			on a.ASXCode = c.ASXCode
			inner join #TempChixAnalysisRaw as d
			on a.ASXCode = d.ASXCode
			and d.RowNumber = 1
			inner join
			(
				select ASXCode, max(ObservationDate) as ObservationDate
				from #TempChixAnalysisRaw
				group by ASXCode
			) as o
			on a.ASXCode = o.ASXCode
			left join #TempBrokerReportListLastNDay as m2
			on a.ASXCode = m2.ASXCode
			left join #TempBrokerReportListNegLastNDay as n2
			on a.ASXCode = n2.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			left join StockData.StockStatsHistoryPlus as x
			on a.ASXCode = x.ASXCode
			and x.DateSeqReverse = 2
			left join StockData.StockStatsHistoryPlus as y
			on a.ASXCode = y.ASXCode
			and y.DateSeqReverse = 3
			where 1 = 1
			and isnull(c.MC, 100) < 1000
			and d.AvgCHIXPerc > 15
			--and a.ASXCode = 'AIS.AX'
			--and x.MovingAverage10d >= y.MovingAverage10d
			and cast(replace(d.TotalValue, ',', '') as int) > 50000
			and o.ObservationDate >= @dtObservationDatePrevN
			and o.ObservationDate <= @dtObservationDate
			order by MC asc;

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
					'ChiX Analysis' as ReportType,
					d.AvgCHIXPerc, 
					a.ASXCode, 
					o.ObservationDate,
					a.NumHighVolume, 
					--b.NumHighVWAP,
					m2.BrokerCode as RecentTopBuyBroker,
					n2.BrokerCode as RecentTopSellBroker,
					ttsu.FriendlyNameList,
					c.[MC],
					c.[CashPosition],
					c.[AnnDateTime],
					c.[FloatingShares],
					c.[FloatingSharesPerc],
					c.[SharesIssued],
					c.[IndustrySubGroup],
					c.[LastValidateDate],
					c.[Close]
				from
				(
					select ASXCode, count(*) as NumHighVolume
					from #TempChixAnalysisRaw as a
					where RowNumber <= 5
					and CHIXPerc > AvgCHIXPerc*1.1
					group by ASXCode
					having count(*) >= 3
				) as a
				--inner join
				--(
				--	select ASXCode, count(*) as NumHighVWAP
				--	from #TempChixAnalysisRaw as a
				--	where RowNumber < 10
				--	and TotalVWAP > ASXVWAP
				--	group by ASXCode
				--	having count(*) > 2
				--) as b
				--on a.ASXCode = b.ASXCode
				inner join Transform.StockMCAndCashPosition as c
				on a.ASXCode = c.ASXCode
				inner join #TempChixAnalysisRaw as d
				on a.ASXCode = d.ASXCode
				and d.RowNumber = 1
				inner join
				(
					select ASXCode, max(ObservationDate) as ObservationDate
					from #TempChixAnalysisRaw
					group by ASXCode
				) as o
				on a.ASXCode = o.ASXCode
				left join #TempBrokerReportListLastNDay as m2
				on a.ASXCode = m2.ASXCode
				left join #TempBrokerReportListNegLastNDay as n2
				on a.ASXCode = n2.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on a.ASXCode = ttsu.ASXCode
				left join StockData.StockStatsHistoryPlus as x
				on a.ASXCode = x.ASXCode
				and x.DateSeqReverse = 2
				left join StockData.StockStatsHistoryPlus as y
				on a.ASXCode = y.ASXCode
				and y.DateSeqReverse = 3
				where 1 = 1
				and isnull(c.MC, 100) < 1000
				and d.AvgCHIXPerc > 15
				--and a.ASXCode = 'AIS.AX'
				--and x.MovingAverage10d >= y.MovingAverage10d
				and cast(replace(d.TotalValue, ',', '') as int) > 50000
				and o.ObservationDate >= @dtObservationDatePrevN
				and o.ObservationDate <= @dtObservationDate
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