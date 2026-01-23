-- Stored procedure: [StockData].[usp_RefreshStockStatsHistoryPlusMonthly]


CREATE PROCEDURE [StockData].[usp_RefreshStockStatsHistoryPlusMonthly]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshStockStatsHistoryPlusMonthly.sql
Stored Procedure Name: usp_RefreshStockStatsHistoryPlusMonthly
Overview
-----------------
usp_RefreshStockStatsHistoryPlusMonthly

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
Date:		2020-08-03
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshStockStatsHistoryPlusMonthly'
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
		
		delete a
		from [StockData].[StockStatsHistoryPlusMonthly] as a;

		dbcc checkident('[StockData].[StockStatsHistoryPlusMonthly]', reseed, 1);

		insert into [StockData].[StockStatsHistoryPlusMonthly]
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
		  ,a.MonthOpenDate
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,getdate() as [CreateDate]
		  ,null as [DateSeq]
		  ,null as DateSeqReverse
		from [StockData].[PriceHistoryMonthly] as a

		update a
		set a.DateSeq = b.RowNumber
		from [StockData].[StockStatsHistoryPlusMonthly] as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate) as RowNumber
			from [StockData].[StockStatsHistoryPlusMonthly]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		update a
		set a.DateSeqReverse = b.RowNumber
		from [StockData].[StockStatsHistoryPlusMonthly] as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from [StockData].[StockStatsHistoryPlusMonthly]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		
		update a
		set a.PrevClose = b.[Close]
		from [StockData].[StockStatsHistoryPlusMonthly] as a
		inner join [StockData].[StockStatsHistoryPlusMonthly] as b
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
			a.MovingAverage135d = b.MovingAverage135d
		from [StockData].[StockStatsHistoryPlusMonthly] as a
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
			from [StockData].[StockStatsHistoryPlusMonthly]
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
		from [StockData].[StockStatsHistoryPlusMonthly] as a
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
			from [StockData].[StockStatsHistoryPlusMonthly]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		
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
