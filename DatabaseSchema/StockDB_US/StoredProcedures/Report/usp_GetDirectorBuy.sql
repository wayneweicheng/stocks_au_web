-- Stored procedure: [Report].[usp_GetDirectorBuy]


CREATE PROCEDURE [Report].[usp_GetDirectorBuy]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0,
@pvchSortBy as varchar(50) = 'Ann DateTime'
AS
/******************************************************************************
File: usp_GetStockAnnouncement.sql
Stored Procedure Name: usp_GetStockAnnouncement
Overview
-----------------
usp_GetStockScreening

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
Date:		2018-02-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetDirectorBuy'
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
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempDirectorCurrent') is not null
			drop table #TempDirectorCurrent

		select a.ASXCode, stuff((
			select ',' + [Name]
			from StockData.DirectorCurrent
			where ASXCode = a.ASXCode
			order by Surname desc
			for xml path('')), 1, 1, ''
		) as DirName
		into #TempDirectorCurrent
		from StockData.DirectorCurrent as a
		group by a.ASXCode

		if object_id(N'Tempdb.dbo.#TempDirBuy') is not null
			drop table #TempDirBuy

		--select distinct
		--c.ASXCode,
		--e.CleansedMarketCap, 
		--DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Value/Consideration.{0,180})[$0-9\,\.]+(?=\s{0,10}(\(.{0,80}\)){0,1}\s{0,10}(Appendix|No\. of securities))') as ValueConsideration, 
		--DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Value/Consideration.{0,180})[$0-9\,\.]+(?=\s{0,10}(\(.{0,80}\)){0,1}\s{0,10}(per.{0,20}share|per.{0,20}stock))') as ValueConsiderationPerShare,
		--DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Number acquired\s{0,5})[0-9\,]+(?=\s{0,10}.{0,30}Number disposed)') as NumAcquired,
		--DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Number disposed\s{0,5})[0-9\,]+(?=\s{0,10}.{0,30}Value/Consideration)') as NumDisposed,
		--d.AnnDescr,
		--d.AnnDateTime
		--into #TempDirBuy
		--from StockData.Announcement as c
		--inner join StockData.Announcement as d
		--on c.ASXCode = d.ASXCode
		--and c.AnnDescr in ('Becoming a substantial holder', 'Change in substantial holding')
		--and d.AnnDescr like ('Change of Director% Notice%')
		--and 
		--(
		--	DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<!Example:\s)on[-\s]market (trade|purchase|buy|acquire)') is not null
		--	or
		--	DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<!Example:\s)on[-\s]market') is not null
		--)
		--and datediff(day, c.AnnDateTime, getdate()) < 180
		--and abs(datediff(day, c.AnnDateTime, d.AnnDateTime)) < 90
		----and not try_cast(DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Number disposed\s{0,5})[0-9\,]+(?=\s{0,10}.{0,30}Value/Consideration)') as decimal(10, 2)) > 0
		--inner join StockData.CompanyInfo as e
		--on d.ASXCode = e.ASXCode

		select *
		into #TempDirBuy
		from StockData.DirectorBuyOnMarket

		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrev1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -1, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null 
			drop table #TempPriceSummary

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDate
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempPriceSummaryPrev1') is not null 
			drop table #TempPriceSummaryPrev1

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummaryPrev1
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDatePrev1
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ASXCode, BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate between cast(Common.DateAddBusinessDay(-13, @dtObservationDate) as date) and cast(Common.DateAddBusinessDay(-3, @dtObservationDate) as date)
		group by ASXCode, BrokerCode

		if object_id(N'Tempdb.dbo.#TempBrokerReportList') is not null
			drop table #TempBrokerReportList

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregate as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportList
		from #TempBRAggregate as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNeg') is not null
			drop table #TempBrokerReportListNeg

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregate as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNeg
		from #TempBRAggregate as x
		
		if @pvchSortBy = 'Ann DateTime'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				ValueConsideration, 
				ValueConsiderationPerShare,
				NumAcquired,
				NumDisposed,
				case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
				case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
				cast(d.IndustrySubGroup as varchar(100)) as IndustrySubGroup,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				g.DirName
			from #TempDirBuy as x
			inner join 
			(
				select ASXCode, max(AnnDateTime) as AnnDateTime
				from #TempDirBuy
				group by ASXCode
			) as y
			on x.ASXCode = y.ASXCode
			left join #TempCashVsMC as c
			on x.ASXCode = c.ASXCode
			left join StockData.CompanyInfo as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join Transform.PosterList as f
			on x.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on x.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join #TempBrokerReportList as m
			on x.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on x.ASXCode = n.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as s
			on x.ASXCode = s.ASXCode
			--order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
			where isnull(cast(c.MC as decimal(8, 2)), 5) < 500
			order by y.AnnDateTime desc, x.ASXCode, x.AnnDateTime desc

		end

		if @pvchSortBy = 'Market Cap'
		begin
			select top 500
				x.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				x.AnnDescr,
				x.AnnDateTime,
				ValueConsideration, 
				ValueConsiderationPerShare,
				NumAcquired,
				NumDisposed,
				case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
				case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
				cast(d.IndustrySubGroup as varchar(100)) as IndustrySubGroup,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker,
				g.DirName
			from #TempDirBuy as x
			inner join 
			(
				select ASXCode, max(AnnDateTime) as AnnDateTime
				from #TempDirBuy
				group by ASXCode
			) as y
			on x.ASXCode = y.ASXCode
			left join #TempCashVsMC as c
			on x.ASXCode = c.ASXCode
			left join StockData.CompanyInfo as d
			on x.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on x.ASXCode = e.ASXCode
			left join Transform.PosterList as f
			on x.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on x.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on x.ASXCode = h.ASXCode
			left join #TempBrokerReportList as m
			on x.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on x.ASXCode = n.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as s
			on x.ASXCode = s.ASXCode
			--order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
			where isnull(cast(c.MC as decimal(8, 2)), 5) < 500
			order by isnull(c.MC, 99999) asc
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
