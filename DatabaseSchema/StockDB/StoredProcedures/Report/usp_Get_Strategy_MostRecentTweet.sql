-- Stored procedure: [Report].[usp_Get_Strategy_MostRecentTweet]


CREATE PROCEDURE [Report].[usp_Get_Strategy_MostRecentTweet]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_AdvancedFRCS.sql
Stored Procedure Name: usp_Get_Strategy_AdvancedFRCS
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_AdvancedFRCS'
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
		declare @dtObservationDatePlus1 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay + 1, getdate()) as date)
		declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay -3, getdate()) as date)

		--select @dtObservationDate
		--select @dtObservationDatePrev1 
		--select @dtObservationDatePrevN 

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null 
			drop table #TempPriceSummary

		select *, cast(null as decimal(20, 4)) as PreviousDay_Close, row_number() over (partition by ASXCode order by DateFrom) as RowNumber
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtObservationDate
		and DateTo is null
		and [PrevClose] > 0
		and Volume > 0

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

		if @pbitASXCodeOnly = 0
		begin
			select 
				FriendlyName, 
				CreateDateTime, 
				a.Symbol + '.AX' as ASXCode,
				cast(CreateDateTime as date) as ObservationDate,
				left(FullText, 200) as MessageContent, 
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				ttsu.FriendlyNameList,
				cast(coalesce(f.SharesIssued*p.[Close]*1.0, g.MC) as decimal(8, 2)) as MC,
				cast(g.CashPosition as decimal(8, 2)) CashPosition,
				cast(p.[Value]/1000.0 as int) as [T/O in K],
				cast(j.MedianTradeValue as int) as [MedianValue Wk],
				cast(j.MedianTradeValueDaily as int) as [MedianValue Day]
			from
			(
				select *, row_number() over (partition by FriendlyName, Symbol order by CreateDateTime asc) as RowNumber
				from
				(
					select 
						a.UserName, 
						d.FriendlyName, 
						d.Rating, 
						dateadd(hour, 10, a.CreateDateTimeUTC) as CreateDateTime, 
						a.TweetID, 
						json_value(a.TweetJson, '$.full_text') as FullText, upper(replace(json_value(b.value, '$.text'), '.AX', '')) as Symbol, 
						upper(json_value(c.value, '$.text')) as Hashtag
					from TT.Tweet as a
					inner join TT.QualityUser as d
					on a.UserName = d.UserName
					cross apply openjson(TweetJson, '$.symbols') as b
					outer apply openjson(TweetJson, '$.hashtags') as c
					where a.CreateDateTimeUTC > dateadd(day, -60, getdate())
				) as x
			) as a
			left join StockData.v_CompanyFloatingShare as f
			on a.Symbol + '.AX' = f.ASXCode
			left join #TempCashVsMC as g
			on a.Symbol + '.AX' = g.ASXCode
			left join StockData.MedianTradeValue as j
			on a.Symbol + '.AX' = j.ASXCode
			left join #TempBrokerReportListLastNDay as m2
			on a.Symbol + '.AX' = m2.ASXCode
			left join #TempBrokerReportListNegLastNDay as n2
			on a.Symbol + '.AX' = n2.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.Symbol + '.AX' = ttsu.ASXCode			
			left join #TempPriceSummary as p
			on a.Symbol + '.AX' = p.ASXCode
			where a.RowNumber = 1
			and CreateDateTime < @dtObservationDatePlus1
			and CreateDateTime >= @dtObservationDatePrevN
			order by CreateDateTime desc

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
					FriendlyName, 
					CreateDateTime, 
					cast(CreateDateTime as date) as ObservationDate,
					a.Symbol + '.AX' as ASXCode,
					left(FullText, 200) as MessageContent, 
					m2.BrokerCode as RecentTopBuyBroker,
					n2.BrokerCode as RecentTopSellBroker,
					ttsu.FriendlyNameList,
					cast(coalesce(f.SharesIssued*p.[Close]*1.0, g.MC) as decimal(8, 2)) as MC,
					cast(g.CashPosition as decimal(8, 2)) CashPosition,
					cast(p.[Value]/1000.0 as int) as [T/O in K],
					cast(j.MedianTradeValue as int) as [MedianValue Wk],
					cast(j.MedianTradeValueDaily as int) as [MedianValue Day]
				from
				(
					select *, row_number() over (partition by FriendlyName, Symbol order by CreateDateTime asc) as RowNumber
					from
					(
						select 
							a.UserName, 
							d.FriendlyName, 
							d.Rating, 
							dateadd(hour, 10, a.CreateDateTimeUTC) as CreateDateTime, 
							a.TweetID, 
							json_value(a.TweetJson, '$.full_text') as FullText, upper(replace(json_value(b.value, '$.text'), '.AX', '')) as Symbol, 
							upper(json_value(c.value, '$.text')) as Hashtag
						from TT.Tweet as a
						inner join TT.QualityUser as d
						on a.UserName = d.UserName
						cross apply openjson(TweetJson, '$.symbols') as b
						outer apply openjson(TweetJson, '$.hashtags') as c
						where a.CreateDateTimeUTC > dateadd(day, -60, getdate())
					) as x
				) as a
				left join StockData.v_CompanyFloatingShare as f
				on a.Symbol + '.AX' = f.ASXCode
				left join #TempCashVsMC as g
				on a.Symbol + '.AX' = g.ASXCode
				left join StockData.MedianTradeValue as j
				on a.Symbol + '.AX' = j.ASXCode
				left join #TempBrokerReportListLastNDay as m2
				on a.Symbol + '.AX' = m2.ASXCode
				left join #TempBrokerReportListNegLastNDay as n2
				on a.Symbol + '.AX' = n2.ASXCode
				left join Transform.TTSymbolUser as ttsu
				on a.Symbol + '.AX' = ttsu.ASXCode			
				left join #TempPriceSummary as p
				on a.Symbol + '.AX' = p.ASXCode
				where a.RowNumber = 1
				and CreateDateTime < @dtObservationDatePlus1
				and CreateDateTime >= @dtObservationDatePrevN
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