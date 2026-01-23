-- Stored procedure: [DataMaintenance].[usp_RefreshAlertStatsHistory]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshAlertStatsHistory]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshAlertStatsHistory.sql
Stored Procedure Name: usp_RefreshAlertStatsHistory
Overview
-----------------
usp_RefreshAlertStatsHistory

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
Date:		2019-09-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshAlertStatsHistory'
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
		if object_id(N'Tempdb.dbo.#TempStockAlertStats') is not null
			drop table #TempStockAlertStats

		select *
		into #TempStockAlertStats
		from [StockData].[StockStatsHistoryPlus] as a
		where 1 = 0

		if object_id(N'Tempdb.dbo.#TempBreakThroughStock') is not null
			drop table #TempBreakThroughStock

		select distinct a.ASXCode
		into #TempBreakThroughStock
		from 
		(
			select AlertTypeID, ASXCode, CreateDate
			from Stock.ASXAlertHistory
			group by AlertTypeID, ASXCode, CreateDate
		) as a
		inner join LookupRef.AlertType as b
		on a.AlertTypeID = b.AlertTypeID
		where cast(a.CreateDate as date) > cast(Common.DateAddBusinessDay(-1 * 15, getdate()) as date)
		and cast(a.CreateDate as date) <=  cast(Common.DateAddBusinessDay(0, getdate()) as date)
		and b.AlertTypeName in
		(
			'Break Through',
			'Breakaway Gap',
			'Breakthrough Trading Range', 
			'Gain Momentum'
		)

		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory
		
		select *
		into #TempPriceHistory
		from
		(
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
			  ,[CreateDate]
			  ,[ModifyDate]
			from [StockData].[PriceHistory] as a with(nolock)
			where exists
			(
				select 1
				from Alert.TradingAlert
				where AlertTriggerDate is null
				and ASXCode = a.ASXCode
			)
			and a.ObservationDate > dateadd(day, -250, getdate())
			union
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
			  ,[CreateDate]
			  ,[ModifyDate]
			from [StockData].[PriceHistory] as a with(nolock)
			where exists
			(
				select 1
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and ASXCode = a.ASXCode
			)
			and a.ObservationDate > dateadd(day, -250, getdate())
			union
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
			  ,[CreateDate]
			  ,[ModifyDate]
			from [StockData].[PriceHistory] as a with(nolock)
			where exists
			(
				select 1
				from #TempBreakThroughStock
				where ASXCode = a.ASXCode
			)
			and a.ObservationDate > dateadd(day, -250, getdate())
			union
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
			  ,[CreateDate]
			  ,[ModifyDate]
			from [StockData].[PriceHistory] as a with(nolock)
			where exists
			(
				select 1
				from [Order].[Order]
				where ASXCode = a.ASXCode
				--and OrderTriggerDate is null
				and ValidUntil >= getdate()
			)
			and a.ObservationDate > dateadd(day, -250, getdate())
		) as x

		insert into #TempPriceHistory
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
			  ,[CreateDate]
			  ,[ModifyDate]
		from
		(
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
			  ,DateFrom as [CreateDate]
			  ,DateFrom as [ModifyDate]
			from [StockData].[v_PriceSummary] as a with(nolock)
			where 1 = 1
			and not exists
			(
				select 1
				from #TempPriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate >= a.ObservationDate
			)
			and exists
			(
				select 1
				from Alert.TradingAlert
				where AlertTriggerDate is null
				and ASXCode = a.ASXCode
			)
			and a.DateTo is null
			and a.ObservationDate > dateadd(day, -250, getdate())
			union
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
			  ,DateFrom as [CreateDate]
			  ,DateFrom as [ModifyDate]
			from [StockData].[v_PriceSummary] as a with(nolock)
			where 1 = 1
			and not exists
			(
				select 1
				from #TempPriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate >= a.ObservationDate
			)
			and exists
			(
				select 1
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and ASXCode = a.ASXCode
			)
			and a.DateTo is null
			and a.ObservationDate > dateadd(day, -250, getdate())
			union
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
			  ,DateFrom as [CreateDate]
			  ,DateFrom as [ModifyDate]
			from [StockData].[v_PriceSummary] as a with(nolock)
			where 1 = 1
			and not exists
			(
				select 1
				from #TempPriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate >= a.ObservationDate
			)
			and exists
			(
				select 1
				from #TempBreakThroughStock
				where ASXCode = a.ASXCode
			)
			and a.DateTo is null
			and a.ObservationDate > dateadd(day, -250, getdate())
			union
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
			  ,DateFrom as [CreateDate]
			  ,DateFrom as [ModifyDate]
			from [StockData].[v_PriceSummary] as a with(nolock)
			where 1 = 1
			and not exists
			(
				select 1
				from #TempPriceHistory
				where ASXCode = a.ASXCode
				and ObservationDate >= a.ObservationDate
			)
			and exists
			(
				select 1
				from [Order].[Order]
				where ASXCode = a.ASXCode
				--and OrderTriggerDate is null
				and ValidUntil >= getdate()
			)
			and a.DateTo is null
			and a.ObservationDate > dateadd(day, -250, getdate())
		) as x

		insert into #TempStockAlertStats
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
		from #TempPriceHistory as a
		where 1 = 1
		and Volume > 0
		and [Open] > 0

		insert into #TempStockAlertStats
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
			,getdate() as [CreateDate]
			,null as [DateSeq]
			,null as DateSeqReverse
		from StockData.PriceSummaryToday as a
		where not exists
		(
			select 1
			from #TempStockAlertStats
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
		)
		and exists
		(
			select 1
			from Alert.TradingAlert
			where AlertTriggerDate is null
			and ASXCode = a.ASXCode
		)
		and a.LatestForTheDay = 1
		and a.DateTo is null

		insert into #TempStockAlertStats
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
			,getdate() as [CreateDate]
			,null as [DateSeq]
			,null as DateSeqReverse
		from StockData.PriceSummary as a
		where not exists
		(
			select 1
			from #TempStockAlertStats
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
		)
		and exists
		(
			select 1
			from Alert.TradingAlert
			where AlertTriggerDate is null
			and ASXCode = a.ASXCode
		)
		and a.LatestForTheDay = 1
		and a.DateTo is null

		update a
		set a.DateSeq = b.RowNumber
		from #TempStockAlertStats as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate) as RowNumber
			from #TempStockAlertStats
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		update a
		set a.DateSeqReverse = b.RowNumber
		from #TempStockAlertStats as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from #TempStockAlertStats
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		
		update a
		set a.PrevClose = b.[Close]
		from #TempStockAlertStats as a
		inner join #TempStockAlertStats as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq = b.DateSeq + 1

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
		from #TempStockAlertStats as a
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
			from #TempStockAlertStats
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		update a
		set 
			a.MovingAverage5dVol = b.MovingAverage5dVol,
			a.MovingAverage10dVol = b.MovingAverage10dVol,
			a.MovingAverage15dVol = b.MovingAverage15dVol,
			a.MovingAverage20dVol = b.MovingAverage20dVol,
			a.MovingAverage30dVol = b.MovingAverage30dVol,
			a.MovingAverage60dVol = b.MovingAverage60dVol,
			a.MovingAverage120dVol = b.MovingAverage120dVol
		from #TempStockAlertStats as a
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
			from #TempStockAlertStats
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		truncate table Alert.StockStatsHistoryPlus

		insert into Alert.StockStatsHistoryPlus
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[PrevClose]
		  ,[Volume]
		  ,[IsTrendFlatOrUp]
		  ,[CreateDate]
		  ,[DateSeq]
		  ,[Spread]
		  ,[GainLossPecentage]
		  ,[MovingAverage5d]
		  ,[MovingAverage10d]
		  ,[MovingAverage15d]
		  ,[MovingAverage20d]
		  ,[MovingAverage30d]
		  ,[MovingAverage60d]
		  ,[MovingAverage120d]
		  ,[MovingAverage135d]
		  ,[MovingAverage5dVol]
		  ,[MovingAverage10dVol]
		  ,[MovingAverage15dVol]
		  ,[MovingAverage20dVol]
		  ,[MovingAverage30dVol]
		  ,[MovingAverage60dVol]
		  ,[MovingAverage120dVol]
		  ,[ExpMovingAverage7d]
		  ,[ExpMovingAverage15d]
		  ,[ExpMovingAverage25d]
		  ,[ExpMovingAverage235d]
		  ,[MaxClose5d]
		  ,[MaxClose10d]
		  ,[MaxClose15d]
		  ,[MaxClose20d]
		  ,[MinClose5d]
		  ,[MinClose10d]
		  ,[MinClose15d]
		  ,[MinClose20d]
		  ,[PriceSpread5d]
		  ,[PriceSpread10d]
		  ,[PriceSpread15d]
		  ,[PriceSpread20d]
		  ,[UpperShadowVsBodyRatio]
		  ,[BottomShadowVsBodyRatio]
		  ,[MACDMACD]
		  ,[MACDSignal]
		  ,[MACDHist]
		  ,[RSI]
		  ,[Previous30dHigh]
		  ,[Previous30dLow]
		  ,[Next60dHigh]
		  ,[Next60dLow]
		  ,[Next30dHigh]
		  ,[Next30dLow]
		  ,[Support1]
		  ,[Support2]
		  ,[Support3]
		  ,[Resistence1]
		  ,[Resistence2]
		  ,[Resistence3]
		  ,[EMA7After10d]
		  ,[EMA710dChange]
		  ,[EMA7After5d]
		  ,[EMA75dChange]
		  ,[EMA7After20d]
		  ,[EMA720dChange]
		  ,[PriceBand]
		  ,[EMA7dOverEMA15d]
		  ,[SMA30dOverSMA60d]
		  ,[PriceOverSMA60d]
		  ,[PriceOverSMA30d]
		  ,[PriceOverEMA7d]
		  ,[PriceOverEMA15d]
		  ,[VolumeOver3xVol120d]
		  ,[VolumeOver5xVol120d]
		  ,[PriceOverMaxClose20d]
		  ,[PriceUnderMinClose20d]
		  ,[PriceEMAMove5d]
		  ,[PriceEMAMove10d]
		  ,[PriceEMAMove20d]
		  ,[PriceDirection]
		  ,[CLHL]
		  ,[MACDHistTurnUp]
		  ,[MACDCrossUp]
		  ,[Next5dHigh]
		  ,[Next10dHigh]
		  ,[Next5dLow]
		  ,[Next10dLow]
		  ,[Previous90dHigh]
		  ,[Previous60dHigh]
		  ,[Previous60dLow]
		  ,[BullEngulfing]
		  ,[MovingAverage200d]
		  ,[DateSeqReverse]
		)
		select 
		   [ASXCode]
		  ,[ObservationDate]
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[PrevClose]
		  ,[Volume]
		  ,[IsTrendFlatOrUp]
		  ,[CreateDate]
		  ,[DateSeq]
		  ,[Spread]
		  ,[GainLossPecentage]
		  ,[MovingAverage5d]
		  ,[MovingAverage10d]
		  ,[MovingAverage15d]
		  ,[MovingAverage20d]
		  ,[MovingAverage30d]
		  ,[MovingAverage60d]
		  ,[MovingAverage120d]
		  ,[MovingAverage135d]
		  ,[MovingAverage5dVol]
		  ,[MovingAverage10dVol]
		  ,[MovingAverage15dVol]
		  ,[MovingAverage20dVol]
		  ,[MovingAverage30dVol]
		  ,[MovingAverage60dVol]
		  ,[MovingAverage120dVol]
		  ,[ExpMovingAverage7d]
		  ,[ExpMovingAverage15d]
		  ,[ExpMovingAverage25d]
		  ,[ExpMovingAverage235d]
		  ,[MaxClose5d]
		  ,[MaxClose10d]
		  ,[MaxClose15d]
		  ,[MaxClose20d]
		  ,[MinClose5d]
		  ,[MinClose10d]
		  ,[MinClose15d]
		  ,[MinClose20d]
		  ,[PriceSpread5d]
		  ,[PriceSpread10d]
		  ,[PriceSpread15d]
		  ,[PriceSpread20d]
		  ,[UpperShadowVsBodyRatio]
		  ,[BottomShadowVsBodyRatio]
		  ,[MACDMACD]
		  ,[MACDSignal]
		  ,[MACDHist]
		  ,[RSI]
		  ,[Previous30dHigh]
		  ,[Previous30dLow]
		  ,[Next60dHigh]
		  ,[Next60dLow]
		  ,[Next30dHigh]
		  ,[Next30dLow]
		  ,[Support1]
		  ,[Support2]
		  ,[Support3]
		  ,[Resistence1]
		  ,[Resistence2]
		  ,[Resistence3]
		  ,[EMA7After10d]
		  ,[EMA710dChange]
		  ,[EMA7After5d]
		  ,[EMA75dChange]
		  ,[EMA7After20d]
		  ,[EMA720dChange]
		  ,[PriceBand]
		  ,[EMA7dOverEMA15d]
		  ,[SMA30dOverSMA60d]
		  ,[PriceOverSMA60d]
		  ,[PriceOverSMA30d]
		  ,[PriceOverEMA7d]
		  ,[PriceOverEMA15d]
		  ,[VolumeOver3xVol120d]
		  ,[VolumeOver5xVol120d]
		  ,[PriceOverMaxClose20d]
		  ,[PriceUnderMinClose20d]
		  ,[PriceEMAMove5d]
		  ,[PriceEMAMove10d]
		  ,[PriceEMAMove20d]
		  ,[PriceDirection]
		  ,[CLHL]
		  ,[MACDHistTurnUp]
		  ,[MACDCrossUp]
		  ,[Next5dHigh]
		  ,[Next10dHigh]
		  ,[Next5dLow]
		  ,[Next10dLow]
		  ,[Previous90dHigh]
		  ,[Previous60dHigh]
		  ,[Previous60dLow]
		  ,[BullEngulfing]
		  ,[MovingAverage200d]
		  ,[DateSeqReverse]
		from #TempStockAlertStats

		if object_id(N'Alert.StockStatsHistoryPlusCurrent') is not null
			drop table Alert.StockStatsHistoryPlusCurrent

		select
			a.*
		into Alert.StockStatsHistoryPlusCurrent
		from Alert.StockStatsHistoryPlus as a
		inner join
		(
			select ASXCode, max(DateSeq) as DateSeq
			from Alert.StockStatsHistoryPlus
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		and a.DateSeq = b.DateSeq

		create clustered index idx_alertstockstatshistorypluscurrent_asxcode on Alert.StockStatsHistoryPlusCurrent(ASXCode)

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
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
