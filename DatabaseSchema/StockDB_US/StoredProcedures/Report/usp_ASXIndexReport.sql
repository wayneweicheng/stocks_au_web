-- Stored procedure: [Report].[usp_ASXIndexReport]


CREATE PROCEDURE [Report].[usp_ASXIndexReport]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_ASXIndexReport.sql
Stored Procedure Name: usp_ASXIndexReport
Overview
-----------------
usp_ASXIndexReport

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
Date:		2018-08-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_ASXIndexReport'
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
		if object_id(N'Tempdb.dbo.#TempXJO') is not null
			drop table #TempXJO

		select *
		into #TempXJO
		from [StockData].[StockStatsHistoryPlus]
		where ASXCode = 'XJO.AX'

		update a
		set a.PrevClose = b.[Close]
		from #TempXJO as a
		inner join #TempXJO as b
		on a.DateSeq = b.DateSeq + 1

		if object_id(N'Tempdb.dbo.#TempXAO') is not null
			drop table #TempXAO

		select *
		into #TempXAO
		from [StockData].[StockStatsHistoryPlus]
		where ASXCode = 'XAO.AX'

		update a
		set a.PrevClose = b.[Close]
		from #TempXAO as a
		inner join #TempXAO as b
		on a.DateSeq = b.DateSeq + 1

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

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *
		into #TempPriceSummary
		from
		(
			select 
				*,
				row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
			from [StockData].[v_PriceSummary]
			where ObservationDate >= dateadd(day, -5, getdate())
		) as a
		where RowNumber = 1

		select *
		from
		(
			select 
				'c. Close vs Last Close' as ReportType,
				XAO.ObservationDate, 
				XAO.PriceChange as XAOPriceChange, 
				XJO.PriceChange as XJOPriceChange, 
				--b.PriceUp, 
				--b.PriceDown, 
				c.PriceUp as PriceUpLargeCap, 
				c.PriceDown as PriceDownLargeCap, 
				d.PriceUp as PriceUpMidCap, 
				d.PriceDown as PriceDownMidCap, 
				e.PriceUp as PriceUpSmallCap, 
				e.PriceDown as PriceDownSmallCap,
				case when XAO.PriceChange > 0 and b.PriceUp < 50 then 'FakeBull'
						when XAO.PriceChange < 0 and b.PriceUp > 50 then 'FakeBear'
						else null
				end as WarningSign
			from
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXAO 
				where ASXCode = 'XAO.AX'
				group by ObservationDate
			) as XAO
			left join
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXJO 
				where ASXCode = 'XJO.AX'
				group by ObservationDate
			) as XJO
			on XAO.ObservationDate = XJO.ObservationDate
			left join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from [StockData].[StockStatsHistoryPlus]
				where [Close] != PrevClose
				group by ObservationDate
			) as b
			on XAO.ObservationDate = b.ObservationDate
			left join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from [StockData].[StockStatsHistoryPlus] as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC > 1000
				)
				group by ObservationDate
			) as c
			on XAO.ObservationDate = c.ObservationDate
			left join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from [StockData].[StockStatsHistoryPlus] as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 300 and 1000
				)
				group by ObservationDate
			) as d
			on XAO.ObservationDate = d.ObservationDate
			left join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from [StockData].[StockStatsHistoryPlus] as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 20 and 300
				)
				group by ObservationDate
			) as e
			on XAO.ObservationDate = e.ObservationDate
			union 
			select 
				'd. Close vs Open' as ReportType,
				XAO.ObservationDate, 
				XAO.PriceChange as XAOPriceChange, 
				XJO.PriceChange as XJOPriceChange, 
				--b.PriceUp, 
				--b.PriceDown, 
				c.PriceUp as PriceUpLargeCap, 
				c.PriceDown as PriceDownLargeCap, 
				d.PriceUp as PriceUpMidCap, 
				d.PriceDown as PriceDownMidCap, 
				e.PriceUp as PriceUpSmallCap, 
				e.PriceDown as PriceDownSmallCap, 
				null as WarningSign
			from
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXAO 
				where ASXCode = 'XAO.AX'
				group by ObservationDate
			) as XAO
			inner join
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXJO 
				where ASXCode = 'XJO.AX'
				group by ObservationDate
			) as XJO
			on XAO.ObservationDate = XJO.ObservationDate
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from [StockData].[StockStatsHistoryPlus]
				where [Close] != PrevClose
				group by ObservationDate
			) as b
			on XAO.ObservationDate = b.ObservationDate
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown 
				from [StockData].[StockStatsHistoryPlus] as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC > 1000
				)
				group by ObservationDate
			) as c
			on XAO.ObservationDate = c.ObservationDate
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown 
				from [StockData].[StockStatsHistoryPlus] as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 300 and 1000
				)
				group by ObservationDate
			) as d
			on XAO.ObservationDate = d.ObservationDate
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from [StockData].[StockStatsHistoryPlus] as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 20 and 300
				)
				group by ObservationDate
			) as e
			on XAO.ObservationDate = e.ObservationDate
			union
			select 
				'a. Close vs Last Close' as ReportType,
				c.ObservationDate, 
				XAO.PriceChange as XAOPriceChange, 
				XJO.PriceChange as XJOPriceChange, 
				--b.PriceUp, 
				--b.PriceDown, 
				c.PriceUp as PriceUpLargeCap, 
				c.PriceDown as PriceDownLargeCap, 
				d.PriceUp as PriceUpMidCap, 
				d.PriceDown as PriceDownMidCap, 
				e.PriceUp as PriceUpSmallCap, 
				e.PriceDown as PriceDownSmallCap,
				null as WarningSign
			from
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from #TempPriceSummary as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC > 1000
				)
				group by ObservationDate
			) as c
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from #TempPriceSummary as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 300 and 1000
				)
				group by ObservationDate
			) as d
			on c.ObservationDate = d.ObservationDate
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from #TempPriceSummary as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 20 and 300
				)
				group by ObservationDate
			) as e
			on c.ObservationDate = e.ObservationDate
			left join
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXAO 
				where ASXCode = 'XAO.AX'
				group by ObservationDate
			) as XAO
			on c.ObservationDate = XAO.ObservationDate
			left join
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXJO 
				where ASXCode = 'XJO.AX'
				group by ObservationDate
			) as XJO
			on c.ObservationDate = XJO.ObservationDate
			union 
			select 
				'b. Close vs Open' as ReportType,
				c.ObservationDate, 
				XAO.PriceChange as XAOPriceChange, 
				XJO.PriceChange as XJOPriceChange, 
				--b.PriceUp, 
				--b.PriceDown, 
				c.PriceUp as PriceUpLargeCap, 
				c.PriceDown as PriceDownLargeCap, 
				d.PriceUp as PriceUpMidCap, 
				d.PriceDown as PriceDownMidCap, 
				e.PriceUp as PriceUpSmallCap, 
				e.PriceDown as PriceDownSmallCap,
				null as WarningSign
			from
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from #TempPriceSummary as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC > 1000
				)
				group by ObservationDate
			) as c
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from #TempPriceSummary as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 300 and 1000
				)
				group by ObservationDate
			) as d
			on c.ObservationDate = d.ObservationDate
			inner join 
			(
				select ObservationDate,
					cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
					cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
				from #TempPriceSummary as a
				where [Close] != PrevClose
				and exists
				(
					select 1
					from #TempCashVsMC
					where ASXCode = a.ASXCode
					and MC between 20 and 300
				)
				group by ObservationDate
			) as e
			on c.ObservationDate = e.ObservationDate
			left join
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXAO 
				where ASXCode = 'XAO.AX'
				group by ObservationDate
			) as XAO
			on c.ObservationDate = XAO.ObservationDate
			left join
			(
				select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
				from #TempXJO 
				where ASXCode = 'XJO.AX'
				group by ObservationDate
			) as XJO
			on c.ObservationDate = XJO.ObservationDate
		) as x
		order by x.ObservationDate desc, x.ReportType

		--if @pvchReportType = 'Previous History'
		--begin

		--end

		--if @pvchReportType = 'Current Index'
		--begin
			
		--	select *
		--	from
		--	(
		--		select 
		--			'a. Close vs Last Close' as ReportType,
		--			XAO.ObservationDate, 
		--			XAO.PriceChange as XAOPriceChange, 
		--			XJO.PriceChange as XJOPriceChange, 
		--			--b.PriceUp, 
		--			--b.PriceDown, 
		--			c.PriceUp as PriceUpLargeCap, 
		--			c.PriceDown as PriceDownLargeCap, 
		--			d.PriceUp as PriceUpMidCap, 
		--			d.PriceDown as PriceDownMidCap, 
		--			e.PriceUp as PriceUpSmallCap, 
		--			e.PriceDown as PriceDownSmallCap,
		--			case when XAO.PriceChange > 0 and b.PriceUp < 50 then 'FakeBull'
		--				 when XAO.PriceChange < 0 and b.PriceUp > 50 then 'FakeBear'
		--				 else null
		--			end as WarningSign
		--		from
		--		(
		--			select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
		--			from #TempXAO 
		--			where ASXCode = 'XAO.AX'
		--			group by ObservationDate
		--		) as XAO
		--		inner join
		--		(
		--			select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
		--			from #TempXJO 
		--			where ASXCode = 'XJO.AX'
		--			group by ObservationDate
		--		) as XJO
		--		on XAO.ObservationDate = XJO.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
		--			from #TempPriceSummary
		--			where [Close] != PrevClose
		--			group by ObservationDate
		--		) as b
		--		on XAO.ObservationDate = b.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
		--			from #TempPriceSummary as a
		--			where [Close] != PrevClose
		--			and exists
		--			(
		--				select 1
		--				from #TempCashVsMC
		--				where ASXCode = a.ASXCode
		--				and MC > 1000
		--			)
		--			group by ObservationDate
		--		) as c
		--		on XAO.ObservationDate = c.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
		--			from #TempPriceSummary as a
		--			where [Close] != PrevClose
		--			and exists
		--			(
		--				select 1
		--				from #TempCashVsMC
		--				where ASXCode = a.ASXCode
		--				and MC between 300 and 1000
		--			)
		--			group by ObservationDate
		--		) as d
		--		on XAO.ObservationDate = d.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > PrevClose then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > PrevClose then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
		--			from #TempPriceSummary as a
		--			where [Close] != PrevClose
		--			and exists
		--			(
		--				select 1
		--				from #TempCashVsMC
		--				where ASXCode = a.ASXCode
		--				and MC between 20 and 300
		--			)
		--			group by ObservationDate
		--		) as e
		--		on XAO.ObservationDate = e.ObservationDate
		--		union 
		--		select 
		--			'b. Close vs Open' as ReportType,
		--			XAO.ObservationDate, 
		--			XAO.PriceChange as XAOPriceChange, 
		--			XJO.PriceChange as XJOPriceChange, 
		--			--b.PriceUp, 
		--			--b.PriceDown, 
		--			c.PriceUp as PriceUpLargeCap, 
		--			c.PriceDown as PriceDownLargeCap, 
		--			d.PriceUp as PriceUpMidCap, 
		--			d.PriceDown as PriceDownMidCap, 
		--			e.PriceUp as PriceUpSmallCap, 
		--			e.PriceDown as PriceDownSmallCap, 
		--			case when XAO.PriceChange > 0 and b.PriceUp < 50 then 'FakeBull'
		--				 when XAO.PriceChange < 0 and b.PriceUp > 50 then 'FakeBear'
		--				 else null
		--			end as WarningSign
		--		from
		--		(
		--			select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
		--			from #TempXAO 
		--			where ASXCode = 'XAO.AX'
		--			group by ObservationDate
		--		) as XAO
		--		inner join
		--		(
		--			select ObservationDate, cast(avg(([Close] - [PrevClose])*100.0/PrevClose) as decimal(10, 2)) as PriceChange
		--			from #TempXJO 
		--			where ASXCode = 'XJO.AX'
		--			group by ObservationDate
		--		) as XJO
		--		on XAO.ObservationDate = XJO.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
		--			from #TempPriceSummary
		--			where [Close] != PrevClose
		--			group by ObservationDate
		--		) as b
		--		on XAO.ObservationDate = b.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown 
		--			from #TempPriceSummary as a
		--			where [Close] != PrevClose
		--			and exists
		--			(
		--				select 1
		--				from #TempCashVsMC
		--				where ASXCode = a.ASXCode
		--				and MC > 1000
		--			)
		--			group by ObservationDate
		--		) as c
		--		on XAO.ObservationDate = c.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown 
		--			from #TempPriceSummary as a
		--			where [Close] != PrevClose
		--			and exists
		--			(
		--				select 1
		--				from #TempCashVsMC
		--				where ASXCode = a.ASXCode
		--				and MC between 300 and 1000
		--			)
		--			group by ObservationDate
		--		) as d
		--		on XAO.ObservationDate = d.ObservationDate
		--		inner join 
		--		(
		--			select ObservationDate,
		--				cast(sum(case when [Close] > [Open] then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUp, 
		--				cast(sum(case when [Close] > [Open] then 0 else 1 end)*100.0/count(*) as decimal(10, 2)) as PriceDown
		--			from #TempPriceSummary as a
		--			where [Close] != PrevClose
		--			and exists
		--			(
		--				select 1
		--				from #TempCashVsMC
		--				where ASXCode = a.ASXCode
		--				and MC between 20 and 300
		--			)
		--			group by ObservationDate
		--		) as e
		--		on XAO.ObservationDate = e.ObservationDate
		--	) as x
		--	order by x.ObservationDate desc, x.ReportType
		--end


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
