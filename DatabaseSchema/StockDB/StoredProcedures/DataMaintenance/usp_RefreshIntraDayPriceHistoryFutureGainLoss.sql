-- Stored procedure: [DataMaintenance].[usp_RefreshIntraDayPriceHistoryFutureGainLoss]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshIntraDayPriceHistoryFutureGainLoss]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshIntraDayPriceHistoryFutureGainLoss.sql
Stored Procedure Name: usp_RefreshIntraDayPriceHistoryFutureGainLoss
Overview
-----------------
usp_RefreshIntraDayPriceHistoryFutureGainLoss

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
Date:		2021-09-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshIntraDayPriceHistoryFutureGainLoss'
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
		if object_id(N'Tempdb.dbo.#TempTodayPriceHistory') is not null
			drop table #TempTodayPriceHistory

		if object_id(N'Tempdb.dbo.#TempTransformPriceHistoryFutureGainLoss') is not null
			drop table #TempTransformPriceHistoryFutureGainLoss

		select distinct
			ASXCode,
			ObservationDate,
			FIRST_VALUE(Price) OVER (PARTITION BY ASXCode, ObservationDate ORDER BY SaleDateTime ASC) AS OpenPrice,
			FIRST_VALUE(Price) OVER (PARTITION BY ASXCode, ObservationDate ORDER BY SaleDateTime DESC) AS ClosePrice,
			MAX(Price) OVER (PARTITION BY ASXCode, ObservationDate) AS HighPrice,
			MIN(Price) OVER (PARTITION BY ASXCode, ObservationDate) AS LowPrice,
			--row_number() over (partition by ASXCode, ObservationDate order by SaleDateTime asc) as OpenRank,
			--row_number() over (partition by ASXCode, ObservationDate order by SaleDateTime desc) as CloseRank,
			sum(Quantity) over (partition by ASXCode, ObservationDate) as Volume
		into #TempTodayPriceHistory
		from StockData.CourseOfSaleSecondaryToday with(nolock)
		where ObservationDate = cast(getdate() as date)

		insert into StockData.PriceHistory
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
		  ,ClosePrice as [Close]
		  ,OpenPrice as [Open]
		  ,LowPrice as [Low]
		  ,HighPrice as [High]
		  ,[Volume]
		  ,ClosePrice*Volume as [Value]
		  ,99 as [Trades]
		  ,getdate() as [CreateDate]
		  ,getdate() as [ModifyDate]
		from #TempTodayPriceHistory as a
		where not exists
		(
			select 1
			from StockData.PriceHistory
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
		)

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
			case when [Prev3Close] > 0 then cast(([Close]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Last3DaysChange,
			cast(0 as int) as HighestIn30D,
			cast(0 as int) as HighestIn60D,
			row_number() over (partition by ASXCode order by ObservationDate asc) as SeqNo
		into #TempTransformPriceHistoryFutureGainLoss
		from
		(
			select 
				*, 
				lead([Low]) over (partition by ASXCode order by ObservationDate desc) as PrevLow,
				lead([High]) over (partition by ASXCode order by ObservationDate desc) as PrevHigh,
				lead([Close]) over (partition by ASXCode order by ObservationDate desc) as PrevClose,
				lag([Open], 1) over (partition by ASXCode order by ObservationDate desc) as NextOpen,
				lag([Low], 1) over (partition by ASXCode order by ObservationDate desc) as NextLow,
				lag([High], 1) over (partition by ASXCode order by ObservationDate desc) as NextHigh,
				lag([Close], 1) over (partition by ASXCode order by ObservationDate desc) as NextClose,
				lead([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Close,
				lead([Close], 3) over (partition by ASXCode order by ObservationDate desc) as Prev3Close,
				lag([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Next2Close,
				lag([Close], 5) over (partition by ASXCode order by ObservationDate desc) as Next5Close,
				lag([Close], 10) over (partition by ASXCode order by ObservationDate desc) as Next10Close
			from StockData.PriceHistory
			where ObservationDate > dateadd(day, -10, getdate())
		) as a

		delete a
		from Transform.PriceHistoryFutureGainLoss as a
		where ObservationDate = cast(getdate() as date)

		insert into Transform.PriceHistoryFutureGainLoss
		select *
		from #TempTransformPriceHistoryFutureGainLoss as a
		where not exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
		)

		update a
		set SeqNo = b.NewSeqNo
		from Transform.PriceHistoryFutureGainLoss as a
		inner join
		(
			select *, row_number() over (partition by ASXCode order by ObservationDate) as NewSeqNo
			from Transform.PriceHistoryFutureGainLoss
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

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
		where ObservationDate > dateadd(day, -10, getdate())

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
		where ObservationDate > dateadd(day, -10, getdate())

		update a
		set HighestIn30D = 0
		from Transform.PriceHistoryFutureGainLoss as a
		where exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and SeqNo < a.SeqNo 
			and SeqNo >= a.SeqNo - 30
			and HighestIn30D = 1
		)
		and HighestIn30D = 1
		and ObservationDate > dateadd(day, -10, getdate())

		update a
		set HighestIn60D = 0
		from Transform.PriceHistoryFutureGainLoss as a
		where exists
		(
			select 1
			from Transform.PriceHistoryFutureGainLoss
			where ASXCode = a.ASXCode
			and SeqNo < a.SeqNo 
			and SeqNo >= a.SeqNo - 60
			and HighestIn60D = 1
		)
		and HighestIn60D = 1
		and ObservationDate > dateadd(day, -10, getdate())

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_RefreshTransformBrokerReportList failed'
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