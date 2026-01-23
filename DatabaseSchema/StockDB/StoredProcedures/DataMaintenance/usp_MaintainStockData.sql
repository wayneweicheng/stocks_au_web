-- Stored procedure: [DataMaintenance].[usp_MaintainStockData]





CREATE PROCEDURE [DataMaintenance].[usp_MaintainStockData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_MaintainStockData.sql
Stored Procedure Name: usp_MaintainStockData
Overview
-----------------
usp_MaintainStockData

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
Date:		2017-02-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MaintainStockData'
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
		exec [DataMaintenance].[usp_MaintainPriceHistory]

		update a
		set Sentiment = DA_Utility.dbo.RegexMatch(replace(replace(replace(PostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Sentiment:).{0,30}(?=</span>)')
		from HC.PostRaw as a
		where Sentiment is null
		and PostFooter is not null
		and DA_Utility.dbo.RegexMatch(replace(replace(replace(PostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Sentiment:).{0,30}(?=</span>)') is not null

		update a
		set Disclosure = DA_Utility.dbo.RegexMatch(replace(replace(replace(PostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Disclosure:).{0,30}(?=</span>)')
		from HC.PostRaw as a
		where Disclosure is null
		and PostFooter is not null
		and DA_Utility.dbo.RegexMatch(replace(replace(replace(PostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Disclosure:).{0,30}(?=</span>)') is not null

		update a
		set PriceAtPosting = replace(DA_Utility.dbo.RegexMatch(replace(replace(replace(PostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Priceatposting:).{0,30}(?=</span>)'), '&cent;', 'c')
		from HC.PostRaw as a
		where PriceAtPosting is null
		and PostFooter is not null
		and replace(DA_Utility.dbo.RegexMatch(replace(replace(replace(PostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Priceatposting:).{0,30}(?=</span>)'), '&cent;', 'c') is not null

		exec [StockData].[usp_RefeshCashPosition]

		exec [StockData].[usp_RefeshQuarterlyCashflow]

		update a
		set CleansedMarketCap = try_cast(replace(MarketCap, ',', '') as decimal(20, 4))
		from StockData.StockOverview as a
		where len(MarketCap) > 0 

		update a
		set CleansedShareOnIssue = try_cast(replace(ShareOnIssue, ',', '') as decimal(20, 4))
		from StockData.StockOverview as a
		where len(ShareOnIssue) > 0 

		update a
		set CleansedMarketCap = case when right(MarketCap, 1) = 'B' then try_cast(replace(replace(replace(replace(MarketCap, '$', ''), 'M', ''), 'B', ''), 'K', '') as decimal(20, 2))*1000.0
									 when right(MarketCap, 1) = 'M' then try_cast(replace(replace(replace(replace(MarketCap, '$', ''), 'M', ''), 'B', ''), 'K', '') as decimal(20, 2))*1.0 
									 when right(MarketCap, 1) = 'K' then try_cast(replace(replace(replace(replace(MarketCap, '$', ''), 'M', ''), 'B', ''), 'K', '') as decimal(20, 2))*0.001
								end
		from HC.StockOverview as a
		where len(MarketCap) > 0

		update a
		set CleansedMonthlyVisit = try_cast(replace(MonthlyVisit, ',', '') as int)
		from HC.StockOverview as a
		where len(MonthlyVisit) > 0
		and CleansedMonthlyVisit is null

		update a
		set CleansedNoOfPost = try_cast(replace(NoOfPost, ',', '') as int)
		from HC.StockOverview as a
		where len(NoOfPost) > 0

		update a
			set a.dateto = getdate()
		from stockdata.director as a
		inner join
		(
			select 
				asxcode,
				max(datelastseen) as datelastseen
			from stockdata.director
			group by 
				asxcode
		) as b
		on a.asxcode = b.asxcode	
		and a.dateto is null
		and datediff(day, a.datelastseen, b.datelastseen) > 2

		if object_id(N'Working.Director') is not null
			drop table Working.Director

		select
		   [DirectorID]
		  ,[ASXCode]
		  ,[Name]
		  ,cast(null as varchar(200)) as FirstName
		  ,cast(null as varchar(200)) as MiddleName
		  ,cast(null as varchar(200)) as Surname
		  ,[Age]
		  ,[Since]
		  ,[Position]
		  ,DirectorID as UniqueKey
		  ,DirectorID as DedupeKey
		into Working.Director
		from StockData.Director as a
		where DateTo is null

		update a
		set a.DedupeKey = b.DedupeKey
		from Working.Director as a
		inner join
		(
			select Name, min(DedupeKey) as DedupeKey
			from Working.Director
			where len(Name) > 3
			group by Name
		) as b
		on a.Name = b.Name
		and a.DedupeKey > b.DedupeKey

		delete a
		from StockData.DirectorCurrent as a

		dbcc checkident('StockData.DirectorCurrent', reseed, 1);

		insert into StockData.DirectorCurrent
		(
			[DirectorID],
			[ASXCode],
			[Name],
			[FirstName],
			[MiddleName],
			[Surname],
			[Age],
			[Since],
			[Position],
			[UniqueKey],
			[DedupeKey]
		)
		select 
			[DirectorID],
			[ASXCode],
			[Name],
			[FirstName],
			[MiddleName],
			[Surname],
			[Age],
			[Since],
			[Position],
			[UniqueKey],
			[DedupeKey]
		from Working.Director

		delete a
		from StockData.StockOverviewCurrent as a

		dbcc checkident('StockData.StockOverviewCurrent', reseed, 1);
		
		insert into StockData.StockOverviewCurrent
		(
		   [ASXCode]
		  ,[MarketCap]
		  ,[ShareOnIssue]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[CleansedMarketCap]
		  ,[CleansedShareOnIssue]
		)
		select
		   [ASXCode]
		  ,[MarketCap]
		  ,[ShareOnIssue]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[CleansedMarketCap]
		  ,[CleansedShareOnIssue]
		from StockData.StockOverview
		where DateTo is null

		update a
		set a.CleansedMarketCap = b.CleansedMarketCap,
			a.MarketCap = b.MarketCap
		from StockData.StockOverviewCurrent as a
		inner join HC.StockOverview as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		and b.CleansedMarketCap is not null
		and a.CleansedMarketCap != b.CleansedMarketCap		
		
		insert into StockData.StockOverviewCurrent
		(
		   [ASXCode]
		  ,[MarketCap]
		  ,[ShareOnIssue]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[CleansedMarketCap]
		  ,[CleansedShareOnIssue]
		)
		select
		   [ASXCode]
		  ,[MarketCap]
		  ,null as [ShareOnIssue]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[CleansedMarketCap]
		  ,null as [CleansedShareOnIssue]
		from HC.StockOverview as a
		where DateTo is null
		and CleansedMarketCap is not null
		and not exists
		(
			select 1
			from StockData.StockOverviewCurrent
			where ASXCode = a.ASXCode
		)
		
		update a
		set a.[Open] = a.[Close],
			a.[Volume] = 1,
			a.[Value] = 1
		from StockData.PriceHistory as a
		where ASXCode in ('XAO.AX', 'XJO.AX', 'XSO.AX', 'XEC.AX')
		and (a.[Open] = 0 or a.[Volume] = 0)

		truncate table [StockData].[PriceHistoryCurrent]

		insert into [StockData].[PriceHistoryCurrent]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[Value]
		  ,[Trades]
		  ,[EMA7]
		  ,[SMA5]
		  ,[SMA10]
		  ,[SMA60]
		  ,[VSMA30]
		  ,[RSI]
		  ,[Last12MonthHighDate]
		  ,[Last12MonthLowDate]
		  ,[CreateDate]
		  ,[ModifyDate]
		)
		select
		   [ASXCode]
		  ,[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[Value]
		  ,[Trades]
		  ,null as [EMA7]
		  ,null as [SMA5]
		  ,null as [SMA10]
		  ,null as [SMA60]
		  ,null as [VSMA30]
		  ,null as [RSI]
		  ,null as [Last12MonthHighDate]
		  ,null as [Last12MonthLowDate]
		  ,[CreateDate]
		  ,[ModifyDate]
		from
		(
			SELECT 
				   [ASXCode]
				  ,[ObservationDate]
				  ,[Close]
				  ,[Open]
				  ,[Low]
				  ,[High]
				  ,[Volume]
				  ,[Value]
				  ,[Trades]
				  ,[CreateDate]
				  ,[ModifyDate] 
				  ,row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			FROM [StockData].[PriceHistory]
			where Volume > 0
		) as x
		where RowNumber = 1
		and ObservationDate > dateadd(day, -30, getdate()) 

		if object_id(N'Tempdb.dbo.#TempPriceHistory12m') is not null
			drop table #TempPriceHistory12m

		SELECT 
				[ASXCode]
				,[ObservationDate]
				,[Close]
				,[Open]
				,[Low]
				,[High]
				,[Volume]
				,[Value]
				,[Trades]
				,[CreateDate]
				,[ModifyDate] 
				,row_number() over (partition by ASXCode order by [Close] desc, ObservationDate asc) as RowNumberHigh
				,row_number() over (partition by ASXCode order by [Close] asc, ObservationDate asc) as RowNumberLow
		into #TempPriceHistory12m
		FROM [StockData].[PriceHistory]

		delete x
		from #TempPriceHistory12m as x
		inner join
		(
		select ASXCode, count(ASXCode) as Num
		from #TempPriceHistory12m as a
		group by ASXCode
		) as y
		on x.ASXCode = y.ASXCode
		and y.Num < 180

		update a
		set a.Last12MonthHighDate = b.ObservationDate
		from [StockData].[PriceHistoryCurrent] as a
		inner join #TempPriceHistory12m as b
		on a.ASXCode = b.ASXCode
		and b.RowNumberHigh = 1

		update a
		set a.Last12MonthLowDate = b.ObservationDate
		from [StockData].[PriceHistoryCurrent] as a
		inner join #TempPriceHistory12m as b
		on a.ASXCode = b.ASXCode
		and b.RowNumberLow = 1

		update a
		set PostStats = DA_Utility.dbo.RegexReplace(PostStats, '[^0-9]', '')
		from HC.HeadPost as a
		where DA_Utility.dbo.RegexMatch(PostStats, '[^0-9]') is not null

		if object_id(N'HC.HeadPostSummary') is not null
			drop table HC.HeadPostSummary
		select 
			a.ASXCode,
			isnull(d1.NumPost1d, 0) as NumPost1d,
			isnull(d5.NumPostAvg5d, 0) as NumPostAvg5d,
			isnull(d30.NumPostAvg30d, 0) as NumPostAvg30d
		into HC.HeadPostSummary
		from
		(
			SELECT ASXCode
			FROM HC.HeadPost
			group by ASXCode
		) as a
		left join
		(
			SELECT ASXCode, count(HeadPostID) as NumPost1d
			FROM HC.HeadPost
			where cast(PostDateTime as date) = dateadd(day, -1, cast(getdate() as date))
			group by ASXCode
		) as d1
		on a.ASXCode = d1.ASXCode
		left join
		(
			SELECT ASXCode, count(HeadPostID)*1.0/(datediff(day, min(PostDateTime), GETDATE()) + 1) as NumPostAvg30d
			FROM HC.HeadPost
			where datediff(day, PostDateTime, GETDATE()) < 30
			group by ASXCode
		) as d30
		on a.ASXCode = d30.ASXCode
		left join
		(
			select ASXCode, count(HeadPostID)*1.0/(datediff(day, min(PostDateTime), GETDATE()) + 1) as NumPostAvg5d
			FROM HC.HeadPost
			where datediff(day, PostDateTime, GETDATE()) < 5
			group by ASXCode
		) as d5
		on a.ASXCode = d5.ASXCode

		exec [StockData].[usp_RefeshStockMCList]

		exec [DataMaintenance].[usp_RefreshSectorPerformance]

		exec [HC].[usp_RefreshPosterSummary]

		if object_id(N'HC.TempPostLatest') is not null
			drop table HC.TempPostLatest

		select
			PostRawID,
			ASXCode,
			Poster,
			PostDateTime,
			PosterIsHeart,
			QualityPosterRating,
			Sentiment,
			Disclosure
		into HC.TempPostLatest
		from
		(				
			select
				PostRawID,
				ASXCode,
				a.Poster,
				PostDateTime,
				PosterIsHeart,
				b.Rating as QualityPosterRating,
				Sentiment,
				Disclosure,
				row_number() over (partition by ASXCode, a.Poster order by PostDateTime desc) as RowNumber
			from HC.PostRaw as a
			inner join HC.QualityPoster as b
			on a.Poster = b.Poster
		) as a
		where a.RowNumber = 1

		delete a
		from StockData.DirectorCurrentPvt as a

		dbcc checkident('StockData.DirectorCurrentPvt', reseed, 1);

		insert into [StockData].[DirectorCurrentPvt]
		(
			[ASXCode],
			[DirName]
		)
		select a.ASXCode, stuff((
			select ',' + [Name]
			from StockData.DirectorCurrent
			where ASXCode = a.ASXCode
			order by Surname desc
			for xml path('')), 1, 1, ''
		) as DirName
		from StockData.DirectorCurrent as a
		group by a.ASXCode

		update a
		set a.SeqNum = b.SeqNum
		from HC.StockOverview as a
		inner join
		(
			select 
				StockOverviewID,
				ASXCode,
				dense_rank() over (partition by ASXCode order by cast(DateFrom as date)) as SeqNum
			from HC.StockOverview
		) as b
		on a.StockOverviewID = b.StockOverviewID

		update a
		set a.CleansedMonthlyVisitDelta = a.CleansedMonthlyVisit - b.CleansedMonthlyVisit,
			a.CleansedNoOfPostDelta = a.CleansedNoOfPost - b.CleansedNoOfPost
		from HC.StockOverview as a
		inner join HC.StockOverview as b
		on a.ASXCode = b.ASXCode
		and a.SeqNum = b.SeqNum + 1

		update a
		set a.DerivedTodayVist = case when isnull(b.DerivedTodayVist, 0) + a.CleansedMonthlyVisitDelta > 0 then isnull(b.DerivedTodayVist, 0) + a.CleansedMonthlyVisitDelta else 0 end
		from HC.StockOverview as a
		left join HC.StockOverview as b
		on a.ASXCode = b.ASXCode
		and datediff(day, b.DateFrom, a.Datefrom) = 30

		update a
		set a.MA30Visit = a.CleansedMonthlyVisit*1.0/30
		from HC.StockOverview as a
		where a.MA30Visit is null

		if object_id(N'Tempdb.dbo.#TempPostRaw') is not null
			drop table #TempPostRaw

		select
			PostRawID,
			ASXCode,
			a.Poster,
			PostDateTime,
			PosterIsHeart,
			QualityPosterRating,
			Sentiment,
			Disclosure
		into #TempPostRaw
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

		insert into StockData.MonitorStock
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,[MonitorTypeID]
		  ,[LastCourseOfSaleDate]
		  ,[StockSource]
		  ,[PriorityLevel]
		  ,[SMSAlertSetupDate]
		)
		select 
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,null as [UpdateStatus]
		  ,'T' as [MonitorTypeID]
		  ,null as [LastCourseOfSaleDate]
		  ,null as [StockSource]
		  ,null as [PriorityLevel]
		  ,null as [SMSAlertSetupDate]
		from
		(
			select ASXCode
			from #TempPostRaw
			where 1 = 1
			and datediff(day, PostDateTime, getdate()) < 14
			group by ASXCode
		) as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID ='T'
			and ASXCode = a.ASXCode
		)

		insert into StockData.MonitorStock
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,[MonitorTypeID]
		  ,[LastCourseOfSaleDate]
		  ,[StockSource]
		  ,[PriorityLevel]
		  ,[SMSAlertSetupDate]
		)
		select 
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,null as [UpdateStatus]
		  ,'P' as [MonitorTypeID]
		  ,null as [LastCourseOfSaleDate]
		  ,null as [StockSource]
		  ,null as [PriorityLevel]
		  ,null as [SMSAlertSetupDate]
		from
		(
			select ASXCode
			from #TempPostRaw
			where 1 = 1
			and datediff(day, PostDateTime, getdate()) < 14
			group by ASXCode
		) as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID ='P'
			and ASXCode = a.ASXCode
		)

		insert into StockData.MonitorStock
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,[MonitorTypeID]
		  ,[LastCourseOfSaleDate]
		  ,[StockSource]
		  ,[PriorityLevel]
		  ,[SMSAlertSetupDate]
		)
		select 
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,null as [UpdateStatus]
		  ,'O' as [MonitorTypeID]
		  ,null as [LastCourseOfSaleDate]
		  ,null as [StockSource]
		  ,null as [PriorityLevel]
		  ,null as [SMSAlertSetupDate]
		from
		(
			select ASXCode
			from #TempPostRaw
			where 1 = 1
			and datediff(day, PostDateTime, getdate()) < 14
			group by ASXCode
		) as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID ='O'
			and ASXCode = a.ASXCode
		)

		insert into StockData.MonitorStock
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,[MonitorTypeID]
		  ,[LastCourseOfSaleDate]
		  ,[StockSource]
		  ,[PriorityLevel]
		  ,[SMSAlertSetupDate]
		)
		select 
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,null as [UpdateStatus]
		  ,'A' as [MonitorTypeID]
		  ,null as [LastCourseOfSaleDate]
		  ,null as [StockSource]
		  ,null as [PriorityLevel]
		  ,null as [SMSAlertSetupDate]
		from
		(
			select ASXCode
			from #TempPostRaw
			where 1 = 1
			and datediff(day, PostDateTime, getdate()) < 14
			group by ASXCode
		) as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID ='A'
			and ASXCode = a.ASXCode
		)

		insert into StockData.MonitorStock
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,[MonitorTypeID]
		  ,[LastCourseOfSaleDate]
		  ,[StockSource]
		  ,[PriorityLevel]
		  ,[SMSAlertSetupDate]
		)
		select 
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,null as [UpdateStatus]
		  ,'H' as [MonitorTypeID]
		  ,null as [LastCourseOfSaleDate]
		  ,null as [StockSource]
		  ,null as [PriorityLevel]
		  ,null as [SMSAlertSetupDate]
		from
		(
			select ASXCode
			from #TempPostRaw
			where 1 = 1
			and datediff(day, PostDateTime, getdate()) < 14
			group by ASXCode
		) as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID ='H'
			and ASXCode = a.ASXCode
		)

		insert into StockData.MonitorStock
		(
		   [ASXCode]
		  ,[CreateDate]
		  ,[LastUpdateDate]
		  ,[UpdateStatus]
		  ,[MonitorTypeID]
		  ,[LastCourseOfSaleDate]
		  ,[StockSource]
		  ,[PriorityLevel]
		  ,[SMSAlertSetupDate]
		)
		select 
		   [ASXCode]
		  ,getdate() as [CreateDate]
		  ,null as [LastUpdateDate]
		  ,null as [UpdateStatus]
		  ,'R' as [MonitorTypeID]
		  ,null as [LastCourseOfSaleDate]
		  ,null as [StockSource]
		  ,null as [PriorityLevel]
		  ,null as [SMSAlertSetupDate]
		from
		(
			select ASXCode
			from #TempPostRaw
			where 1 = 1
			and datediff(day, PostDateTime, getdate()) < 14
			group by ASXCode
		) as a
		where not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID ='R'
			and ASXCode = a.ASXCode
		)

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

		delete a
		from Transform.CashVsMC as a

		dbcc checkident('Transform.CashVsMC', reseed, 1);

		insert into Transform.CashVsMC
		(
		   [CashVsMC]
		  ,[CashPosition]
		  ,[MC]
		  ,[ASXCode]
		)
		select 
			cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		--into Transform.CashVsMC
		from #TempCashPosition as a
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		delete a
		from [Transform].[TempStockNature] as a

		dbcc checkident('[Transform].[TempStockNature]', reseed, 1);

		insert into [Transform].[TempStockNature]
		(
			ASXCode, Nature
		)
		select a.ASXCode, stuff((
			select ',' + Token
			from StockData.StockNature
			where ASXCode = a.ASXCode
			order by AnnCount desc
			for xml path('')), 1, 1, ''
		) as Nature
		from StockData.StockNature as a
		group by a.ASXCode

		truncate table Transform.TempDirectorCurrent

		insert into Transform.TempDirectorCurrent
		(
			ASXCode, DirName
		)
		select a.ASXCode, a.DirName
		from StockData.DirectorCurrentPvt as a
	
		truncate table Transform.TempPostRaw

		insert into Transform.TempPostRaw
		(
			[PostRawID],
			[ASXCode],
			[Poster],
			[PostDateTime],
			[PosterIsHeart],
			[QualityPosterRating],
			[Sentiment],
			[Disclosure]
		)
		select
			PostRawID,
			ASXCode,
			Poster,
			PostDateTime,
			PosterIsHeart,
			QualityPosterRating,
			Sentiment,
			Disclosure
		from HC.TempPostLatest

		delete a
		from Transform.PosterList as a

		dbcc checkident('Transform.PosterList', reseed, 1);

		insert into Transform.PosterList
		(
			[ASXCode],
			[Poster]
		)
		select x.ASXCode, stuff((
			select ',' + [Poster]
			from Transform.TempPostRaw as a
			where x.ASXCode = a.ASXCode
			and (Sentiment in ('Buy') or Disclosure in ('Held'))
			and datediff(day, PostDateTime, getdate()) <= 120
			and exists
			(
				select 1
				from StockData.PriceHistoryCurrent
				where ASXCode = a.ASXCode
			)
			order by PostDateTime desc, isnull(QualityPosterRating, 200) asc
			for xml path('')), 1, 1, ''
		) as [Poster]
		from Transform.TempPostRaw as x
		where (Sentiment in ('Buy') or Disclosure in ('Held'))
		and datediff(day, PostDateTime, getdate()) <= 120
		and exists
		(
			select 1
			from StockData.PriceHistoryCurrent
			where ASXCode = x.ASXCode
		)
		group by x.ASXCode

		if object_id(N'Transform.PriceHistory24Month') is not null
			drop table Transform.PriceHistory24Month

		if object_id(N'Tempdb.dbo.#TempPriceHistory24Month') is not null
			drop table #TempPriceHistory24Month

		select cast(null as int) as ReverseRowNumber, *
		into #TempPriceHistory24Month
		from StockData.v_PriceHistory
		where ObservationDate > dateadd(day, -2*365, getdate())

		update a
		set ReverseRowNumber = b.ReverseRowNumber
		from #TempPriceHistory24Month as a
		inner join
		(
			select ObservationDate, ASXCode, row_number() over (partition by ASXCode order by ObservationDate desc) as ReverseRowNumber
			from #TempPriceHistory24Month
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode;

		WITH Base AS (
			SELECT
				PH.*,
				CAST(
					AVG(PH.[Close]) OVER (
						PARTITION BY PH.ASXCode
						ORDER BY PH.ObservationDate
						ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
					) AS DECIMAL(18,6)
				) AS SMA10,
				CAST(
					AVG(PH.[Close]) OVER (
						PARTITION BY PH.ASXCode
						ORDER BY PH.ObservationDate
						ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
					) AS DECIMAL(18,6)
				) AS SMA50
			FROM #TempPriceHistory24Month AS PH
		),
		BaseWithChange AS (
			SELECT
				b.*,
				CAST(
					CASE
						WHEN b.PrevClose IS NULL OR b.PrevClose = 0 THEN NULL
						ELSE 100.0 * (b.[Close] - b.PrevClose) / b.PrevClose
					END AS DECIMAL(18,4)
				) AS PriceChangePct
			FROM Base AS b
		)
		SELECT
			bwc.*,
			bwc.Volume AS TodayVolume,
			bwc.SMA10 AS TodaySMA10,
			LAG(bwc.SMA10, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_SMA10,
			LAG(bwc.SMA50, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_SMA50,
			LAG(bwc.Volume, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_Volume,
			LAG(bwc.PriceChangePct, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_PriceChangePct,
			LAG(bwc.SMA10, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_SMA10,
			LAG(bwc.SMA50, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_SMA50,
			LAG(bwc.Volume, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_Volume,
			LAG(bwc.PriceChangePct, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_PriceChangePct
		into Transform.PriceHistory24Month
		FROM BaseWithChange AS bwc;

		CREATE NONCLUSTERED INDEX idx_transformpricehistory24month_asxobdata
		ON [Transform].[PriceHistory24Month] ([ASXCode],[ObservationDate])
		INCLUDE ([TodayChange],[Next2DaysChange],[Next5DaysChange],[Next10DaysChange])

		exec [DataMaintenance].[usp_CacheTodayTradeBuyvsSell]
		@pbitFullRefresh = 1

		exec [DataMaintenance].[usp_CacheTokenPriceVolumeHistory]

		--UPDATE StockData.MoneyFlowInOutHistory
		truncate table Working.MoneyFlowInOutHistory

		declare @dtObservationDate as date = cast(getdate() as date)

		insert into [Working].[MoneyFlowInOutHistory]
		exec [StockData].[usp_MoneyFlowReportAllStock]
		@pdtObservationDate = @dtObservationDate,
		@pintLookbackDays = 90

		delete a
		from StockData.MoneyFlowInOutHistory as a
		inner join [Working].[MoneyFlowInOutHistory] as b
		on a.ASXCode = b.ASXCode
		and a.MarketDate = b.MarketDate

		insert into StockData.MoneyFlowInOutHistory
		select *
		from Working.MoneyFlowInOutHistory as a
		where not exists
		(
			select 1
			from StockData.MoneyFlowInOutHistory
			where ASXCode = a.ASXCode
			and MarketDate = a.MarketDate
		)

		if object_id(N'Transform.TweetSymbol') is not null
			drop table Transform.TweetSymbol

		select *, FriendlyName + '-' + right('0' + cast(month(CreateDateTimeUTC) as varchar(10)), 2) + + right('0' + cast(day(CreateDateTimeUTC) as varchar(10)), 2) as FriendlyNameWithDate
		into Transform.TweetSymbol
		from TT.v_TweetSymbol
		
		if object_id(N'Transform.TTSymbolUser') is not null
			drop table Transform.TTSymbolUser

		select distinct x.Symbol, x.Symbol + '.AX' as ASXCode, stuff((
			select top 10 ',' + [FriendlyNameWithDate]
			from Transform.TweetSymbol as a
			where x.Symbol = a.Symbol
			order by a.Rating asc
			for xml path('')), 1, 1, ''
		) as FriendlyNameList
		into Transform.TTSymbolUser
		from Transform.TweetSymbol as x

		--exec [DataMaintenance].[usp_RefreshTransformPriceHistoryNetVolume]

		exec Transform.usp_RefreshBrokerProfitLossRank

		exec [DataMaintenance].[usp_RefreshTransformPriceHistorySecondarySmart]

		exec [StockData].[usp_RefreshTopBrokerBuy]
		@pintNumPrevDay = 0

		exec [StockData].[usp_RefreshTopBrokerBuy]
		@pintNumPrevDay = 2

		exec [StockData].[usp_RefreshTopBrokerBuy]
		@pintNumPrevDay = 4

		exec [StockData].[usp_RefreshTopBrokerBuy]
		@pintNumPrevDay = 9
		
		--exec [StockData].[usp_RefeshStockCustomFilter]

		exec [DataMaintenance].[usp_CancelUnwantedOrders]

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainStockData failed'
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
