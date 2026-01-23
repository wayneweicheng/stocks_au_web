-- Stored procedure: [DataMaintenance].[usp_RefreshTransformDailyInstituteBuySell]


CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformDailyInstituteBuySell]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_RefreshScanResultStatsHistory.sql
Stored Procedure Name: usp_RefreshScanResultStatsHistory
Overview
-----------------
usp_RefreshScanResultStatsHistory

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
Date:		2020-02-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformDailyInstituteBuySell'
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
		--declare @pintNumPrevDay as int = 0
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 0, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempCourseOfSaleSecondary') is not null
			drop table #TempCourseOfSaleSecondary

		select *
		into #TempCourseOfSaleSecondary
		from StockData.CourseOfSaleSecondary with(nolock)
		where 1 = 1
		and 
		(
			ObservationDate >= @dtObservationDatePrevN
			and
			ObservationDate <= @dtObservationDate
		)

		if object_id(N'Tempdb.dbo.#TempDerivedInstitutePerformance') is not null
			drop table #TempDerivedInstitutePerformance

		select 
			x.*,
			x.Quantity*100.0/y.Quantity as QuantityPerc,
			x.TradeValue*100.0/y.TradeValue as TradeValuePerc,
			isnull(c.PriceChangeVsPrevClose, d.PriceChangeVsPrevClose) as PriceChangeVsPrevClose,
			isnull(c.PriceChangeVsOpen, d.PriceChangeVsOpen) as PriceChangeVsOpen
		into #TempDerivedInstitutePerformance
		from
		(
			select 
				a.ASXCode,
				cast(SaleDateTime as date) as ObservationDate,
				isnull(DerivedInstitute, 0) as DerivedInstitute,
				a.ActBuySellInd, 
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from #TempCourseOfSaleSecondary as a
			where 1 = 1
			and ActBuySellInd is not null
			group by a.ASXCode, cast(SaleDateTime as date), isnull(DerivedInstitute, 0), a.ActBuySellInd
		) as x
		inner join
		(
			select 
				a.ASXCode, 
				cast(SaleDateTime as date) as ObservationDate,
				isnull(DerivedInstitute, 0) as DerivedInstitute,
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from #TempCourseOfSaleSecondary as a
			where 1 = 1
			and ActBuySellInd is not null
			group by a.ASXCode, cast(SaleDateTime as date), isnull(DerivedInstitute, 0)
		) as y
		on x.DerivedInstitute = y.DerivedInstitute
		and x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		left join Transform.PriceHistory as c with(nolock)
		on x.ASXCode = c.ASXCode
		and c.ObservationDate = x.ObservationDate
		left join [StockData].[v_PriceSummary_Latest_Today] as d
		on x.ASXCode = d.ASXCode
		and x.ObservationDate = d.ObservationDate
		order by x.ASXCode, x.ObservationDate, isnull(x.DerivedInstitute, 0), x.ActBuySellInd;

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a with(nolock)
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

		if object_id(N'Tempdb.dbo.#TempInstitutePerc') is not null
			drop table #TempInstitutePerc

		select 
			x.ObservationDate,
			x.ASXCode as ASXCode,
			isnull(DerivedInstitute, 0) as DerivedInstitute, 
			x.VWAP as VWAP,
			format(x.Quantity, 'N0') as Quantity, 
			format(x.TradeValue, 'N0') as TradeValue,
			x.Quantity*100.0/y.Quantity as QuantityPerc,
			x.TradeValue*100.0/y.TradeValue as TradeValuePerc,
			c.PriceChangeVsPrevClose,
			c.PriceChangeVsOpen
		into #TempInstitutePerc
		from
		(
			select 
				a.ASXCode,
				ObservationDate as ObservationDate,
				isnull(DerivedInstitute, 0) as DerivedInstitute, 
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from #TempCourseOfSaleSecondary as a with(nolock)
			where 1 = 1
			group by a.ASXCode, isnull(DerivedInstitute, 0), a.ObservationDate
		) as x
		inner join
		(
			select
				a.ASXCode,
				a.ObservationDate as ObservationDate,
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from #TempCourseOfSaleSecondary as a with(nolock)
			where 1 = 1
			group by a.ASXCode, a.ObservationDate
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		left join Transform.PriceHistory as c with(nolock)
		on x.ASXCode = c.ASXCode
		and x.ObservationDate = c.ObservationDate
		and 
		(
			c.ObservationDate >= @dtObservationDatePrevN
			and
			c.ObservationDate <= @dtObservationDate
		)
		where x.DerivedInstitute = 1
		order by x.ObservationDate desc, x.DerivedInstitute;

		if object_id(N'Tempdb.dbo.#TempInstitutePercRank') is not null
			drop table #TempInstitutePercRank

		select 
			*, 
			row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber,
			avg(TradeValuePerc) over (partition by ASXCode order by ObservationDate asc rows 9 preceding) as AvgTradeValuePerc
		into #TempInstitutePercRank
		from #TempInstitutePerc

		if object_id(N'Tempdb.dbo.#TempInstituteMarketParticipation') is not null
			drop table #TempInstituteMarketParticipation
		
		select a.*, b.TradeValuePerc as InstituteBuyPerc, b.VWAP as InstituteBuyVWAP, c.TradeValuePerc as RetailBuyPerc, c.VWAP as RetailBuyVWAP
		into #TempInstituteMarketParticipation
		from #TempInstitutePercRank as a
		left join #TempDerivedInstitutePerformance as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and b.ActBuySellInd = 'B'
		and b.DerivedInstitute = 1
		left join #TempDerivedInstitutePerformance as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and c.ActBuySellInd = 'B'
		and c.DerivedInstitute = 0
		where 1 = 1
		order by a.ObservationDate desc;

		if object_id(N'Tempdb.dbo.#TempDailyInstituteBuySell') is not null
			drop table #TempDailyInstituteBuySell

		select distinct
			'Derived Institute Performance' as ReportType,
			a.DerivedInstitute,
			a.ASXCode,
			a.ObservationDate,
			a.Quantity,
			x.TradeValue as InstituteTradeValue,
			--x.QuantityPerc as InstituteQuantityPerc,
			format(x.TradeValuePerc, 'N1') as InstituteTradeValuePerc,
			cast(null as decimal(10, 2)) as AvgTradeValuePerc,
			a.PriceChangeVsPrevClose,
			a.PriceChangeVsOpen,
			case when a.VWAP > b.VWAP then 1 else 0 end as VWAPStrength,
			x.InstituteBuyPerc,
			x.RetailBuyPerc,
			x.InstituteBuyVWAP,
			x.RetailBuyVWAP,
			--'|' as Divider,
			--y.TotalVWAP,
			--y.ChixVWAP,
			--y.ASXVWAP,
			--y.CHIXPerc,
			--y.AvgCHIXPerc,
			--y.TotalValue,
			m2.BrokerCode as RecentTopBuyBroker,
			n2.BrokerCode as RecentTopSellBroker,
			ttsu.FriendlyNameList
		into #TempDailyInstituteBuySell
		from #TempDerivedInstitutePerformance as a
		inner join #TempDerivedInstitutePerformance as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.DerivedInstitute = 1
		and b.DerivedInstitute = 0
		and a.ActBuySellInd = 'B'
		and b.ActBuySellInd = 'B'
		left join StockData.StockStatsHistoryPlus as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		left join StockData.StockStatsHistoryPlus as d
		on a.ASXCode = d.ASXCode
		and c.DateSeqReverse + 1 = d.DateSeqReverse
		left join #TempBrokerReportListLastNDay as m2
		on a.ASXCode = m2.ASXCode
		left join #TempBrokerReportListNegLastNDay as n2
		on a.ASXCode = n2.ASXCode
		left join Transform.TTSymbolUser as ttsu
		on a.ASXCode = ttsu.ASXCode
		left join #TempInstituteMarketParticipation as x
		on a.ASXCode = x.ASXCode
		and a.ObservationDate = x.ObservationDate
		left join Transform.CHIXVolumeAndVWAP as y
		on a.ASXCode = y.ASXCode
		and a.ObservationDate = y.ObservationDate
		where 1 = 1
		
		delete a
		from Transform.DailyInstituteBuySell as a
		inner join #TempDailyInstituteBuySell as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		--drop table Transform.DailyInstituteBuySell

		--select *
		--into Transform.DailyInstituteBuySell
		--from #TempDailyInstituteBuySell

		insert into Transform.DailyInstituteBuySell
		select * 
		from #TempDailyInstituteBuySell

		update a
		set AvgTradeValuePerc = b.AvgTradeValuePerc
		from Transform.DailyInstituteBuySell as a
		inner join
		(
			select
			ASXCode,
			ObservationDate,
			avg(cast(a.InstituteTradeValuePerc as decimal(10, 2))) over (partition by ASXCode order by ObservationDate asc rows 9 preceding) as AvgTradeValuePerc
			from Transform.DailyInstituteBuySell as a
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate


	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
