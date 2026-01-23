-- Stored procedure: [StockData].[usp_GetIntradayPriceHistory]






CREATE PROCEDURE [StockData].[usp_GetIntradayPriceHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10), 
@pdtObservationDate date
AS
/******************************************************************************
File: usp_GetIntradayPriceHistory.sql
Stored Procedure Name: usp_GetIntradayPriceHistory
Overview
-----------------
usp_GetIntradayPriceHistory

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
Date:		2018-03-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetIntradayPriceHistory'
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
		--declare @pvchASXCode as varchar(10) = 'BLK.AX'
		--declare @pdtObservationDate as date = '2018-03-14'

		if object_id(N'Tempdb.dbo.#TempCourseOfSale') is not null
			drop table #TempCourseOfSale

		select 
			*,
			cast(null as smalldatetime) as DataPoint1Min
		into #TempCourseOfSale
		from StockData.CourseOfSale as a
		where ASXCode = @pvchASXCode
		and cast(SaleDateTime as date) = @pdtObservationDate

		if object_id(N'Tempdb.dbo.#TempDataPoint1Min') is not null
			drop table #TempDataPoint1Min

		select 
			cast(cast(@pdtObservationDate as varchar(20)) + ' ' + IntraDayTime as smalldatetime) as ObservationDateTime,
			cast(null as datetime) as SaleDateTime,
			cast(null as int) as SeqNo,
			cast(null as decimal(20, 4)) as [Close],
			cast(null as bigint) as Volume,
			cast(null as decimal(20, 4)) as EMA7,
			cast(null as decimal(20, 4)) as SMA5,
			cast(null as decimal(20, 4)) as SMA10,
			cast(null as decimal(20, 4)) as SMA60,
			cast(null as decimal(20, 4)) as VSMA30,
			cast(null as decimal(10, 2)) as RSI
		into #TempDataPoint1Min
		from LookupRef.IntraDayTime
		where IntraDayTimeTypeID = '1min'

		update a
		set a.DataPoint1Min = b.ObservationDateTime
		from #TempCourseOfSale as a
		inner join #TempDataPoint1Min as b
		on a.SaleDateTime >= b.ObservationDateTime
		and a.SaleDateTime < dateadd(minute, 1, b.ObservationDateTime)

		update a
		set a.SaleDateTime = b.SaleDateTime
		from #TempDataPoint1Min as a
		inner join 
		(
			select DataPoint1Min, max(SaleDateTime) as SaleDateTime
			from #TempCourseOfSale
			group by DataPoint1Min
		) as b
		on a.ObservationDateTime = b.DataPoint1Min

		update a
		set a.Volume = b.Quantity
		from #TempDataPoint1Min as a
		inner join 
		(
			select DataPoint1Min, sum(Quantity) as Quantity
			from #TempCourseOfSale
			group by DataPoint1Min
		) as b
		on a.ObservationDateTime = b.DataPoint1Min

		update a
		set a.[Close] = b.[Price]
		from #TempDataPoint1Min as a
		inner join 
		(
			select DataPoint1Min, Price, row_number() over (partition by DataPoint1Min order by SaleDateTime desc, CourseOfSaleID desc) as RowNumber
			from #TempCourseOfSale
		) as b
		on a.ObservationDateTime = b.DataPoint1Min
		and b.RowNumber = 1

		update a
		set a.[Close] = c.[Close]
		from #TempDataPoint1Min as a
		inner join 
		(
			select a.ObservationDateTime, max(b.ObservationDateTime) as PrevObservationDateTime
			from #TempDataPoint1Min as a
			inner join #TempDataPoint1Min as b
			on a.ObservationDateTime > b.ObservationDateTime
			and a.[Close] is null
			and b.[Close] is not null
			group by a.ObservationDateTime
		) as b
		on a.ObservationDateTime = b.ObservationDateTime
		inner join #TempDataPoint1Min as c
		on b.PrevObservationDateTime = c.ObservationDateTime
		where a.[Close] is null
		and c.[Close] is not null

		update a
		set a.Volume = 0
		from #TempDataPoint1Min as a
		where a.Volume is null

		delete a
		from #TempDataPoint1Min as a
		where a.[Close] is null

		--CALCULATE EMA7
		declare @decCloseFirst decimal(20, 4) = 
		(
			select top 1 [close] 
			from #TempDataPoint1Min order by ObservationDateTime
		)

		if object_id(N'Tempdb.dbo.#TempEMA7') is not null
			drop table #TempEMA7

		select 
		 ObservationDateTime
		,[Close]
		,row_number() OVER (ORDER BY ObservationDateTime) RowNumber
		,@decCloseFirst as EMA7
		into #TempEMA7
		from #TempDataPoint1Min
		order by ObservationDateTime
		
		update #TempEMA7
		set
			EMA7 = null
		where RowNumber = 1

		declare @intMaxRowNumber int = (select max(RowNumber) from #TempEMA7)
		declare @intCurrentRowNumber int = 3
		declare @decEMA7 decimal(20, 4) = 2.0/(7.0 + 1), @decTodayEMA7 decimal(20, 4)
		
		while @intCurrentRowNumber <= @intMaxRowNumber
		begin

			set @decTodayEMA7 =
			(
				select top 1
				([close] * @decEMA7) + (lag(EMA7,1) over (order by ObservationDateTime) * (1 - @decEMA7)) as EMA
				from #TempEMA7
				where RowNumber >=  @intCurrentRowNumber - 1 and RowNumber <= @intCurrentRowNumber
				order by RowNumber desc
			)

			update #TempEMA7
			set 
				EMA7 = @decTodayEMA7
			where RowNumber = @intCurrentRowNumber

			set @intCurrentRowNumber = @intCurrentRowNumber + 1

		end
		
		update a
		set a.EMA7 = b.EMA7
		from #TempDataPoint1Min as a
		inner join #TempEMA7 as b
		on a.ObservationDateTime = b.ObservationDateTime

		delete a
		from #TempDataPoint1Min as a
		where Volume = 0

		update a
		set a.SeqNo = b.RowNumber
		from #TempDataPoint1Min as a
		inner join 
		(
			select
				ObservationDateTime,
				row_number() over (order by ObservationDateTime) as RowNumber
			from #TempDataPoint1Min
		) as b
		on a.ObservationDateTime = b.ObservationDateTime

		--SMA5 and SMA10
		update a
		set a.SMA10 = b.SMA10,
			a.SMA5 = b.SMA5,
			a.SMA60 = b.SMA60,
			a.VSMA30 = b.VSMA30
		from #TempDataPoint1Min as a
		inner join 
		(
		select
			ObservationDateTime,
			avg([Close]) over (order by ObservationDateTime asc rows 4 preceding) as SMA5,
			avg([Close]) over (order by ObservationDateTime asc rows 9 preceding) as SMA10,
			avg([Close]) over (order by ObservationDateTime asc rows 59 preceding) as SMA60,
			avg([Volume]) over (order by ObservationDateTime asc rows 29 preceding) as VSMA30
		from #TempDataPoint1Min
		) as b
		on a.ObservationDateTime = b.ObservationDateTime

		IF OBJECT_ID('tempdb.dbo.#TempRSI') IS NOT NULL BEGIN
			DROP TABLE #TempRSI
		END
  
		SELECT
			 T0.*
			,T0.[Close] - T1.[Close] AS Gain
			,CAST(NULL AS FLOAT) AS AvgGain
			,CAST(NULL AS FLOAT) AS AvgLoss
		INTO
			#TempRSI
		FROM
			#TempDataPoint1Min T0
		LEFT OUTER JOIN
			#TempDataPoint1Min T1
		ON T0.SeqNo - 1 = T1.SeqNo
 
		CREATE UNIQUE CLUSTERED INDEX EMA9_IDX_RT ON #TempRSI (SeqNo)
  
		IF OBJECT_ID('tempdb.dbo.#TBL_START_SUM') IS NOT NULL 
		BEGIN
			DROP TABLE #TBL_START_SUM
		END
 
		SELECT SUM(CASE WHEN Gain >= 0 THEN Gain ELSE 0 END) AS Start_Gain_Sum, SUM(CASE WHEN Gain < 0 THEN ABS(Gain) ELSE 0 END) AS Start_Loss_Sum INTO #TBL_START_SUM 
		FROM #TempRSI WHERE SeqNo <= 14
 
		DECLARE @AvgGain FLOAT, @AvgLoss FLOAT
 
		UPDATE
			T1
		SET
			@AvgGain =
				CASE
					WHEN SeqNo = 14 THEN T2.Start_Gain_Sum
					WHEN SeqNo > 14 THEN @AvgGain * 13 + CASE WHEN Gain >= 0 THEN Gain ELSE 0 END
				END / 14
			,AvgGain = @AvgGain
			,@AvgLoss =
				CASE
					WHEN SeqNo = 14 THEN T2.Start_Loss_Sum
					WHEN SeqNo > 14 THEN @AvgLoss * 13 + CASE WHEN Gain < 0 THEN ABS(Gain) ELSE 0 END
				END / 14
			,AvgLoss = @AvgLoss
		FROM
			#TempRSI T1
		JOIN
			#TBL_START_SUM T2
		ON
			1 = 1
		
		update a
		set a.RSI = b.RSI
		from #TempDataPoint1Min as a
		inner join 
		(
		SELECT
			 SeqNo
			,ObservationDateTime
			,[Close]
			,Gain
			,CAST(AvgGain AS NUMERIC(10,2)) AS AvgGain
			,CAST(AvgLoss AS NUMERIC(10,2)) AS AvgLoss
			,CAST(AvgGain / AvgLoss AS NUMERIC(10,2)) AS RS
			,CAST(100 - (100 / (1 + AvgGain / AvgLoss)) AS NUMERIC(10,2)) AS RSI
		FROM
			#TempRSI
		) as b
		on a.SeqNo = b.SeqNo

		declare @dtmObservationDateTime as smalldatetime
		declare @decClose as decimal(20, 4)
		declare @decSMA5 as decimal(20, 4)
		declare @decSMA10 as decimal(20, 4)
		declare @decSMA60 as decimal(20, 4)
		declare @decVSMA30 as decimal(20, 4)
		declare @intVolume int
		declare @intSeqNo int
		declare @dtmSaleDateTime as datetime
		declare @vchBuy2Raised as bit = 0
		declare @decBuy2Price as decimal(20, 4)
		declare @vchBuy3Raised as bit = 0
		declare @decBuy3Price as decimal(20, 4)
		declare @decRSI as decimal(10, 2)

		declare @dtmPrevObservationDateTime as smalldatetime
		declare @decPrevClose as decimal(20, 4)
		declare @decPrevSMA5 as decimal(20, 4)
		declare @decPrevSMA10 as decimal(20, 4)
		declare @decPrevSMA60 as decimal(20, 4)
		declare @decPrevVSMA30 as decimal(20, 4)
		declare @intPrevVolume int

		declare @dtmPrev2ObservationDateTime as smalldatetime
		declare @decPrev2Close as decimal(20, 4)
		declare @decPrev2SMA5 as decimal(20, 4)
		declare @decPrev2SMA10 as decimal(20, 4)
		declare @decPrev2SMA60 as decimal(20, 4)
		declare @decPrev2VSMA30 as decimal(20, 4)
		declare @intPrev2Volume int

		declare curTrigger cursor for
		select
			ObservationDateTime,
			SaleDateTime,
			SeqNo,
			[Close],
			Volume,
			SMA5,
			SMA10,
			SMA60,
			VSMA30,
			RSI
		from #TempDataPoint1Min

		open curTrigger
		fetch curTrigger into @dtmObservationDateTime, @dtmSaleDateTime, @intSeqNo, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30, @decRSI

		while @@fetch_status = 0
		begin

			--BUY 1
			if 
			(
				@decSMA5 > @decSMA10 and @decPrevSMA5 <= @decPrevSMA10
				and
				(@intVolume > @decVSMA30 or @intPrevVolume > @decPrevVSMA30)
				and
				(@decSMA60 is null or @decPrevSMA60 is null or @decPrev2SMA60 is null or (@decSMA60 >= @decPrevSMA60 and @decPrevSMA60 >= @decPrev2SMA60))				
			)
			begin
				select 'B', 'BUY1', @dtmObservationDateTime, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30
			end

			declare @intI as int = 0
			declare @decBuy2Close as decimal(20, 4)
			declare @decBuy2SMA5SMA10 as decimal(20, 4)
			declare @decPrev1Buy2Close as decimal(20, 4)
			declare @decPrev1Buy2SMA5SMA10 as decimal(20, 4)
			declare @bitBuy2Signal as bit = 1
			while @intI < 3 and @bitBuy2Signal = 1
			begin
				select 
					@decBuy2Close = [Close],
					@decBuy2SMA5SMA10 = SMA5 - SMA10
				from #TempDataPoint1Min
				where SeqNo = @intSeqNo - @intI

				select 
					@decPrev1Buy2Close = [Close],
					@decPrev1Buy2SMA5SMA10 = SMA5 - SMA10
				from #TempDataPoint1Min
				where SeqNo = @intSeqNo - (@intI + 1)

				if (
					@decBuy2SMA5SMA10 is null or @decPrev1Buy2SMA5SMA10 is null
					or @decBuy2SMA5SMA10 >= 0
					or @decBuy2SMA5SMA10 < @decPrev1Buy2SMA5SMA10
				)
				begin
					select @bitBuy2Signal = 0
				end

				select @intI = @intI + 1
			end

			--BUY 2
			if 
			(
				@decClose - @decPrevClose <= abs([Common].[GetPriceTick](@decClose))
				and
				@decPrevClose - @decPrev2Close <= abs([Common].[GetPriceTick](@decClose))
				and
				@decClose - @decPrev2Close <= abs([Common].[GetPriceTick](@decClose))
				and
				--(@decSMA60 is null or @decPrevSMA60 is null or @decPrev2SMA60 is null or (@decSMA60 >= @decPrevSMA60 and @decPrevSMA60 >= @decPrev2SMA60))
				--and
				CAST(@intVolume*100.0/@decVSMA30 as int) < 50 
				and
				@bitBuy2Signal = 1
				and
				@vchBuy2Raised != 1
			)
			begin
				select 'B', 'BUY2', @dtmObservationDateTime, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30
				select @vchBuy2Raised = 1
				select @decBuy2Price = @decClose
			end
			
			declare @decResistence as decimal(20, 4)
			if (CAST(@intPrevVolume*100.0/@decPrevVSMA30 as int) > 300 and @decClose < @decPrevClose)
			begin
				select @decResistence = case when isnull(@decResistence, 0) > @decPrevClose then @decResistence else @decPrevClose end
			end

			if (@decClose - @decResistence > 0 and CAST(@intVolume*100.0/@decVSMA30 as int) > 200)
			begin
				select 'B', 'BUY3', @dtmObservationDateTime, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30
				select @vchBuy3Raised = 1
				select @decBuy3Price = @decClose
				select @decResistence = null
			end

			--SELL 1
			if 
			(
				(@decSMA5 - @decSMA10 < -1 * [Common].[GetPriceTick](@decSMA5) and @decPrevSMA5 - @decPrevSMA10 >= -1 * [Common].[GetPriceTick](@decSMA5))
			)
			begin
				select 'S', 'SELL1', @dtmObservationDateTime, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30
				select @vchBuy2Raised = 0
			end

			--SELL 2
			if 
			(
				(@decClose - @decPrevClose <= 0 and @intVolume > 3*@decVSMA30 and @decPrevSMA5 - @decPrevSMA10 > 0 and @decClose != isnull(@decBuy3Price, 0))
			)
			begin
				select 'S', 'SELL2', @dtmObservationDateTime, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30
				select @vchBuy2Raised = 0
			end

			--SELL 3
			if 
			(
				@vchBuy2Raised = 1 and @decBuy2Price - @decClose >= 2 * [Common].[GetPriceTick](@decClose)
			)
			begin
				select 'S', 'SELL3', @dtmObservationDateTime, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30
				select @vchBuy2Raised = 0
				select @decBuy2Price = null
			end

			select @dtmPrev2ObservationDateTime = @dtmPrevObservationDateTime
			select @decPrev2Close = @decPrevClose
			select @intPrev2Volume = @intPrevVolume
			select @decPrev2SMA5 = @decPrevSMA5
			select @decPrev2SMA10 = @decPrevSMA10
			select @decPrev2SMA60 = @decPrevSMA60
			select @decPrev2VSMA30= @decPrevVSMA30

			select @dtmPrevObservationDateTime = @dtmObservationDateTime
			select @decPrevClose = @decClose
			select @intPrevVolume = @intVolume
			select @decPrevSMA5 = @decSMA5
			select @decPrevSMA10 = @decSMA10
			select @decPrevSMA60 = @decSMA60
			select @decPrevVSMA30= @decVSMA30

			fetch curTrigger into @dtmObservationDateTime, @dtmSaleDateTime, @intSeqNo, @decClose, @intVolume, @decSMA5, @decSMA10, @decSMA60, @decVSMA30, @decRSI

		end

		close curTrigger
		deallocate curTrigger

		SELECT *, SMA5 - SMA10 as SMA5Over10, CAST(Volume*100.0/VSMA30 as int) as VolumeOverVSMA30 
		FROM #TempDataPoint1Min

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
