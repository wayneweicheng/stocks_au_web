-- Stored procedure: [DataMaintenance].[usp_CacheTodayTradeBuyvsSell]


--exec [DataMaintenance].[usp_CacheTodayTradeBuyvsSell]
--@pbitFullRefresh = 1

--exec [DataMaintenance].[usp_CacheTodayTradeBuyvsSell]
--@pbitFullRefresh = 1

--select * from Transform.TodayTradeBuyvsSell

CREATE PROCEDURE [DataMaintenance].[usp_CacheTodayTradeBuyvsSell]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pbitFullRefresh as bit = 0
AS
/******************************************************************************
File: usp_GetTodayTradeBuyvsSell.sql
Stored Procedure Name: usp_GetTodayTradeBuyvsSell
Overview
-----------------
usp_GetTodayTradeBuyvsSell

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
Date:		2018-06-26
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTodayTradeBuyvsSell'
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
		--select 
		--	ASXCode, 
		--	dateadd(hour, datepart(hour, DateFrom), cast(cast(DateFrom as date) as smalldatetime)) as DateHour, 
		--	isnull(BuySellInd, 'U') as BuySellInd, 
		--	sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
		--	avg(VWAP)*100.0 as VWAP 
		--from StockData.PriceSummary
		--where 1 = 1
		----and ASXCode = 'AVZ.AX'
		--and VWAP > 0
		--group by ASXCode, cast(DateFrom as date), datepart(hour, DateFrom), BuySellInd

		if object_id(N'#TempTodayTradeBuyvsSell') is not null
			drop table #TempTodayTradeBuyvsSell

		select *
		into #TempTodayTradeBuyvsSell
		from Transform.TodayTradeBuyvsSell
		where 1 = 0

		declare @pintNumPrevDay as int = 0

		declare @intFinishNumber as int
		if @pbitFullRefresh = 1
			select @intFinishNumber = 5
		else 
			select @intFinishNumber = 0

		while @pintNumPrevDay <= @intFinishNumber
		begin
			--delete a
			--from Transform.TodayTradeBuyvsSell as a
			--where NumPrevDay = @pintNumPrevDay

			declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

			declare @dtMaxHistory as date
			select @dtMaxHistory = max(ObservationDate) from StockData.PriceHistoryCurrent

			if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
				drop table #TempPriceSummary

			create table #TempPriceSummary
			(
				UniqueKey int identity(1, 1) not null,
				ASXCode varchar(10) not null,
				[Open] decimal(20, 4),
				[Close] decimal(20, 4),
				[PrevClose] decimal(20, 4),
				DateFrom datetime
			)

			if @pintNumPrevDay = 0
			begin
				insert into #TempPriceSummary
				(
					ASXCode,
					[Open],
					[Close],
					[PrevClose],
					DateFrom
				)
				select 
					ASXCode,
					[Open],
					[Close],
					[PrevClose],
					DateFrom
				from
				(
					select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, a.DateFrom, row_number() over (partition by a.ASXCode order by a.DateFrom desc) as RowNumber
					from StockData.PriceSummaryToday as a
					--inner join StockData.PriceHistoryCurrent as b
					--on a.ASXCode = b.ASXCode
					where ObservationDate = @dtDate
					and LatestForTheDay = 1
					and DateTo is null
				) as a
				where RowNumber = 1

				insert into #TempPriceSummary
				(
					ASXCode,
					[Open],
					[Close],
					[PrevClose],
					DateFrom 
				)
				select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, a.DateFrom
				from StockData.PriceSummary as a
				--inner join StockData.PriceHistoryCurrent as b
				--on a.ASXCode = b.ASXCode
				where ObservationDate = @dtDate
				and LatestForTheDay = 1
				and DateTo is null
				and not exists
				(
					select 1
					from #TempPriceSummary
					where ASXCode = a.ASXCode
				)

			end
			else
			begin
				insert into #TempPriceSummary
				(
					ASXCode,
					[Open],
					[Close],
					[PrevClose],
					DateFrom  
				)
				select a.ASXCode, a.[Open], a.[Close], a.[PrevClose] as PrevClose, a.DateFrom
				from StockData.PriceSummary as a
				where ObservationDate = @dtDate
				and LatestForTheDay = 1

				insert into #TempPriceSummary
				(
					ASXCode,
					[Open],
					[Close],
					[PrevClose],
					DateFrom
				)
				select
					ASXCode,
					[Open],
					[Close],
					[PrevClose],
					CreateDate as DateFrom
				from StockData.StockStatsHistoryPlus as a
				where ObservationDate = @dtDate			
				and not exists
				(
					select 1
					from #TempPriceSummary
					where ObservationDate = a.ObservationDate
					and ASXCode = a.ASXCode
				)

			end

			delete a
			from #TempPriceSummary as a
			where PrevClose = 0

			delete a
			from #TempPriceSummary as a
			inner join
			(
				select
					UniqueKey,
					row_number() over (partition by ASXCode order by DateFrom desc, UniqueKey asc) as RowNumber
				from #TempPriceSummary
			) as b
			on a.UniqueKey = b.UniqueKey
			where RowNumber > 1

			;with TodayTrade as
			(
				select 
					ASXCode, 
					cast(DateFrom as date) as CurrentDate,
					isnull(BuySellInd, 'U') as BuySellInd, 
					sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
					sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
					avg(VWAP)*100.0 as VWAP 
				from StockData.PriceSummary
				where cast(DateFrom as date) = @dtDate
				and VWAP > 0
				group by ASXCode, cast(DateFrom as date), BuySellInd
				union all
				select 
					ASXCode, 
					cast(DateFrom as date) as CurrentDate,
					isnull(BuySellInd, 'U') as BuySellInd, 
					sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
					sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
					avg(VWAP)*100.0 as VWAP 
				from StockData.PriceSummaryToday
				where cast(DateFrom as date) = @dtDate
				and VWAP > 0
				group by ASXCode, cast(DateFrom as date), BuySellInd
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
					) as [SearchTerm],
					row_number() over (partition by ASXCode order by AnnDateTime asc) as RowNumber
				from StockData.Announcement as x
				where cast(AnnDateTime as date) = @dtDate
			)

			insert into #TempTodayTradeBuyvsSell
			(
			   [ASXCode]
			  ,[CurrentDate]
			  ,[BuyTradeValue]
			  ,[SellTradeValue]
			  ,[TradeVolume]
			  ,[VWAP]
			  ,[BuyVsSell]
			  ,[MC]
			  ,[CashPosition]
			  ,[BuyVsMC]
			  ,[Poster]
			  ,[AnnDescr]
			  ,[SearchTerm]
			  ,[MovingAverage5d]
			  ,[MovingAverage10d]
			  ,[MovingAverage30d]
			  ,[MovingAverage60d]
			  ,[MovingAverage10dVol]
			  ,[VolumeVsAvg10]
			  ,[MovingAverage120dVol]
			  ,[VolumeVsAvg120]
			  ,[MaxClose20d]
			  ,[MinClose20d]
			  ,TrendMovingAverage60d
			  ,TrendMovingAverage200d
			  ,[Nature]
			  ,[ChangePerc]
			  ,[NumPrevDay]
			)
			select 
				a.ASXCode, 
				cast(a.CurrentDate as date) as CurrentDate, 
				cast(a.TradeValue/1000.0 as int) as BuyTradeValue, 
				cast(b.TradeValue/1000.0 as int) as SellTradeValue, 
				t.TradeVolume,
				cast(a.VWAP as decimal(20, 4)) as VWAP, 
				case when b.TradeValue > 0 then cast(a.TradeValue*100.0/b.TradeValue as decimal(20, 2)) else null end as BuyVsSell,
				c.MC,
				c.CashPosition,
				case when c.MC > 0 then a.TradeValue*100.0/(c.MC*1000000) else null end as BuyVsMC,
				d.Poster,
				f.AnnDescr,
				f.[SearchTerm],
				g.MovingAverage5d as MovingAverage5d,
				g.MovingAverage10d as MovingAverage10d,
				g.MovingAverage30d as MovingAverage30d,
				g.MovingAverage60d as MovingAverage60d,
				cast(g.MovingAverage10dVol as decimal(20, 2)) as MovingAverage120dVol,
				case when g.MovingAverage10dVol = 0 then 0 else cast(t.TradeVolume*100.0/g.MovingAverage10dVol as decimal(20, 2)) end VolumeVsAvg10,
				cast(g.MovingAverage120dVol as decimal(20, 2)) as MovingAverage120dVol,
				case when g.MovingAverage120dVol = 0 then 0 else cast(t.TradeVolume*100.0/g.MovingAverage120dVol as decimal(20, 2)) end VolumeVsAvg120,
				g.MaxClose20d,
				g.MinClose20d,
				g.TrendMovingAverage60d,
				g.TrendMovingAverage200d,
				e.Nature,
				cast((h.[Close] - h.[PrevClose])*100.0/h.[Prevclose] as decimal(20, 2)) as ChangePerc,
				@pintNumPrevDay as [NumPrevDay]
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
			left join Transform.CashVsMC as c
			on a.ASXCode = c.ASXCode
			left join Transform.PosterList as d
			on a.ASXCode = d.ASXCode
			left join Transform.TempStockNature as e
			on a.ASXCode = e.ASXCode
			left join Announcement as f
			on a.ASXCode = f.ASXCode
			and f.RowNumber = 1
			left join StockData.v_StockStatsHistoryPlusCurrent as g
			on a.ASXCode = g.ASXCode
			left join #TempPriceSummary as h
			on a.ASXCode = h.ASXCode
			where 1 = 1
			--and b.TradeValue > 0
			--and a.TradeValue > 60000
			order by isnull(case when b.TradeValue > 0 then a.TradeValue*100.0/b.TradeValue else null end, 0) desc

			select @pintNumPrevDay = @pintNumPrevDay + 1
		end

		if @pbitFullRefresh = 1
		begin
			delete a
			from Transform.TodayTradeBuyvsSell as a

			dbcc checkident('Transform.TodayTradeBuyvsSell', reseed, 1);
		end
		else
		begin
			delete a
			from Transform.TodayTradeBuyvsSell as a
			where exists
			(
				select 1
				from #TempTodayTradeBuyvsSell
				where CurrentDate = a.CurrentDate
			)
		end

		insert into Transform.TodayTradeBuyvsSell
		(
		   [ASXCode]
		  ,[CurrentDate]
		  ,[BuyTradeValue]
		  ,[SellTradeValue]
		  ,[TradeVolume]
		  ,[VWAP]
		  ,[BuyVsSell]
		  ,[MC]
		  ,[CashPosition]
		  ,[BuyVsMC]
		  ,TrendMovingAverage60d
		  ,TrendMovingAverage200d
		  ,[Poster]
		  ,[AnnDescr]
		  ,[SearchTerm]
		  ,[MovingAverage5d]
		  ,[MovingAverage10d]
		  ,[MovingAverage30d]
		  ,[MovingAverage60d]
		  ,[MovingAverage10dVol]
		  ,[VolumeVsAvg10]
		  ,[MovingAverage120dVol]
		  ,[VolumeVsAvg120]
		  ,[MaxClose20d]
		  ,[MinClose20d]
		  ,[Nature]
		  ,[ChangePerc]
		  ,[NumPrevDay]
		)
		select
		   [ASXCode]
		  ,[CurrentDate]
		  ,[BuyTradeValue]
		  ,[SellTradeValue]
		  ,[TradeVolume]
		  ,[VWAP]
		  ,[BuyVsSell]
		  ,[MC]
		  ,[CashPosition]
		  ,[BuyVsMC]
		  ,TrendMovingAverage60d
		  ,TrendMovingAverage200d
		  ,[Poster]
		  ,[AnnDescr]
		  ,[SearchTerm]
		  ,[MovingAverage5d]
		  ,[MovingAverage10d]
		  ,[MovingAverage30d]
		  ,[MovingAverage60d]
		  ,[MovingAverage10dVol]
		  ,[VolumeVsAvg10]
		  ,[MovingAverage120dVol]
		  ,[VolumeVsAvg120]
		  ,[MaxClose20d]
		  ,[MinClose20d]
		  ,[Nature]
		  ,[ChangePerc]
		  ,[NumPrevDay]
		from #TempTodayTradeBuyvsSell as a
		where not exists
		(
			select 1
			from Transform.TodayTradeBuyvsSell
			where CurrentDate = a.CurrentDate
		)

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
