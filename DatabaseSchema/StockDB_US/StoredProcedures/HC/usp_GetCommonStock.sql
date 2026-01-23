-- Stored procedure: [HC].[usp_GetCommonStock]

CREATE PROCEDURE [HC].[usp_GetCommonStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumDay int = 30,
@pintMaxQualityPosterRating int = 25,
@pvchSortBy as varchar(50) = 'ASXCode'
AS
/******************************************************************************
File: usp_GetCommonStock.sql
Stored Procedure Name: usp_GetCommonStock
Overview
-----------------
usp_IsQualityPoster

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
Date:		2017-09-17
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetCommonStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'HC'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
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

		update a
		set a.QualityPosterRating = case when b.Poster is not null then b.Rating else case when a.PosterIsHeart = 1 then 20 else null end end
		from #TempPostRaw as a
		left join HC.QualityPoster as b
		on a.Poster = b.Poster

		if object_id(N'Tempdb.dbo.#TempCommonStock') is not null
			drop table #TempCommonStock

		select ASXCode, count(distinct Poster) as PosterCount
		into #TempCommonStock
		from #TempPostRaw as a
		where QualityPosterRating <= @pintMaxQualityPosterRating
		and datediff(day, PostDateTime, getdate()) < @pintNumDay
		and (Disclosure = 'Held' or Sentiment = 'Buy' or Poster in ('Shinji Ono'))
		group by ASXCode
		having count(distinct Poster) > 1
		order by count(distinct Poster) desc

		if object_id(N'Tempdb.dbo.#TempCommonStockCurr') is not null
			drop table #TempCommonStockCurr

		select a.ASXCode, cast(a.Poster as varchar(30)) as Poster, max(PostDateTime) as LatestHoldDate, cast(0 as bit) as LatestHoldDateChanged, cast(0 as bit) as DroppedFromLast
		into #TempCommonStockCurr
		from #TempPostRaw as a
		inner join #TempCommonStock as b
		on a.ASXCode = b.ASXCode
		and datediff(day, PostDateTime, getdate()) < @pintNumDay
		and (Disclosure = 'Held' or Sentiment = 'Buy' or Poster in ('Shinji Ono'))
		and QualityPosterRating < @pintMaxQualityPosterRating
		group by a.ASXCode, a.Poster
		order by a.ASXCode, max(PostDateTime) desc

		declare @dtCreateDate as datetime
		select @dtCreateDate = max(CreateDate)
		from HC.CommonStockHistory
		where CreateDate < dateadd(day, -1, cast(getdate() as date))

		if object_id(N'Tempdb.dbo.#TempCommonStockPrev') is not null
			drop table #TempCommonStockPrev

		select
			ASXCode,
			Poster,
			LatestHoldDate
		into #TempCommonStockPrev
		from HC.CommonStockHistory
		where CreateDate = @dtCreateDate

		insert into #TempCommonStockCurr
		(
			ASXCode, 
			Poster, 
			LatestHoldDate, 
			LatestHoldDateChanged,
			DroppedFromLast
		)
		select
			ASXCode, 
			Poster, 
			LatestHoldDate, 
			0 as LatestHoldDateChanged,
			1 as DroppedFromLast
		from #TempCommonStockPrev as a
		where not exists
		(
			select 1
			from #TempCommonStockCurr
			where ASXCode = a.ASXCode
			and Poster = a.Poster
		)

		update a
		set LatestHoldDateChanged = 1
		from #TempCommonStockCurr as a
		inner join #TempCommonStockPrev as b
		on a.ASXCode = b.ASXCode
		and a.Poster = b.Poster
		and a.LatestHoldDate != b.LatestHoldDate

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

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select * 
		into #TempPriceSummary
		from StockData.PriceSummary
		where cast(DateFrom as date) = cast(getdate() as date)
		and DateTo is null

		if @pvchSortBy = 'ASXCode' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				isnull(h.[close], e.[Close]) as [Close],
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by a.ASXCode, a.LatestHoldDate desc
		end

		if @pvchSortBy = 'Market Cap' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				isnull(h.[close], e.[Close]) as [Close],
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by isnull(cast(c.MC as decimal(8, 2)), 99999), a.LatestHoldDate desc
		end

		if @pvchSortBy = 'Latest Date' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				isnull(h.[close], e.[Close]) as [Close],
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by LatestHoldDate desc
		end

		if @pvchSortBy = 'Changes' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				isnull(h.[close], e.[Close]) as [Close],
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by case when b.ASXCode is null then 0 
						  when DroppedFromLast = 1 then 1
						  when a.LatestHoldDateChanged = 1 then 2
						  else 99
				     end asc, a.ASXCode, a.LatestHoldDate desc
		end

		if @pvchSortBy = 'Price Changes' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) desc, a.ASXCode, a.LatestHoldDate desc
		end

		if @pvchSortBy = 'Value Over MC' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) desc, a.ASXCode, a.LatestHoldDate desc
		end
	
		if @pvchSortBy = 'Num Common Poster' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				isnull(h.[close], e.[Close]) as [Close],
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			left join 
			(
				select ASXCode, count(distinct Poster) as NumPoster
				from #TempCommonStockCurr
				group by ASXCode
			) as i
			on a.ASXCode = i.ASXCode
			order by i.NumPoster desc, a.ASXCode, a.LatestHoldDate desc
		end

		if @pvchSortBy = 'Poster' 
		begin
			select 
				case when b.ASXCode is null then a.ASXCode + '+' 
					 when DroppedFromLast = 1 then a.ASXCode + '-'
					 else a.ASXCode 
				end as ASXCode,
				case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
				end as Poster,
				case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end as LatestHoldDate,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				--f.NumPost1d,
				--cast(f.NumPostAvg5d as decimal(8,2)) as NumPostAvg5d,
				--cast(f.NumPostAvg30d as decimal(8,2)) as NumPostAvg30d,
				cast(d.Nature as varchar(100)) as Nature,
				g.DirName
			from #TempCommonStockCurr as a
			left join #TempCommonStockPrev as b
			on a.ASXCode = b.ASXCode
			and a.Poster = b.Poster
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
			order by 
			case when b.ASXCode is null then a.Poster  + '+'
					 when DroppedFromLast = 1 then a.Poster + '-' 
					 else a.Poster 
			end asc, 
			case when a.LatestHoldDateChanged = 1 then convert(varchar(30), a.LatestHoldDate, 126) + '^' else convert(varchar(30), a.LatestHoldDate, 126) end desc,
			case when b.ASXCode is null then a.ASXCode + '+' 
				 when DroppedFromLast = 1 then a.ASXCode + '-'
				 else a.ASXCode 
			end,
			a.LatestHoldDate desc
		end

		if @pvchSortBy = 'NewStar' 
		begin
			if object_id(N'Tempdb.dbo.#TempPostRaw2') is not null
				drop table #TempPostRaw2

			select
				PostRawID,
				ASXCode,
				a.Poster,
				PostDateTime,
				PosterIsHeart,
				QualityPosterRating,
				Sentiment,
				Disclosure
			into #TempPostRaw2
			from HC.TempPostLatest as a
			inner join 
			(
				select distinct Poster
				from HC.TempPostLatest
				where PosterIsHeart = 1		
				union
				select Poster
				from HC.QualityPoster		
			) as b
			on a.Poster = b.Poster

			if object_id(N'Tempdb.dbo.#TempNewStar') is not null
				drop table #TempNewStar

			select * 
			into #TempNewStar
			from #TempPostRaw2 as a
			where not exists
			(
				select 1
				from HC.PostRaw
				where ASXCode = a.ASXCode
				and Poster = a.Poster
				and datediff(day, PostDateTime, getdate()) > 15
			)
			and datediff(day, PostDateTime, getdate()) < 5
			and (Disclosure = 'Held' or Sentiment = 'Buy')

			select 
				a.ASXCode as ASXCode,
				a.Poster as Poster,
				cast(c.MC as decimal(8, 2)) as MC,
				cast(c.CashPosition as decimal(8, 2)) CashPosition,
				cast(isnull(h.[Value], e.[Value])/1000.0 as decimal(10, 2)) as [Value in K],
				cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
				cast(isnull(h.[Value], e.[Value])/(cast(c.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
				cast(d.Nature as varchar(100)) as Nature,
				--g.DirName,
				a.Sentiment,
				a.Disclosure,
				a.PostDateTime
			from #TempNewStar as a
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
			order by 
			a.ASXCode
		end

		insert into HC.CommonStockHistory
		(
			ASXCode,
			Poster,
			LatestHoldDate,
			CreateDate
		)
		select
			ASXCode,
			Poster,
			LatestHoldDate,
			getdate() as CreateDate
		from #TempCommonStockCurr
		where isnull(DroppedFromLast, 0) = 0
		
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
