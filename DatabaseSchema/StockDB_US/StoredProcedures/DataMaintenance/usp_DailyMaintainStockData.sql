-- Stored procedure: [DataMaintenance].[usp_DailyMaintainStockData]





CREATE PROCEDURE [DataMaintenance].[usp_DailyMaintainStockData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_DailyMaintainStockData.sql
Stored Procedure Name: usp_DailyMaintainStockData
Overview
-----------------
usp_DailyMaintainStockData

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
Date:		2017-06-18
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_DailyMaintainStockData'
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
		exec [DataMaintenance].[usp_MaintainStockMergeandSplit]

		exec [StockData].[usp_RefreshStockStatsHistoryPlus]

		exec [Transform].[usp_RefreshTransformPriceHistory]

		exec [DataMaintenance].[usp_RefreshTransformMarketCLVTrend]

		exec [DataMaintenance].[usp_RefreshTransformEquityPutCallRatio]

		exec [DataMaintenance].[usp_RefreshTransformPutSellingPerc]

		--exec [Report].[usp_Perf_Strategy_SPXOptionMoneyFlow_NASDAQ]

		--exec [Report].[usp_Perf_Strategy_SPXOptionMoneyFlow_SPX]

		--exec [Report].[usp_Perf_Strategy_SPXWOptionMoneyFlow_NASDAQ]

		--exec [Report].[usp_Perf_Strategy_SPXWOptionMoneyFlow_SPX]

		--exec [Report].[usp_Perf_Strategy_LithiumUSStock_ALB]
		--@pvchASXCode = 'ALB.US'

		--exec [Report].[usp_Perf_Strategy_LithiumUSStock_ALB]
		--@pvchASXCode = 'SQM.US'

		--exec [Report].[usp_Perf_Strategy_LithiumUSStock_ALB]
		--@pvchASXCode = 'LAC.US'

		exec [DataMaintenance].[usp_RefreshTransformBreathLine]

		exec [DataMaintenance].[usp_RefreshTransformGammaWall]

		exec [DataMaintenance].[usp_RefreshRelativePriceStrength]

		exec [DataMaintenance].[usp_MaintainSPX500Overview]

		exec [DataMaintenance].[usp_MaintainOptionGexChangeCapitalType]
		@pintPrevNumDay = 30

		exec [DataMaintenance].[usp_MaintainOptionGexChangeCapitalType_Pre]
		@pintPrevNumDay = 30

		if object_id(N'Transform.PriceHistoryFutureGainLoss') is not null
			drop table Transform.PriceHistoryFutureGainLoss

		select *, 
			cast(0 as int) as HighestIn30D,
			cast(0 as int) as HighestIn60D,
			row_number() over (partition by ASXCode order by ObservationDate asc) as SeqNo
		into Transform.PriceHistoryFutureGainLoss
		from (
			select 
				*, 
				case when [PrevClose] > 0 then cast(([Close]-PrevClose)*100.0/[PrevClose] as decimal(10, 2)) end as TodayChange,
				case when [Close] > 0 then cast((NextClose-[Close])*100.0/[Close] as decimal(10, 2)) end as TomorrowChange,
				case when [Close] > 0 then cast((NextOpen-[Close])*100.0/[Close] as decimal(10, 2)) end as TomorrowOpenChange,
				case when [Close] > 0 then cast((Next2Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next2DaysChange,
				case when [Close] > 0 then cast((Next5Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next5DaysChange,
				case when [Close] > 0 then cast((Next10Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next10DaysChange,
				case when [Prev2Close] > 0 then cast(([PrevClose]-Prev2Close)*100.0/[Prev2Close] as decimal(10, 2)) end as YesterdayChange,
				case when [Prev3Close] > 0 then cast(([PrevClose]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Prev2DaysChange,
				case when [Prev2Close] > 0 then cast(([Close]-Prev2Close)*100.0/[Prev2Close] as decimal(10, 2)) end as Last2DaysChange,
				case when [Prev3Close] > 0 then cast(([Close]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Last3DaysChange
			from
			(
				select 
					*, 
					lead([Low]) over (partition by ASXCode order by ObservationDate desc) as PrevLow,
					lead([High]) over (partition by ASXCode order by ObservationDate desc) as PrevHigh,
					lead([Close]) over (partition by ASXCode order by ObservationDate desc) as PrevClose,
					lag([Open], 1) over (partition by ASXCode order by ObservationDate desc) as NextOpen,
					lag([Close], 1) over (partition by ASXCode order by ObservationDate desc) as NextClose,
					lead([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Close,
					lead([Close], 3) over (partition by ASXCode order by ObservationDate desc) as Prev3Close,
					lag([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Next2Close,
					lag([Close], 5) over (partition by ASXCode order by ObservationDate desc) as Next5Close,
					lag([Close], 10) over (partition by ASXCode order by ObservationDate desc) as Next10Close
				from StockData.PriceHistory
				where ObservationDate > dateadd(day, -200, getdate())
			) as a
		) as x
		
		update a
		set HighestIn30D = 1
		from Transform.PriceHistoryFutureGainLoss as a
		inner join 
		(
			select
				a.ASXCode, 
				a.SeqNo,
				max(b.[Close]) as MaxClose
			from Transform.PriceHistoryFutureGainLoss as a
			inner join Transform.PriceHistoryFutureGainLoss as b
			on a.ASXCode = b.ASXCode
			and a.SeqNo < b.SeqNo + 30
			and a.SeqNo >= b.SeqNo
			group by a.ASXCode, a.SeqNo
		) as b
		on a.ASXCode = b.ASXCode
		and a.SeqNo = b.SeqNo + 1
		and a.[Close] > b.MaxClose
		and a.SeqNo > 30

		update a
		set HighestIn60D = 1
		from Transform.PriceHistoryFutureGainLoss as a
		inner join 
		(
			select
				a.ASXCode, 
				a.SeqNo,
				max(b.[Close]) as MaxClose
			from Transform.PriceHistoryFutureGainLoss as a
			inner join Transform.PriceHistoryFutureGainLoss as b
			on a.ASXCode = b.ASXCode
			and a.SeqNo < b.SeqNo + 60
			and a.SeqNo >= b.SeqNo
			group by a.ASXCode, a.SeqNo
		) as b
		on a.ASXCode = b.ASXCode
		and a.SeqNo = b.SeqNo + 1
		and a.[Close] > b.MaxClose
		and a.SeqNo > 60

		update a
		set HighestIn30D = 0
		from Transform.PriceHistoryFutureGainLoss as a
		where exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and SeqNo < a.SeqNo 
			and SeqNo >= a.SeqNo - 10
			and HighestIn30D = 1
		)
		and HighestIn30D = 1

		update a
		set HighestIn60D = 0
		from Transform.PriceHistoryFutureGainLoss as a
		where exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and SeqNo < a.SeqNo 
			and SeqNo >= a.SeqNo - 10
			and HighestIn60D = 1
		)
		and HighestIn60D = 1

		exec [DataMaintenance].[usp_RefreshTransformTickSaleVsBidAsk]

		exec [DataMaintenance].[usp_ArchivePriceHistorySecondary]

		delete a
		from StockData.StockBidAsk as a
		where CreateDateTime < dateadd(hour, -25, getdate())

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
