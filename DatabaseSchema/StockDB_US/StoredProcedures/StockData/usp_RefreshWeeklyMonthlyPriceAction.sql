-- Stored procedure: [StockData].[usp_RefreshWeeklyMonthlyPriceAction]


CREATE PROCEDURE [StockData].[usp_RefreshWeeklyMonthlyPriceAction]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshWeeklyMonthlyPriceAction.sql
Stored Procedure Name: usp_RefreshWeeklyMonthlyPriceAction
Overview
-----------------
usp_RefreshWeeklyMonthlyPriceAction

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
Date:		2019-08-03
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshWeeklyMonthlyPriceAction'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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
		if object_id(N'Tempdb.dbo.#TempStockStatsHistoryPlusMonthly') is not null
			drop table #TempStockStatsHistoryPlusMonthly

		select *
		into #TempStockStatsHistoryPlusMonthly
		from
		(
			select 
			*, 
			lag(MovingAverage5d, 3) over (partition by ASXCode order by ObservationDate) as Prev3MovingAverage5d,
			lag(MovingAverage5d, 2) over (partition by ASXCode order by ObservationDate) as Prev2MovingAverage5d,
			lag(MovingAverage5d, 1) over (partition by ASXCode order by ObservationDate) as Prev1MovingAverage5d,
			row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber 
			from [StockData].[StockStatsHistoryPlusMonthly]
		) as a
		where RowNumber = 1

		delete a
		from #TempStockStatsHistoryPlusMonthly as a
		inner join LookupRef.DimDate as b
		on cast(getdate() as date) = b.[Date]
		where a.ObservationDate < b.FirstDateofMonth

		if object_id(N'StockData.MonthlyCurrent') is not null
			drop table StockData.MonthlyCurrent

		select *
		into StockData.MonthlyCurrent
		from #TempStockStatsHistoryPlusMonthly

		if object_id(N'Tempdb.dbo.#TempStockStatsHistoryPlusWeekly') is not null
			drop table #TempStockStatsHistoryPlusWeekly

		select *
		into #TempStockStatsHistoryPlusWeekly
		from
		(
			select 
			*, 
			lag([Close], 2) over (partition by ASXCode order by ObservationDate) as Prev2Close,
			lag([Close], 1) over (partition by ASXCode order by ObservationDate) as Prev1Close,
			lag(MovingAverage5d, 2) over (partition by ASXCode order by ObservationDate) as Prev2MovingAverage5d,
			lag(MovingAverage5d, 1) over (partition by ASXCode order by ObservationDate) as Prev1MovingAverage5d,
			lag(MovingAverage10d, 2) over (partition by ASXCode order by ObservationDate) as Prev2MovingAverage10d,
			lag(MovingAverage10d, 1) over (partition by ASXCode order by ObservationDate) as Prev1MovingAverage10d,
			row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber 
			from [StockData].[StockStatsHistoryPlusWeekly]
		) as a
		where RowNumber = 1

		delete a
		--select a.ObservationDate, case when b.WeekDayName_Short = 'SUN' then dateadd(day, -7, b.FirstDateofWeek) else dateadd(day, 0, b.FirstDateofWeek) end, *
		from #TempStockStatsHistoryPlusWeekly as a
		inner join LookupRef.DimDate as b
		on cast(getdate() as date) = b.[Date]
		where a.ObservationDate < case when b.WeekDayName_Short = 'SUN' then dateadd(day, -7, b.FirstDateofWeek) else dateadd(day, 0, b.FirstDateofWeek) end

		if object_id(N'StockData.WeeklyCurrent') is not null
			drop table StockData.WeeklyCurrent

		select *
		into StockData.WeeklyCurrent
		from #TempStockStatsHistoryPlusWeekly

		if object_id(N'Tempdb.dbo.#TempWeeklyMonthlyPriceAction') is not null
			drop table #TempWeeklyMonthlyPriceAction

		select *
		into #TempWeeklyMonthlyPriceAction
		from
		(
			select 
				m.ASXCode,
				m.ObservationDate,
				m.FirstDateofMonth,
				m.LastDateofMonth,
				w.FirstDateofWeek,
				w.LastDateofWeek,
				m.[Close] as [Close],
				m.MovingAverage5d as MonthlyMovingAverage5d,
				m.MovingAverage10d as MonthlyMovingAverage10d,
				m.Prev1MovingAverage5d as MonthlyPrev1MovingAverage5d,
				m.Prev2MovingAverage5d as MonthlyPrev2MovingAverage5d,
				w.MovingAverage5d as WeeklyMovingAverage5d,
				w.MovingAverage10d as WeeklyMovingAverage10d,
				w.Prev1MovingAverage5d as WeeklyPrev1MovingAverage5d,
				w.Prev1MovingAverage10d as WeeklyPrev1MovingAverage10d,
				cast(mv.MedianTradeValue as int) as MedianTradeValueWeekly,
				cast(mv.MedianTradeValueDaily as int) as MedianTradeValueDaily,
				mv.MedianPriceChangePerc as MedianPriceChangePerc,
				'Retreat to Weekly MA10' as ActionType
			from 
			(
				select b.LastDateofMonth, b.FirstDateofMonth, a.*
				from
				(
					select 
						*
					from #TempStockStatsHistoryPlusMonthly as x
					where exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValue > 800
						and x.ASXCode = ASXCode
					)
				) as a
				inner join LookupRef.DimDate as b
				on a.ObservationDate = b.[Date]
				where MovingAverage5d > Prev1MovingAverage5d
			) as m
			inner join
			(
				select b.LastDateofWeek, b.FirstDateofWeek, a.*
				from
				(
					select 
						*
					from #TempStockStatsHistoryPlusWeekly as x
					where exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValue > 800
						and x.ASXCode = ASXCode
					)
				) as a
				inner join LookupRef.DimDate as b
				on a.ObservationDate = b.[Date]
				where 1 = 1
				--and MovingAverage5d > Prev1MovingAverage5d
				--and Prev1MovingAverage5d <= Prev2MovingAverage5d
				and MovingAverage10d > Prev1MovingAverage10d
				--and Prev1MovingAverage10d <= Prev2MovingAverage10d
			) as w
			on 1 = 1
			--and w.FirstDateofWeek >= m.FirstDateofMonth
			--and w.LastDateofWeek <= dateadd(day, 5, m.LastDateofMonth)
			and cast(getdate() as date) between w.FirstDateofWeek and w.LastDateofWeek
			and cast(getdate() as date) between m.FirstDateofMonth and m.LastDateofMonth
			and m.ASXCode = w.ASXCode
			and w.[Close] <= w.MovingAverage10d*1.02
			and w.[Prev1Close] > w.Prev1MovingAverage10d
			inner join StockData.MedianTradeValue as mv
			on m.ASXCode = mv.ASXCode
			union
			select 
				m.ASXCode,
				m.ObservationDate,
				m.FirstDateofMonth,
				m.LastDateofMonth,
				w.FirstDateofWeek,
				w.LastDateofWeek,
				m.[Close] as [Close],
				m.MovingAverage5d as MonthlyMovingAverage5d,
				m.MovingAverage10d as MonthlyMovingAverage10d,
				m.Prev1MovingAverage5d as MonthlyPrev1MovingAverage5d,
				m.Prev2MovingAverage5d as MonthlyPrev2MovingAverage5d,
				w.MovingAverage5d as WeeklyMovingAverage5d,
				w.MovingAverage10d as WeeklyMovingAverage10d,
				w.Prev1MovingAverage5d as WeeklyPrev1MovingAverage5d,
				w.Prev1MovingAverage10d as WeeklyPrev1MovingAverage10d,
				cast(mv.MedianTradeValue as int) as MedianTradeValueWeekly,
				cast(mv.MedianTradeValueDaily as int) as MedianTradeValueDaily,
				mv.MedianPriceChangePerc as MedianPriceChangePerc,
				'Retreat to Weekly MA5' as ActionType
			from 
			(
				select b.LastDateofMonth, b.FirstDateofMonth, a.*
				from
				(
					select 
						*
					from #TempStockStatsHistoryPlusMonthly as x
					where exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValue > 800
						and x.ASXCode = ASXCode
					)
				) as a
				inner join LookupRef.DimDate as b
				on a.ObservationDate = b.[Date]
				where MovingAverage5d > Prev1MovingAverage5d
			) as m
			inner join
			(
				select b.LastDateofWeek, b.FirstDateofWeek, a.*
				from
				(
					select 
						*
					from #TempStockStatsHistoryPlusWeekly as x
					where exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValue > 800
						and x.ASXCode = ASXCode
					)
				) as a
				inner join LookupRef.DimDate as b
				on a.ObservationDate = b.[Date]
				where 1 = 1
				and MovingAverage5d > Prev1MovingAverage5d
				--and Prev1MovingAverage5d <= Prev2MovingAverage5d
				and MovingAverage10d > Prev1MovingAverage10d
				--and Prev1MovingAverage10d <= Prev2MovingAverage10d
			) as w
			on 1 = 1
			--and w.FirstDateofWeek >= m.FirstDateofMonth
			--and w.LastDateofWeek <= dateadd(day, 5, m.LastDateofMonth)
			and cast(getdate() as date) between w.FirstDateofWeek and w.LastDateofWeek
			and cast(getdate() as date) between m.FirstDateofMonth and m.LastDateofMonth
			and m.ASXCode = w.ASXCode
			and w.[Close] <= w.MovingAverage5d*1.02
			and w.[Prev1Close] > w.Prev1MovingAverage5d
			inner join StockData.MedianTradeValue as mv
			on m.ASXCode = mv.ASXCode
		) as x

		delete a
		from StockData.WeeklyMonthlyPriceAction as a
		where cast(CreateDate as date) = cast(getdate() as date)

		insert into StockData.WeeklyMonthlyPriceAction
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[FirstDateofMonth]
		  ,[LastDateofMonth]
		  ,[FirstDateofWeek]
		  ,[LastDateofWeek]
		  ,[Close]
		  ,[MonthlyMovingAverage5d]
		  ,[MonthlyMovingAverage10d]
		  ,[MonthlyPrev1MovingAverage5d]
		  ,[MonthlyPrev2MovingAverage5d]
		  ,[WeeklyMovingAverage5d]
		  ,[WeeklyMovingAverage10d]
		  ,[WeeklyPrev1MovingAverage5d]
		  ,[WeeklyPrev1MovingAverage10d]
		  ,[MedianTradeValueWeekly]
		  ,[MedianTradeValueDaily]
		  ,[MedianPriceChangePerc]
		  ,ActionType
		  ,[CreateDate]
		)
		select
		   [ASXCode]
		  ,[ObservationDate]
		  ,[FirstDateofMonth]
		  ,[LastDateofMonth]
		  ,[FirstDateofWeek]
		  ,[LastDateofWeek]
		  ,[Close]
		  ,[MonthlyMovingAverage5d]
		  ,[MonthlyMovingAverage10d]
		  ,[MonthlyPrev1MovingAverage5d]
		  ,[MonthlyPrev2MovingAverage5d]
		  ,[WeeklyMovingAverage5d]
		  ,[WeeklyMovingAverage10d]
		  ,[WeeklyPrev1MovingAverage5d]
		  ,[WeeklyPrev1MovingAverage10d]
		  ,[MedianTradeValueWeekly]
		  ,[MedianTradeValueDaily]
		  ,[MedianPriceChangePerc]
		  ,ActionType
		  ,getdate() as [CreateDate]
		from #TempWeeklyMonthlyPriceAction
		
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
