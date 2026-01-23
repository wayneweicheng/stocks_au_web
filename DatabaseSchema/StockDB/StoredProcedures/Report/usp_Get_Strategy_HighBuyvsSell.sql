-- Stored procedure: [Report].[usp_Get_Strategy_HighBuyvsSell]



--exec [Report].[usp_GetVWAPRiseFromTrough]
--@pintNumPrevDay = 8

CREATE PROCEDURE [Report].[usp_Get_Strategy_HighBuyvsSell]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_HighBuyvsSell.sql
Stored Procedure Name: usp_Get_Strategy_HighBuyvsSell
Overview
-----------------
usp_Get_Strategy_HighBuyvsSell

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
Date:		2018-08-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_HighBuyvsSell'
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
		--declare @pintNumPrevDay as int = 18

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		
		declare @dtNextDate as date = cast(Common.DateAddBusinessDay(1, @dtDate) as date)
		declare @dtNext2Date as date = cast(Common.DateAddBusinessDay(2, @dtDate) as date)
		declare @dtNext3Date as date = cast(Common.DateAddBusinessDay(3, @dtDate) as date)

		if object_id(N'Tempdb.dbo.#TempMFResult') is not null
			drop table #TempMFResult

		CREATE TABLE #TempMFResult(
			[ASXCode] [varchar](10) NULL,
			[MarketDate] [varchar](100) NULL,
			[MoneyFlowAmount] [decimal](20, 3) NULL,
			[MoneyFlowAmountIn] [decimal](20, 3) NULL,
			[MoneyFlowAmountOut] [decimal](20, 3) NULL,
			[CumulativeMoneyFlowAmount] [decimal](20, 3) NULL,
			[PriceChangePerc] [nvarchar](4000) NULL,
			[InPerc] [nvarchar](4000) NULL,
			[OutPerc] [nvarchar](4000) NULL,
			[InNumTrades] [int] NULL,
			[OutNumTrades] [int] NULL,
			[InAvgSize] [nvarchar](4000) NULL,
			[OutAvgSize] [nvarchar](4000) NULL,
			[Open] [nvarchar](4000) NULL,
			[High] [nvarchar](4000) NULL,
			[Low] [nvarchar](4000) NULL,
			[Close] [nvarchar](4000) NULL,
			[VWAP] [nvarchar](4000) NULL,
			[Volume] [nvarchar](4000) NULL,
			[Value] [nvarchar](4000) NULL,
			[RowNumber] [bigint] NULL
		) ON [PRIMARY]

		insert into #TempMFResult
		exec [StockData].[usp_MoneyFlowReportAllStock]
		@pdtObservationDate = @dtDate

		update a
		set
			[Open] = replace([Open], ',', ''),
			[Close] = replace([Close], ',', ''),
			[High] = replace([High], ',', ''),
			[Low] = replace([Low], ',', ''),
			[VWAP] = replace([VWAP], ',', ''),
			[Volume] = replace([Volume], ',', ''),
			[Value] = replace([Value], ',', '')
		from #TempMFResult as a

		if object_id(N'Tempdb.dbo.#TempCandidate') is not null
			drop table #TempCandidate

		select b.* 
		into #TempCandidate
		from #TempMFResult as b
		inner join #TempMFResult as a
		on a.ASXCode = b.ASXCode
		and a.RowNumber = b.RowNumber + 1
		and try_cast(a.VWAP as decimal(20, 4)) < try_cast(b.VWAP as decimal(20, 4))
		--and try_cast(a.[Close] as decimal(20, 4)) < try_cast(a.VWAP as decimal(20, 4))
		--and try_cast(b.[Close] as decimal(20, 4)) >= try_cast(b.VWAP as decimal(20, 4))
		and try_cast(b.[Close] as decimal(20, 4)) < try_cast(b.VWAP as decimal(20, 4))*1.05
		where 1 = 1
		and b.MarketDate = @dtDate
		--and (try_cast(b.[High] as decimal(20, 4)) + try_cast(b.[Low] as decimal(20, 4)))/2.0 <= try_cast(b.[Close] as decimal(20, 4))
		order by b.MarketDate desc

		declare @dtMaxHistory as date
		select @dtMaxHistory = max(ObservationDate) from StockData.PriceHistoryCurrent

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		create table #TempPriceSummary
		(
			ASXCode varchar(10) not null,
			[Open] decimal(20, 4),
			[Close] decimal(20, 4),
			[PrevClose] decimal(20, 4)
		)

		if @pintNumPrevDay = 0 and (cast(getdate() as date) > @dtMaxHistory)
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 
			)
			select a.ASXCode, a.[Open], a.[Close], b.[Close] as PrevClose
			from StockData.PriceSummary as a
			inner join StockData.PriceHistoryCurrent as b
			on a.ASXCode = b.ASXCode
			where a.ObservationDate = cast(dateadd(day, 0, getdate()) as date)
			and DateTo is null
		end
		else
		begin
			insert into #TempPriceSummary
			(
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 
			)
			select
				ASXCode,
				[Open],
				[Close],
				[PrevClose] 			
			from StockData.StockStatsHistoryPlus as a
			where ObservationDate = @dtDate		
		end

		delete a
		from #TempPriceSummary as a
		where PrevClose = 0

		if object_id(N'Tempdb.dbo.#TempNextDay') is not null
			drop table #TempNextDay

		select a.ObservationDate, a.ASXCode, a.[Open], a.[Close], a.[High], a.[Low]
		into #TempNextDay
		from StockData.PriceHistory as a
		where ObservationDate = @dtNextDate

		if object_id(N'Tempdb.dbo.#Temp2NextDay') is not null
			drop table #Temp2NextDay

		select a.ObservationDate, a.ASXCode, a.[Open], a.[Close], a.[High], a.[Low]
		into #Temp2NextDay
		from StockData.PriceHistory as a
		where ObservationDate = @dtNext2Date

		if object_id(N'Tempdb.dbo.#Temp3NextDay') is not null
			drop table #Temp3NextDay

		select a.ObservationDate, a.ASXCode, a.[Open], a.[Close], a.[High], a.[Low]
		into #Temp3NextDay
		from StockData.PriceHistory as a
		where ObservationDate = @dtNext3Date

		if @pbitASXCodeOnly = 0
		begin

			;with TodayTrade as
			(
			select 
				ASXCode, 
				ObservationDate as CurrentDate,
				isnull(BuySellInd, 'U') as BuySellInd, 
				sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
				sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
				avg(VWAP)*100.0 as VWAP
			from StockData.PriceSummary
			where ObservationDate = @dtDate
			and VWAP > 0
			group by ASXCode, ObservationDate, BuySellInd
			),
		
			Announcement as
			(
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
				) as [SearchTerm]
			from StockData.Announcement as x
			where cast(AnnDateTime as date) = @dtDate
			)

			select 
				a.ASXCode, 
				cast(a.CurrentDate as date) as CurrentDate, 
				cast(a.TradeValue as int) as BuyTradeValue, 
				cast(b.TradeValue as int) as SellTradeValue, 
				t.TradeVolume,
				cast(case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end as int) as VolumeVsAvg120,
				a.VWAP, 
				cast(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end as decimal(10, 1)) as BuyVsSell,
				ttsu.FriendlyNameList,
				cast(c.MC as decimal(10, 2)) as MC,
				cast(c.CashPosition as decimal(10, 2)) as CashPosition,
				cast(case when c.MC > 0 then a.TradeValue*100.0/(c.MC*1000000) else null end as decimal(10, 2)) as BuyVsMC,
				d.Poster,
				f.AnnDescr,
				f.[SearchTerm],
				cast((g.MovingAverage5d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage5d,
				cast((g.MovingAverage10d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage10d,
				cast((g.MovingAverage30d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage30d,
				cast((g.MovingAverage60d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage60d,
				g.MovingAverage10dVol,
				cast(case when g.MovingAverage10dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage10dVol end as decimal(10, 2)) as VolumeVsAvg10,
				g.MovingAverage120dVol,
				g.MaxClose20d,
				g.MinClose20d,
				e.Nature,
				case when h.[Prevclose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(10, 2)) else null end as ChangePerc,
				@pintNumPrevDay as [NumPrevDay],
				case when n1.[High] > 0 then cast((n1.[High] - h.[Close])*100.0/h.[Close] as decimal(10, 2)) else null end as PercNext1dHigh,
				case when n1.[Low] > 0 then cast((n1.[Low] - h.[Close])*100.0/n1.[Low] as decimal(10, 2)) else null end as PercNext1dLow,
				case when n2.[High] > 0 then cast((n2.[High] - h.[Close])*100.0/h.[Close] as decimal(10, 2)) else null end as PercNext2dHigh,
				case when n2.[Low] > 0 then cast((n2.[Low] - h.[Close])*100.0/n2.[Low] as decimal(10, 2)) else null end as PercNext2dLow,
				case when n3.[High] > 0 then cast((n3.[High] - h.[Close])*100.0/h.[Close] as decimal(10, 2)) else null end as PercNext3dHigh,
				case when n3.[Low] > 0 then cast((n3.[Low] - h.[Close])*100.0/n3.[Low] as decimal(10, 2)) else null end as PercNext3dLow
			from TodayTrade as a
			inner join TodayTrade as b
			on a.ASXCode = b.ASXCode
			and a.CurrentDate = b.CurrentDate
			and a.BuySellInd = 'B'
			and b.BuySellInd = 'S'
			inner join 
			(
				select ASXCode, CurrentDate, sum(TradeVolume) as TradeVolume
				from TodayTrade
				group by ASXCode, CurrentDate
			) as t
			on a.ASXCode = t.ASXCode
			and a.CurrentDate = t.CurrentDate
			inner join #TempCandidate as x
			on a.ASXCode = x.ASXCode
			left join Transform.CashVsMC as c
			on a.ASXCode = c.ASXCode
			left join Transform.PosterList as d
			on a.ASXCode = d.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join Announcement as f
			on a.ASXCode = f.ASXCode
			left join StockData.StockStatsHistoryPlusCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			left join #TempNextDay as n1
			on a.ASXCode = n1.ASXCode
			left join #Temp2NextDay as n2
			on a.ASXCode = n2.ASXCode
			left join #Temp3NextDay as n3
			on a.ASXCode = n3.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where 1 = 1
			--and a.ASXCode = 'DYL.AX'
			and
			(
				(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end > 150.0 and case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end > 200)
				or
				(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end > 300.0 and case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end > 150)
			)
			and a.TradeValue > 100000
			and c.MC < 750
			and case when c.MC > 0 then a.TradeValue*100.0/(c.MC*1000000) else null end > 0.1
			and case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end > 200
			and h.[Close] >= h.[Open]
			--and b.TradeValue > 0
			--and a.TradeValue > 60000
			order by isnull(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end, 0) desc
		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempOutput') is not null
				drop table #TempOutput

			;with TodayTrade as
			(
			select 
				ASXCode, 
				ObservationDate as CurrentDate,
				isnull(BuySellInd, 'U') as BuySellInd, 
				sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
				sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
				avg(VWAP)*100.0 as VWAP
			from StockData.PriceSummary
			where ObservationDate = @dtDate
			and VWAP > 0
			group by ASXCode, ObservationDate, BuySellInd
			),
		
			Announcement as
			(
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
				) as [SearchTerm]
			from StockData.Announcement as x
			where cast(AnnDateTime as date) = @dtDate
			)

			select 
			identity(int, 1, 1) as DisplayOrder,
			*
			into #TempOutput
			from
			(
				select 
					a.ASXCode, 
					cast(a.CurrentDate as date) as CurrentDate, 
					cast(a.TradeValue as int) as BuyTradeValue, 
					cast(b.TradeValue as int) as SellTradeValue, 
					t.TradeVolume,
					cast(case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end as int) as VolumeVsAvg120,
					a.VWAP, 
					cast(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end as decimal(10, 1)) as BuyVsSell,
					cast(c.MC as decimal(10, 2)) as MC,
					cast(c.CashPosition as decimal(10, 2)) as CashPosition,
					cast(case when c.MC > 0 then a.TradeValue*100.0/(c.MC*1000000) else null end as decimal(10, 2)) as BuyVsMC,
					d.Poster,
					f.AnnDescr,
					f.[SearchTerm],
					cast((g.MovingAverage5d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage5d,
					cast((g.MovingAverage10d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage10d,
					cast((g.MovingAverage30d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage30d,
					cast((g.MovingAverage60d*100.0-a.VWAP)*100.0/a.VWAP as decimal(20, 4)) as MovingAverage60d,
					g.MovingAverage10dVol,
					cast(case when g.MovingAverage10dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage10dVol end as decimal(10, 2)) as VolumeVsAvg10,
					g.MovingAverage120dVol,
					g.MaxClose20d,
					g.MinClose20d,
					e.Nature,
					case when h.[Prevclose] > 0 then cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(10, 2)) else null end as ChangePerc,
					@pintNumPrevDay as [NumPrevDay],
					case when n1.[High] > 0 then cast((n1.[High] - h.[Close])*100.0/h.[Close] as decimal(10, 2)) else null end as PercNext1dHigh,
					case when n1.[Low] > 0 then cast((n1.[Low] - h.[Close])*100.0/n1.[Low] as decimal(10, 2)) else null end as PercNext1dLow,
					case when n2.[High] > 0 then cast((n2.[High] - h.[Close])*100.0/h.[Close] as decimal(10, 2)) else null end as PercNext2dHigh,
					case when n2.[Low] > 0 then cast((n2.[Low] - h.[Close])*100.0/n2.[Low] as decimal(10, 2)) else null end as PercNext2dLow,
					case when n3.[High] > 0 then cast((n3.[High] - h.[Close])*100.0/h.[Close] as decimal(10, 2)) else null end as PercNext3dHigh,
					case when n3.[Low] > 0 then cast((n3.[Low] - h.[Close])*100.0/n3.[Low] as decimal(10, 2)) else null end as PercNext3dLow
				from TodayTrade as a
				inner join TodayTrade as b
				on a.ASXCode = b.ASXCode
				and a.CurrentDate = b.CurrentDate
				and a.BuySellInd = 'B'
				and b.BuySellInd = 'S'
				inner join 
				(
					select ASXCode, CurrentDate, sum(TradeVolume) as TradeVolume
					from TodayTrade
					group by ASXCode, CurrentDate
				) as t
				on a.ASXCode = t.ASXCode
				and a.CurrentDate = t.CurrentDate
				inner join #TempCandidate as x
				on a.ASXCode = x.ASXCode
				left join Transform.CashVsMC as c
				on a.ASXCode = c.ASXCode
				left join Transform.PosterList as d
				on a.ASXCode = d.ASXCode
				left join Transform.TempStockNature as e
				on a.ASXCode = e.ASXCode
				left join Announcement as f
				on a.ASXCode = f.ASXCode
				left join StockData.StockStatsHistoryPlusCurrent as g
				on a.ASXCode = g.ASXCode
				left join #TempPriceSummary as h
				on a.ASXCode = h.ASXCode
				left join #TempNextDay as n1
				on a.ASXCode = n1.ASXCode
				left join #Temp2NextDay as n2
				on a.ASXCode = n2.ASXCode
				left join #Temp3NextDay as n3
				on a.ASXCode = n3.ASXCode
				where 1 = 1
				--and a.ASXCode = 'DYL.AX'
				and
				(
					(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end > 150.0 and case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end > 200)
					or
					(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end > 300.0 and case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end > 150)
				)
				and a.TradeValue > 100000
				and c.MC < 750
				and case when c.MC > 0 then a.TradeValue*100.0/(c.MC*1000000) else null end > 0.1
				and case when g.MovingAverage120dVol = 0 then 0 else t.TradeVolume*100.0/g.MovingAverage120dVol end > 200
				and h.[Close] >= h.[Open]
				--and b.TradeValue > 0
				--and a.TradeValue > 60000
			) as x
			order by isnull(case when SellTradeValue > 0 then BuyTradeValue*100.0/SellTradeValue else null end, 0) desc

			select
				distinct
				ASXCode,
				DisplayOrder
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
