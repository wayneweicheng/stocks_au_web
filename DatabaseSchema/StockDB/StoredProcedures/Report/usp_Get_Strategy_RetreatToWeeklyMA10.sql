-- Stored procedure: [Report].[usp_Get_Strategy_RetreatToWeeklyMA10]


CREATE PROCEDURE [Report].[usp_Get_Strategy_RetreatToWeeklyMA10]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_LongBullishBar.sql
Stored Procedure Name: usp_Get_Strategy_LongBullishBar
Overview
-----------------
usp_Get_Strategy_LongBullishBar

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
Date:		2020-08-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_RetreatToWeeklyMA10'
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
		--declare @pintNumPrevDay as int = 1

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

		if @pbitASXCodeOnly = 0
		begin
			select 
				'Retreat to Weekly MA10' as ReportType,			
				j.MedianPriceChangePerc,
				a.ASXCode, 
				cast(a.CreateDate as date) as CreateDate,
				Common.DateAddBusinessDay(-13, @dtObservationDate) as StartBRDate, 
				Common.DateAddBusinessDay(-3, @dtObservationDate) as EndBRDate, 
				a.[Close], 
				a.MedianTradeValueWeekly, 
				a.MedianTradeValueDaily, 
				a.MedianPriceChangePerc, 
				cast(j.MedianTradeValue as int) as MedianTradeValueWeekly,
				cast(j.MedianTradeValueDaily as int) as MedianTradeValueDaily,
				g.MediumTermRetailParticipationRate,
				g.ShortTermRetailParticipationRate,
				ttsu.FriendlyNameList,
				c.CleansedMarketCap,
				f.AnnDescr,
				m.BrokerCode as TopBuyBroker,
				n.BrokerCode as TopSellBroker
			from StockData.WeeklyMonthlyPriceAction as a
			left join StockData.CompanyInfo as c
			on a.ASXCode = c.ASXCode
			left join 
			(
				select ASXCode, MedianTradeValue, MedianTradeValueDaily, MedianPriceChangePerc 
				from StockData.MedianTradeValue
			) as j
			on a.ASXCode = j.ASXCode
			left join (
				select 
					AnnouncementID,
					ASXCode,
					AnnDescr,
					AnnDateTime,
					stuff((
					select ',' + [SearchTerm]
					from StockData.AnnouncementAlert as a
					where x.AnnouncementID = a.AnnouncementID
					order by CreateDate desc
					for xml path('')), 1, 1, ''
					) as [SearchTerm],
					row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
				from StockData.Announcement as x
				where cast(AnnDateTime as date) = @dtObservationDate			
			) as f
			on a.ASXCode = f.ASXCode
			and f.RowNumber = 1
			left join StockData.RetailParticipation as g
			on a.ASXCode = g.ASXCode
			left join #TempBrokerReportList as m
			on a.ASXCode = m.ASXCode
			left join #TempBrokerReportListNeg as n
			on a.ASXCode = n.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where ActionType = 'Retreat to Weekly MA10'
			and cast(CreateDate as date) = @dtObservationDate
			and j.MedianPriceChangePerc >= 2.0
			order by j.MedianPriceChangePerc desc;
		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempOutput') is not null
				drop table #TempOutput

			select 
			identity(int, 1, 1) as DisplayOrder,
			*
			into #TempOutput
			from
			(
				select 
					'Retreat to Weekly MA10' as ReportType,			
					j.MedianPriceChangePerc,
					a.ASXCode, 
					cast(a.CreateDate as date) as CreateDate,
					Common.DateAddBusinessDay(-13, @dtObservationDate) as StartBRDate, 
					Common.DateAddBusinessDay(-3, @dtObservationDate) as EndBRDate, 
					a.[Close], 
					--a.MedianTradeValueWeekly, 
					--a.MedianTradeValueDaily, 
					--a.MedianPriceChangePerc, 
					cast(j.MedianTradeValue as int) as MedianTradeValueWeekly,
					cast(j.MedianTradeValueDaily as int) as MedianTradeValueDaily,
					g.MediumTermRetailParticipationRate,
					g.ShortTermRetailParticipationRate,
					c.CleansedMarketCap,
					f.AnnDescr,
					m.BrokerCode as TopBuyBroker,
					n.BrokerCode as TopSellBroker
				from StockData.WeeklyMonthlyPriceAction as a
				left join StockData.CompanyInfo as c
				on a.ASXCode = c.ASXCode
				left join 
				(
					select ASXCode, MedianTradeValue, MedianTradeValueDaily, MedianPriceChangePerc 
					from StockData.MedianTradeValue
				) as j
				on a.ASXCode = j.ASXCode
				left join (
					select 
						AnnouncementID,
						ASXCode,
						AnnDescr,
						AnnDateTime,
						stuff((
						select ',' + [SearchTerm]
						from StockData.AnnouncementAlert as a
						where x.AnnouncementID = a.AnnouncementID
						order by CreateDate desc
						for xml path('')), 1, 1, ''
						) as [SearchTerm],
						row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
					from StockData.Announcement as x
					where cast(AnnDateTime as date) = @dtObservationDate			
				) as f
				on a.ASXCode = f.ASXCode
				and f.RowNumber = 1
				left join StockData.RetailParticipation as g
				on a.ASXCode = g.ASXCode
				left join #TempBrokerReportList as m
				on a.ASXCode = m.ASXCode
				left join #TempBrokerReportListNeg as n
				on a.ASXCode = n.ASXCode
				where ActionType = 'Retreat to Weekly MA10'
				and cast(CreateDate as date) = @dtObservationDate
				and j.MedianPriceChangePerc >= 2.0
			) as x
			order by MedianPriceChangePerc desc;

			select
				distinct
				ASXCode,
				DisplayOrder,
				cast(CreateDate as date) as ObservationDate,
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
