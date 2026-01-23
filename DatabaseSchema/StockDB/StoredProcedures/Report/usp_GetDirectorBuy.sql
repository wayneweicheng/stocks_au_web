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
		
		if @pvchSortBy = 'Ann DateTime'
		begin
			select top 500 *
			from
			(
				select distinct
					x.ASXCode,
					cast(c.MC as decimal(8, 2)) as MC,
					cast(c.CashPosition as decimal(8, 2)) CashPosition,
					x.AnnDescr,
					x.AnnDateTime,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker,
					ValueConsideration, 
					ValueConsiderationPerShare,
					NumAcquired,
					NumDisposed,
					case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
					case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
					cast(d.IndustrySubGroup as varchar(100)) as IndustrySubGroup,
					g.DirName
				from #TempDirBuy as x
				inner join 
				(
					select ASXCode, max(AnnDateTime) as AnnDateTime
					from #TempDirBuy
					group by ASXCode
				) as y
				on x.ASXCode = y.ASXCode
				left join Transform.CashVsMC as c
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
				left join [Transform].[BrokerReportList] as m
				on x.ASXCode = m.ASXCode
				and m.LookBackNoDays = 0
				and m.ObservationDate = @dtObservationDate
				and m.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n
				on x.ASXCode = n.ASXCode
				and n.LookBackNoDays = 0
				and n.ObservationDate = @dtObservationDate
				and n.NetBuySell = 'S'
				left join [Transform].[BrokerReportList] as m2
				on x.ASXCode = m2.ASXCode
				and m2.LookBackNoDays = 10
				and m2.ObservationDate = @dtObservationDate
				and m2.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n2
				on x.ASXCode = n2.ASXCode
				and n2.LookBackNoDays = 10
				and n2.ObservationDate = @dtObservationDate
				and n2.NetBuySell = 'S'
				left join StockData.StockStatsHistoryPlusCurrent as s
				on x.ASXCode = s.ASXCode
				where isnull(cast(c.MC as decimal(8, 2)), 5) < 500
			) as x
			order by AnnDateTime desc, ASXCode
		end

		if @pvchSortBy = 'Market Cap'
		begin
			select top 500 *
			from
			(
				select distinct
					x.ASXCode,
					cast(c.MC as decimal(8, 2)) as MC,
					cast(c.CashPosition as decimal(8, 2)) CashPosition,
					x.AnnDescr,
					x.AnnDateTime,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker,
					ValueConsideration, 
					ValueConsiderationPerShare,
					NumAcquired,
					NumDisposed,
					case when s.MovingAverage5d > 0 then cast(cast((s.[Close] - s.MovingAverage5d)*100.0/s.MovingAverage5d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA5,
					case when s.MovingAverage10d > 0 then cast(cast((s.[Close] - s.MovingAverage10d)*100.0/s.MovingAverage10d as decimal(10, 1)) as varchar(20)) + '%' else null end as VsMA10,
					cast(d.IndustrySubGroup as varchar(100)) as IndustrySubGroup,
					g.DirName
				from #TempDirBuy as x
				inner join 
				(
					select ASXCode, max(AnnDateTime) as AnnDateTime
					from #TempDirBuy
					group by ASXCode
				) as y
				on x.ASXCode = y.ASXCode
				left join Transform.CashVsMC as c
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
				left join [Transform].[BrokerReportList] as m
				on x.ASXCode = m.ASXCode
				and m.LookBackNoDays = 0
				and m.ObservationDate = @dtObservationDate
				and m.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n
				on x.ASXCode = n.ASXCode
				and n.LookBackNoDays = 0
				and n.ObservationDate = @dtObservationDate
				and n.NetBuySell = 'S'
				left join [Transform].[BrokerReportList] as m2
				on x.ASXCode = m2.ASXCode
				and m2.LookBackNoDays = 10
				and m2.ObservationDate = @dtObservationDate
				and m2.NetBuySell = 'B'
				left join [Transform].[BrokerReportList] as n2
				on x.ASXCode = n2.ASXCode
				and n2.LookBackNoDays = 10
				and n2.ObservationDate = @dtObservationDate
				and n2.NetBuySell = 'S'
				left join StockData.StockStatsHistoryPlusCurrent as s
				on x.ASXCode = s.ASXCode
				where isnull(cast(c.MC as decimal(8, 2)), 5) < 500
			) as x
			order by isnull(MC, 99999) asc
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
