-- Stored procedure: [Report].[usp_GetTradingHalt]



--exec [Report].[usp_GetTradingHalt]


CREATE PROCEDURE [Report].[usp_GetTradingHalt]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintCountNumDaysBack as int = 30,
@pvchSortBy as varchar(50) = 'Ann Date'
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStockAnnouncement'
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
		--declare @pintCountNumDaysBack as int = 30
		
		if object_id(N'Tempdb.dbo.#TempAnn') is not null
			drop table #TempAnn

		select 
			--AnnContent,
			--AnnDescr,
			coalesce(
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}an\s{0,5}announcement).{0,120}'), 
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}in\s{0,5}relation\s{0,5}to).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}in\s{0,5}relations\s{0,5}to).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}with\s{0,5}respect\s{0,5}to).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}(releasing|release)\s{0,5}an\s{0,5}announcement\s{0,5}(about|regarding)).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}finalisation\s{0,5}of).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}(a|the)\s{0,5}release\s{0,5}of).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}(a|the) release\s{0,5}of).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}for\s{0,5}(a|the)\s{0,5}(purpose|purposes)\s{0,5}of).{0,120}'),
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}.{0,50}\s{0,5}announcement\s{0,5}(of|by)).{0,120}'),
				'N/A'
			) as TradingHaltReason, 
			coalesce(
				DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}commence\s{0,5}.{0,50}\s{0,5}trading\s{0,5}.{0,30})[0-9]{0,2}\s{0,5}(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s{0,5}[0-9]{2,4}'), 
				'N/A'
			) as ReopenDate, 
			ASXCode,
			AnnouncementID,
			AnnDateTime,
			AnnDescr
		into #TempAnn
		from StockData.Announcement
		where datediff(day, AnnDateTime, getdate()) < @pintCountNumDaysBack
		and AnnDescr LIKE '%Trading Halt%'
		--and 
		--(
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}an\s{0,5}announcement).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}in\s{0,5}relation\s{0,5}to).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}in\s{0,5}relations\s{0,5}to).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}with\s{0,5}respect\s{0,5}to).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}(releasing|release)\s{0,5}an\s{0,5}announcement\s{0,5}(about|regarding)).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}finalisation\s{0,5}of).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}a\s{0,5}release\s{0,5}relating\s{0,5}to).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}(a|the)\s{0,5}release\s{0,5}of).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}for\s{0,5}(a|the)\s{0,5}(purpose|purposes)\s{0,5}of).{0,80}') is not null
		--	or
		--	DA_Utility.dbo.[RegexMatch](AnnContent, '(?<=.{20}pending\s{0,5}.{0,50}\s{0,5}announcement\s{0,5}(of|by)).{0,80}') is not null
		--)	
		
		if object_id(N'Tempdb.dbo.#TempStockAttribute') is not null
			drop table #TempStockAttribute

		select *
		into #TempStockAttribute
		from 
		(
			select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from StockData.StockAttribute as a
			--where datediff(day, ObservationDate, getdate()) <= 1
			where [Common].[DateAddBusinessDay](-1, cast(getdate() as date)) <= ObservationDate
		) as a
		where RowNumber = 1

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

		if @pvchSortBy = 'MC'
		begin

			select 
				a.ASXCode,
				a.AnnDateTime,
				a.TradingHaltReason,
				format(h.AvgValue90d, 'N0') as AvgValue90d,
				a.ReopenDate,
				--i.ObservationDate,
				c.MC,
				c.CashPosition,
				--i.RSI,
				i.[Close],
				--i.ExpMovingAverage7d,
				d.Nature,
				j.Poster
			from #TempAnn as a
			left join 
			(
				select ASXCode, avg([Value]*[Close]) as AvgValue90d from StockData.PriceHistory
				where 1 = 1
				and datediff(day, ObservationDate, getdate()) <= 90
				group by ASXCode			
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempStockAttribute as i
			on a.ASXCode = i.ASXCode
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join Transform.PosterList as j
			on a.ASXCode = j.ASXCode
			order by cast(c.MC as decimal(8, 2)) asc
		end

		if @pvchSortBy = 'Ann Date'
		begin

			select 
				a.ASXCode,
				a.AnnDateTime,
				a.TradingHaltReason,
				format(h.AvgValue90d, 'N0') as AvgValue90d,
				a.ReopenDate,
				--i.ObservationDate,
				c.MC,
				c.CashPosition,
				--i.RSI,
				i.[Close],
				--i.ExpMovingAverage7d,
				d.Nature,
				j.Poster
			from #TempAnn as a
			left join 
			(
				select ASXCode, avg([Value]*[Close]) as AvgValue90d from StockData.PriceHistory
				where 1 = 1
				and datediff(day, ObservationDate, getdate()) <= 90
				group by ASXCode			
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempStockAttribute as i
			on a.ASXCode = i.ASXCode
			left join #TempCashVsMC as c
			on a.ASXCode = c.ASXCode
			left join #TempStockNature as d
			on a.ASXCode = d.ASXCode
			left join HC.HeadPostSummary as f
			on a.ASXCode = f.ASXCode
			left join Transform.PosterList as j
			on a.ASXCode = j.ASXCode
			order by a.AnnDateTime desc
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
