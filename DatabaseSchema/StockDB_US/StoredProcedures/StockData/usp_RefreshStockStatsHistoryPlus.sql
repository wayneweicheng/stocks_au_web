-- Stored procedure: [StockData].[usp_RefreshStockStatsHistoryPlus]


CREATE PROCEDURE [StockData].[usp_RefreshStockStatsHistoryPlus]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshStockStatsHistoryPlus.sql
Stored Procedure Name: usp_RefreshStockStatsHistoryPlus
Overview
-----------------
usp_RefreshStockStatsHistoryPlus

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
Date:		2018-05-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshStockStatsHistoryPlus'
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
		--truncate table [StockData].[StockStatsHistoryPlus]
		declare @dtScopeDate as date
		--select @dtScopeDate = cast(Common.DateAddBusinessDay(-1 * 120, (select max(ObservationDate) from StockData.StockStatsHistoryPlus)) as date)
		select @dtScopeDate = cast(Common.DateAddBusinessDay(-1 * 720, (select max(ObservationDate) from StockData.StockStatsHistoryPlus)) as date)
		declare @intRowCount as int = 0
		
		insert into [StockData].[StockStatsHistoryPlus]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[CreateDate]
		  ,[DateSeq]
		  ,DateSeqReverse
		)
		select
		   a.[ASXCode]
		  ,a.[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[CreateDate]
		  ,null as [DateSeq]
		  ,null as DateSeqReverse
		from [StockData].[PriceHistory] as a
		inner join 
		(
			select ASXCode, max(ObservationDate) as ObservationDate
			from StockData.StockStatsHistoryPlus
			group by ASXCode
		) as b
		on a.ObservationDate > b.ObservationDate
		and a.ASXCode = b.ASXCode
		where 1 = 1
		and Volume > 0
		and [Open] > 0
		union all
		select
		   a.[ASXCode]
		  ,a.[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,[CreateDate]
		  ,null as [DateSeq]
		  ,null as DateSeqReverse
		from [StockData].[PriceHistory] as a
		left join 
		(
			select ASXCode, max(ObservationDate) as ObservationDate
			from StockData.StockStatsHistoryPlus
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		where 1 = 1
		and b.ASXCode is null
		and Volume > 0
		and [Open] > 0
		and a.ObservationDate >= dateadd(day, -720, getdate())
		
		select @intRowCount = @@ROWCOUNT

		declare @dtPurgeDate as date
		select @dtPurgeDate = cast(Common.DateAddBusinessDay(-1 * 400, getdate()) as date)
		select @dtPurgeDate 

		delete a
		from StockData.StockStatsHistoryPlus as a
		where ObservationDate < @dtPurgeDate 

		update a
		set a.DateSeq = b.RowNumber
		from [StockData].[StockStatsHistoryPlus] as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate) as RowNumber
			from [StockData].[StockStatsHistoryPlus]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		update a
		set a.DateSeqReverse = b.RowNumber
		from [StockData].[StockStatsHistoryPlus] as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from [StockData].[StockStatsHistoryPlus]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		
		update a
		set a.PrevClose = b.[Close]
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq = b.DateSeq + 1
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate

		update a
		set 
			a.MovingAverage5d = b.MovingAverage5d,
			a.MovingAverage10d = b.MovingAverage10d,
			a.MovingAverage15d = b.MovingAverage15d,
			a.MovingAverage20d = b.MovingAverage20d,
			a.MovingAverage30d = b.MovingAverage30d,
			a.MovingAverage60d = b.MovingAverage60d,
			a.MovingAverage120d = b.MovingAverage120d,
			a.MovingAverage135d = b.MovingAverage135d,
			a.MovingAverage200d = b.MovingAverage200d
		from [StockData].[StockStatsHistoryPlus] as a
		inner join
		(
			select 
				ObservationDate,
				ASXCode,
				MovingAverage5d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 4 preceding),
				MovingAverage10d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 9 preceding),
				MovingAverage15d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 14 preceding),
				MovingAverage20d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 19 preceding),
				MovingAverage30d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 29 preceding),
				MovingAverage60d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 59 preceding),
				MovingAverage120d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 119 preceding),
				MovingAverage135d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 134 preceding),
				MovingAverage200d = avg([Close]) over (partition by ASXCode order by DateSeq asc rows 199 preceding)
			from [StockData].[StockStatsHistoryPlus]
			--where ObservationDate >= @dtScopeDate
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		--and a.ObservationDate >= @dtScopeDate

		update a
		set 
			a.MovingAverage5dVol = b.MovingAverage5dVol,
			a.MovingAverage10dVol = b.MovingAverage10dVol,
			a.MovingAverage15dVol = b.MovingAverage15dVol,
			a.MovingAverage20dVol = b.MovingAverage20dVol,
			a.MovingAverage30dVol = b.MovingAverage30dVol,
			a.MovingAverage60dVol = b.MovingAverage60dVol,
			a.MovingAverage120dVol = b.MovingAverage120dVol
		from [StockData].[StockStatsHistoryPlus] as a
		inner join
		(
			select ObservationDate,
				ASXCode,
				MovingAverage5dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 4 preceding),
				MovingAverage10dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 9 preceding),
				MovingAverage15dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 14 preceding),
				MovingAverage20dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 19 preceding),
				MovingAverage30dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 29 preceding),
				MovingAverage60dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 59 preceding),
				MovingAverage120dVol = avg([Volume]) over (partition by ASXCode order by DateSeq asc rows 119 preceding)
			from [StockData].[StockStatsHistoryPlus]
			--where ObservationDate >= @dtScopeDate
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		--and a.ObservationDate >= @dtScopeDate
		
		update x
		set x.MaxClose5d = y.MaxClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
			select
				a.ASXCode, 
				a.DateSeq,
				max(b.[Close]) as MaxClose
			from [StockData].[StockStatsHistoryPlus] as a
			inner join [StockData].[StockStatsHistoryPlus] as b
			on a.ASXCode = b.ASXCode
			and a.DateSeq < b.DateSeq + 5
			and a.DateSeq >= b.DateSeq
			--and a.ObservationDate >= @dtScopeDate
			--and b.ObservationDate >= @dtScopeDate
			group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MaxClose10d = y.MaxClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
			select
				a.ASXCode, 
				a.DateSeq,
				max(b.[Close]) as MaxClose
			from [StockData].[StockStatsHistoryPlus] as a
			inner join [StockData].[StockStatsHistoryPlus] as b
			on a.ASXCode = b.ASXCode
			and a.DateSeq < b.DateSeq + 10
			and a.DateSeq >= b.DateSeq
			--and a.ObservationDate >= @dtScopeDate
			--and b.ObservationDate >= @dtScopeDate
			group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MaxClose15d = y.MaxClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			a.ASXCode, 
			a.DateSeq,
			max(b.[Close]) as MaxClose
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq < b.DateSeq + 15
		and a.DateSeq >= b.DateSeq
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MaxClose20d = y.MaxClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			a.ASXCode, 
			a.DateSeq,
			max(b.[Close]) as MaxClose
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq < b.DateSeq + 20
		and a.DateSeq >= b.DateSeq
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MinClose5d = y.MinClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			a.ASXCode, 
			a.DateSeq,
			Min(b.[Close]) as MinClose
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq < b.DateSeq + 5
		and a.DateSeq >= b.DateSeq
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MinClose10d = y.MinClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			a.ASXCode, 
			a.DateSeq,
			Min(b.[Close]) as MinClose
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq < b.DateSeq + 10
		and a.DateSeq >= b.DateSeq
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MinClose15d = y.MinClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			a.ASXCode, 
			a.DateSeq,
			Min(b.[Close]) as MinClose
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq < b.DateSeq + 15
		and a.DateSeq >= b.DateSeq
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.MinClose20d = y.MinClose
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			a.ASXCode, 
			a.DateSeq,
			Min(b.[Close]) as MinClose
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq < b.DateSeq + 20
		and a.DateSeq >= b.DateSeq
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		group by a.ASXCode, a.DateSeq
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateSeq = y.DateSeq
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.PriceDirection = y.PriceDirection
		from [StockData].[StockStatsHistoryPlus] as x
		inner join
		(
		select
			b.ObservationDate,
			b.ASXCode,
			case when (a.High - a.[Open])/a.[Open] > case when a.[Close] between 0 and 1 then 0.05 else 0.03 end then 'Up'
				 when (a.[Low] - a.[Open])/a.[Open] < case when a.[Close] between 0 and 1 then -0.05 else -0.03 end then 'Down'
				 else 'Unknown'
			end as PriceDirection
		from [StockData].[StockStatsHistoryPlus] as a
		inner join [StockData].[StockStatsHistoryPlus] as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq = b.DateSeq + 1
		--and a.ObservationDate >= @dtScopeDate
		--and b.ObservationDate >= @dtScopeDate
		) as y
		on x.ObservationDate = y.ObservationDate
		and x.ASXCode = y.ASXCode
		--where x.ObservationDate >= @dtScopeDate

		update x
		set x.PriceDirection = 'Unknown'
		from [StockData].[StockStatsHistoryPlus] as x
		where PriceDirection is null
		--and x.ObservationDate >= @dtScopeDate

		update a
		set VolumeOver3xVol120d = case when [Volume] > 3*MovingAverage120dVol then 1 else 0 end
		from [StockData].[StockStatsHistoryPlus] as a
		--where ObservationDate >= @dtScopeDate
		
		update a
		set PriceOverMaxClose20d = case when [Close] > MaxClose20d then 1 else 0 end
		from [StockData].[StockStatsHistoryPlus] as a
		--where ObservationDate >= @dtScopeDate
		
		update a
		set PriceOverSMA60d = case when [Close] > MovingAverage60d then 1 else 0 end
		from [StockData].[StockStatsHistoryPlus] as a		
		--where ObservationDate >= @dtScopeDate
		
		update a
		set	PriceBand = case when [Close] < 0.02 then 2
							 when [Close] >= 0.02 and [Close] < 0.05 then 5
							 when [Close] >= 0.05 and [Close] < 0.10 then 10
							 when [Close] >= 0.10 and [Close] < 0.50 then 50
							 when [Close] >= 0.50 and [Close] < 1.00 then 100
							 when [Close] >= 1.00 and [Close] < 5.00 then 500
							 when [Close] >= 5.00 and [Close] < 20.00 then 2000
							 when [Close] >= 20.00  then 9999
						end
		from [StockData].[StockStatsHistoryPlus] as a
		--where ObservationDate >= @dtScopeDate
		
		if @intRowCount > 0
		begin
			if object_id(N'StockData.StockStatsHistoryPlusCurrent') is not null
				drop table StockData.StockStatsHistoryPlusCurrent

			select
				a.*,
				cast('' as varchar(10)) as TrendMovingAverage60d,
				cast('' as varchar(10)) as TrendMovingAverage200d,
				cast('' as varchar(10)) as TrendMovingAverage5w,
				cast('' as varchar(10)) as TrendMovingAverage10w,
				cast('' as varchar(10)) as TrendMovingAverage5m
			into StockData.StockStatsHistoryPlusCurrent
			from StockData.StockStatsHistoryPlus as a
			inner join
			(
				select ASXCode, max(DateSeq) as DateSeq
				from StockData.StockStatsHistoryPlus
				group by ASXCode
			) as b
			on a.ASXCode = b.ASXCode
			and a.DateSeq = b.DateSeq

			update a
			set TrendMovingAverage60d = 'Up'
			from StockData.StockStatsHistoryPlusCurrent as a
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 1
				and y.DateSeqReverse = 2
				and x.ASXCode = y.ASXCode
				and x.MovingAverage60d > y.MovingAverage60d
			) as b
			on a.ASXCode = b.ASXCode
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 10
				and y.DateSeqReverse = 11
				and x.ASXCode = y.ASXCode
				and x.MovingAverage60d > y.MovingAverage60d
			) as c
			on a.ASXCode = c.ASXCode
			  
			update a
			set TrendMovingAverage60d = 'Down'
			from StockData.StockStatsHistoryPlusCurrent as a
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 1
				and y.DateSeqReverse = 2
				and x.ASXCode = y.ASXCode
				and x.MovingAverage60d < y.MovingAverage60d
			) as b
			on a.ASXCode = b.ASXCode
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 10
				and y.DateSeqReverse = 11
				and x.ASXCode = y.ASXCode
				and x.MovingAverage60d < y.MovingAverage60d
			) as c
			on a.ASXCode = c.ASXCode
			
			update a
			set TrendMovingAverage200d = 'Up'
			from StockData.StockStatsHistoryPlusCurrent as a
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 1
				and y.DateSeqReverse = 2
				and x.ASXCode = y.ASXCode
				and x.MovingAverage200d > y.MovingAverage200d
			) as b
			on a.ASXCode = b.ASXCode
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 10
				and y.DateSeqReverse = 11
				and x.ASXCode = y.ASXCode
				and x.MovingAverage200d > y.MovingAverage200d
			) as c
			on a.ASXCode = c.ASXCode
			  
			update a
			set TrendMovingAverage200d = 'Down'
			from StockData.StockStatsHistoryPlusCurrent as a
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 1
				and y.DateSeqReverse = 2
				and x.ASXCode = y.ASXCode
				and x.MovingAverage200d < y.MovingAverage200d
			) as b
			on a.ASXCode = b.ASXCode
			inner join 
			(
				select x.ASXCode
				from StockData.StockStatsHistoryPlus as x
				inner join StockData.StockStatsHistoryPlus as y
				on x.DateSeqReverse = 10
				and y.DateSeqReverse = 11
				and x.ASXCode = y.ASXCode
				and x.MovingAverage200d < y.MovingAverage200d
			) as c
			on a.ASXCode = c.ASXCode
			
			create clustered index idx_stockdatastockstatshistorypluscurrent_asxcode on StockData.StockStatsHistoryPlusCurrent(ASXCode)


			if object_id(N'StockData.StockStatsHistoryPlusTrend') is not null
				drop table StockData.StockStatsHistoryPlusTrend

			select 
				ASXCode, 
				ObservationDate,
				[Close],
				MovingAverage10d, 
				lead(MovingAverage10d) over (partition by ASXCode order by ObservationDate desc) as PrevMovingAverage10d,
				MovingAverage20d, 
				lead(MovingAverage20d) over (partition by ASXCode order by ObservationDate desc) as PrevMovingAverage20d,
				MovingAverage60d, 
				lead(MovingAverage60d) over (partition by ASXCode order by ObservationDate desc) as PrevMovingAverage60d
			into StockData.StockStatsHistoryPlusTrend
			from [StockData].[StockStatsHistoryPlus]
			where ObservationDate > dateadd(day, -250, getdate())
			

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
