-- Stored procedure: [StockData].[usp_RefreshStockStatsHistoryPlusWeekly]


CREATE PROCEDURE [StockData].[usp_RefreshStockStatsHistoryPlusWeekly]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshStockStatsHistoryPlusWeekly.sql
Stored Procedure Name: usp_RefreshStockStatsHistoryPlusWeekly
Overview
-----------------
usp_RefreshStockStatsHistoryPlusWeekly

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshStockStatsHistoryPlusWeekly'
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
		
		if object_id(N'[Working].[StockStatsHistoryPlusWeekly]') is not null
			drop table [Working].[StockStatsHistoryPlusWeekly]
		
		CREATE TABLE [Working].[StockStatsHistoryPlusWeekly](
			[ASXCode] [varchar](10) NOT NULL,
			[ObservationDate] [date] NOT NULL,
			[Close] [decimal](20, 4) NOT NULL,
			[Open] [decimal](20, 4) NOT NULL,
			[Low] [decimal](20, 4) NOT NULL,
			[High] [decimal](20, 4) NOT NULL,
			[PrevClose] [decimal](20, 4) NULL,
			[Volume] [bigint] NOT NULL,
			[IsTrendFlatOrUp] [bit] NULL,
			[CreateDate] [smalldatetime] NOT NULL,
			[DateSeq] [int] NULL,
			[Spread] [decimal](20, 4) NULL,
			[GainLossPecentage] [decimal](20, 4) NULL,
			[MovingAverage5d] [decimal](20, 4) NULL,
			[MovingAverage10d] [decimal](20, 4) NULL,
			[MovingAverage15d] [decimal](20, 4) NULL,
			[MovingAverage20d] [decimal](20, 4) NULL,
			[MovingAverage30d] [decimal](20, 4) NULL,
			[MovingAverage60d] [decimal](20, 4) NULL,
			[MovingAverage120d] [decimal](20, 4) NULL,
			[MovingAverage135d] [decimal](20, 4) NULL,
			[MovingAverage5dVol] [decimal](20, 4) NULL,
			[MovingAverage10dVol] [decimal](20, 4) NULL,
			[MovingAverage15dVol] [decimal](20, 4) NULL,
			[MovingAverage20dVol] [decimal](20, 4) NULL,
			[MovingAverage30dVol] [decimal](20, 4) NULL,
			[MovingAverage60dVol] [decimal](20, 4) NULL,
			[MovingAverage120dVol] [decimal](20, 4) NULL,
			[DateSeqReverse] [int] NULL,
			[UniqueKey] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL
		)

		insert into [Working].[StockStatsHistoryPlusWeekly]
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
		  ,a.WeekOpenDate
		  ,[Close]
		  ,[Open]
		  ,[Low]
		  ,[High]
		  ,[Volume]
		  ,getdate() as [CreateDate]
		  ,null as [DateSeq]
		  ,null as DateSeqReverse
		from [StockData].[PriceHistoryWeekly] as a

		update a
		set a.DateSeq = b.RowNumber
		from [Working].[StockStatsHistoryPlusWeekly] as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate) as RowNumber
			from [Working].[StockStatsHistoryPlusWeekly]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		update a
		set a.DateSeqReverse = b.RowNumber
		from [Working].[StockStatsHistoryPlusWeekly] as a
		inner join
		(
			select
				ObservationDate,
				ASXCode,
				row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
			from [Working].[StockStatsHistoryPlusWeekly]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		
		update a
		set a.PrevClose = b.[Close]
		from [Working].[StockStatsHistoryPlusWeekly] as a
		inner join [Working].[StockStatsHistoryPlusWeekly] as b
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
		from [Working].[StockStatsHistoryPlusWeekly] as a
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
			from [Working].[StockStatsHistoryPlusWeekly]
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
		from [Working].[StockStatsHistoryPlusWeekly] as a
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
			from [Working].[StockStatsHistoryPlusWeekly]
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		delete a
		from [StockData].[StockStatsHistoryPlusWeekly] as a;

		dbcc checkident('[StockData].[StockStatsHistoryPlusWeekly]', reseed, 1);

		insert into [StockData].[StockStatsHistoryPlusWeekly]
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
		  ,[DateSeqReverse]		
		from [Working].[StockStatsHistoryPlusWeekly]
		
		if object_id(N'[StockData].[StockStatsHistoryPlusWeeklyCurrent]') is not null
			drop table [StockData].[StockStatsHistoryPlusWeeklyCurrent]

		select *
		into [StockData].[StockStatsHistoryPlusWeeklyCurrent]
		from
		(
			select *, row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber 
			from [StockData].[StockStatsHistoryPlusWeekly]
		) as a
		where RowNumber = 1

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
