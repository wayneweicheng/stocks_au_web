-- Stored procedure: [DataMaintenance].[usp_MaintainStockData]



CREATE PROCEDURE [DataMaintenance].[usp_MaintainStockData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
with Recompile 
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
		truncate table StockData.PriceHistoryCurrent

		if object_id('Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		select *
		into #TempPriceHistory
		from StockData.v_PriceHistory
		where ObservationDate > dateadd(day, -30, getdate())

		insert into StockData.PriceHistoryCurrent
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
			SELECT *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber 
			FROM #TempPriceHistory
		) as x
		where x.RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempMoneyFlowInfo') is not null
			drop table #TempMoneyFlowInfo

		select *
		into #TempMoneyFlowInfo
		from [StockData].[v_MoneyFlowInfo] with(nolock)
		where dateadd(day, -365*2, getdate()) < ObservationDate
		and MoneyFlowType = 'daily'

		if object_id(N'Transform.MoneyflowInfoPlus') is not null
			drop table Transform.MoneyflowInfoPlus

		;with output as
		(
			select 
				 *
			from #TempMoneyFlowInfo
		)

		select 
			x.*, 
			AvgMFRankPerc,
			case when MaxMFRankPerc - MinMFRankPerc > 0 then cast((MFRankPerc - MinMFRankPerc)/(MaxMFRankPerc - MinMFRankPerc) as decimal(20, 4)) end as NormMFRankPerc,
			case when StdevMFRankPerc != 0 then cast((MFRankPerc - AvgMFRankPerc)/StdevMFRankPerc as decimal(20, 4)) end as ZScoreMFRankPerc
		into Transform.MoneyflowInfoPlus
		from output as x
		inner join 
		(
			select ASXCode, max(MFRankPerc) as MaxMFRankPerc, min(MFRankPerc) as MinMFRankPerc, avg(MFRankPerc) as AvgMFRankPerc, STDEV(MFRankPerc) as StdevMFRankPerc
			from output
			group by ASXCode
		) as y
		on x.ASXCode = y.ASXCode

		if object_id(N'Tempdb.dbo.#TempMoneyFlowInfoAgg') is not null
			drop table #TempMoneyFlowInfoAgg

		select *, Common.DateAddBusinessDay(-10, ObservationDate) as ObDatePrev10Days, Common.DateAddBusinessDay(-1, ObservationDate) as ObDatePrev1Days
		into #TempMoneyFlowInfoAgg
		from StockData.MoneyFlowInfo
		where MoneyFlowType = 'daily'

		if object_id(N'Transform.MoneyFlowInfoAgg') is not null
			drop table Transform.MoneyFlowInfoAgg

		select 
			a.ASXCode,
			a.ObservationDate,
			max(b.TotalScore) as MaxTotalScore, 
			avg(b.TotalScore) as AvgTotalScore,
			min(b.TotalScore) as MinTotalScore,
			max(b.NearScore) as MaxNearScore, 
			avg(b.NearScore) as AvgNearScore,
			min(b.NearScore) as MinNearScore,
			count(b.ASXCode) as NumObs
		into Transform.MoneyFlowInfoAgg
		from #TempMoneyFlowInfoAgg as a
		inner join #TempMoneyFlowInfoAgg as b
		on a.ASXCode = b.ASXCode
		--and a.ObservationDate = b.ObservationDate
		and b.ObservationDate between a.ObDatePrev10Days and a.ObDatePrev1Days
		group by a.ASXCode, a.ObservationDate

		if object_id(N'Transform.StockStatsHistoryPlus') is not null
			drop table Transform.StockStatsHistoryPlus

		select *
		into Transform.StockStatsHistoryPlus
		from [StockData].[v_StockStatsHistoryPlus] with(nolock)

		if object_id(N'Tempdb.dbo.#TempPriceHistory24Month') is not null
			drop table #TempPriceHistory24Month

		select cast(null as int) as ReverseRowNumber, *
		into #TempPriceHistory24Month
		from StockData.v_PriceHistory
		where ObservationDate > dateadd(day, -6*365, getdate())

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
		into #TempPriceHistory24Month_Stg
		FROM BaseWithChange AS bwc;

		if object_id(N'Transform.PriceHistory24Month') is not null
			drop table Transform.PriceHistory24Month

		select *
		into Transform.PriceHistory24Month
		from #TempPriceHistory24Month_Stg

		CREATE NONCLUSTERED INDEX idx_transformpricehistory24month_asxobdata
		ON [Transform].[PriceHistory24Month] ([ASXCode],[ObservationDate])
		INCLUDE ([TodayChange],[Next2DaysChange],[Next5DaysChange],[Next10DaysChange])

		exec [DataMaintenance].[usp_RefreshTransformMarketCLVTrend]

		exec [DataMaintenance].[usp_RefreshOptionContract]

		--exec [StockData].[usp_AddBuySellIndicatorToOptionTrade]
		exec [StockData].[usp_RefreshBuySellIndicatorPlus]

		exec [DataMaintenance].[usp_RefreshTransformSmartDumbCapitalTypeRatioIntraday]

		exec [DataMaintenance].[usp_RefreshOptionTradeByExpiryDate]

		exec [DataMaintenance].[usp_RefreshTransformSmartDumbCapitalTypeRatio]

		exec [DataMaintenance].[usp_RefreshTransformCapitalTypeRatio]

		exec [DataMaintenance].[usp_RefreshTransformCapitalTypeRatioFromOI]

		exec [DataMaintenance].[usp_RefreshTransformBreathLine]

		exec [DataMaintenance].[usp_RefreshTransformLeadingBreath]

		exec [DataMaintenance].[usp_RefreshTransformGammaWall]

		exec [DataMaintenance].[usp_OptionLastHourAction]
		
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
