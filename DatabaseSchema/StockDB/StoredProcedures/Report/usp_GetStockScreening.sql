-- Stored procedure: [Report].[usp_GetStockScreening]



--exec [Report].[usp_GetStockScreening]
--@pvchSortBy = 'Market Cap'

CREATE PROCEDURE [Report].[usp_GetStockScreening]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchSortBy as varchar(50) = 'Value Over MC',
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_GetStockScreening.sql
Stored Procedure Name: usp_GetStockScreening
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStockScreening'
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
		right join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempStockNature') is not null
			drop table #TempStockNature

		select a.ASXCode, stuff((
			select ',' + Token
			from StockData.StockNature
			where ASXCode = a.ASXCode
			order by AnnCount desc
			for xml path('')), 1, 1, ''
		) as Nature
		into #TempStockNature
		from StockData.StockNature as a
		group by a.ASXCode

		if object_id(N'Tempdb.dbo.#TempDirectorCurrent') is not null
			drop table #TempDirectorCurrent

		select a.ASXCode, a.DirName
		into #TempDirectorCurrent
		from StockData.DirectorCurrentPvt as a
	
		--declare @pintNumPrevDay as int = 0

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[PrevClose] decimal(20, 4),
			[Value] decimal(20, 4) 
		)

		insert into #TempPriceSummary
		(
			ASXCode,
			[Open],
			[Close],
			[PrevClose],
			[Value]
		)
		select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, [Value]
		from StockData.PriceSummary as a
		--inner join StockData.PriceHistoryCurrent as b
		--on a.ASXCode = b.ASXCode
		where ObservationDate = cast(dateadd(day, -1*@pintNumPrevDay, getdate()) as date)
		and LatestForTheDay = 1

		delete a
		from #TempPriceSummary as a
		where PrevClose = 0

		if object_id(N'Tempdb.dbo.#TempPostRaw') is not null
			drop table #TempPostRaw

		select
			PostRawID,
			ASXCode,
			Poster,
			PostDateTime,
			PosterIsHeart,
			QualityPosterRating,
			Sentiment,
			Disclosure
		into #TempPostRaw
		from HC.TempPostLatest

		--if object_id(N'Tempdb.dbo.#TempPoster') is not null
		--	drop table #TempPoster

		--select x.ASXCode, stuff((
		--	select ',' + [Poster]
		--	from #TempPostRaw as a
		--	where x.ASXCode = a.ASXCode
		--	and (Sentiment in ('Buy') or Disclosure in ('Held'))
		--	and datediff(day, PostDateTime, getdate()) <= 60
		--	and exists
		--	(
		--		select 1
		--		from StockData.PriceHistoryCurrent
		--		where ASXCode = a.ASXCode
		--	)
		--	order by PostDateTime desc, isnull(QualityPosterRating, 200) asc
		--	for xml path('')), 1, 1, ''
		--) as [Poster]
		--into #TempPoster
		--from #TempPostRaw as x
		--where (Sentiment in ('Buy') or Disclosure in ('Held'))
		--and datediff(day, PostDateTime, getdate()) <= 60
		--and exists
		--(
		--	select 1
		--	from StockData.PriceHistoryCurrent
		--	where ASXCode = x.ASXCode
		--)
		--group by x.ASXCode

		if @pvchSortBy = 'Value Over MC'
		begin
			select top 500
				a.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from StockData.PriceHistoryCurrent as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			--order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
			order by cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) desc
		end

		if @pvchSortBy = 'Price Changes'
		begin
			select top 500
				a.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from StockData.PriceHistoryCurrent as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			--order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
			order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
		end

		if @pvchSortBy = 'Market Cap'
		begin
			select top 1500
				a.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster
			from StockData.PriceHistoryCurrent as a
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			--order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
			where cast(c.MC as decimal(8, 2)) >= 2
			order by cast(c.MC as decimal(8, 2)) asc
		end

		if @pvchSortBy = 'Director Market Buy'
		begin

			if object_id(N'Tempdb.dbo.#TempAnn') is not null
				drop table #TempAnn

			SELECT *
			into #TempAnn
			FROM StockData.Announcement as a
			WHERE 
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<!Example:\s)on[-\s]market (trade|purchase|buy|acquire)') is not null
			--AnnContent like '%market%trade%'
			--and freetext(AnnContent,'"lithium" and "cobalt"')
			--and freetext(AnnContent,'"cobalt"')
			--and freetext(AnnContent, 'Opportunity')
			--and ASXCode = 'KDR.AX'
			and AnnDescr like '%Director%'
			and datediff(day, AnnDateTime, getdate()) < 90
			and not exists
			(
				select 1
				from [StockData].[StockOverview]
				where ASXCode = a.ASXCode
				and DateTo is null
				and CleansedMarketCap > 500
			)
			order by AnnDateTime desc

			select top 500
				a.ASXCode,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(h.[Value]/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				i.Poster,
				x.AnnDescr,
				x.AnnDateTime
			from StockData.PriceHistoryCurrent as a
			inner join #TempAnn as x
			on a. ASXCode = x. ASXCode
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join [StockData].[PriceHistoryCurrent] as e
			on a.ASXCode = e.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join #TempDirectorCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join Transform.PosterList as i
			on a.ASXCode = i.ASXCode
			--order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc
			order by x.AnnDateTime desc

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
