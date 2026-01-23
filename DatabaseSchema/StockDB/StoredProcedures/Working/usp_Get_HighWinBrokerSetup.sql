-- Stored procedure: [Working].[usp_Get_HighWinBrokerSetup]




CREATE PROCEDURE [Working].[usp_Get_HighWinBrokerSetup]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_Get_HighWinBrokerSetup.sql
Stored Procedure Name: usp_Get_HighWinBrokerSetup
Overview
-----------------
usp_Get_HighWinBrokerSetup

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
Date:		2020-12-11
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_HighWinBrokerSetup'
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
		declare @dtObservationDate as date
		declare @dtObservationStartDate1 as date
		declare @dtObservationStartDate2 as date
		declare @dtObservationEndDate as date
		declare @dtObservationEndDateTPlus3 date
		select @dtObservationDate = '2020-12-07'
		select @dtObservationEndDateTPlus3 = Common.DateAddBusinessDay(3, @dtObservationDate)
		select @dtObservationStartDate1 = Common.DateAddBusinessDay(-5, @dtObservationDate)
		select @dtObservationStartDate2 = Common.DateAddBusinessDay(-20, @dtObservationDate)
		select @dtObservationEndDate = @dtObservationDate

		if object_id(N'Tempdb.dbo.#TempBRLast5D') is not null
			drop table #TempBRLast5D

		create table #TempBRLast5D
		(
			ASXCode varchar(10) not null,
			ObservationDate date,
			BrokerCode varchar(50),
			[BuyValue] [bigint] NULL,
			[SellValue] [bigint] NULL,
			[NetValue] [bigint] NULL,
			[TotalValue] [bigint] NULL,
			[BuyVolume] [bigint] NULL,
			[SellVolume] [bigint] NULL,
			[NetVolume] [bigint] NULL,
			[TotalVolume] [bigint] NULL,
			[NoBuys] [bigint] NULL,
			[NoSells] [bigint] NULL,
			[Trades] [bigint] NULL,
			[BuyPrice] [decimal](20, 4) NULL,
			[SellPrice] [decimal](20, 4) NULL
		)

		insert into #TempBRLast5D
		exec [Report].[usp_Get_BrokerReportStartFrom_DEV]
		@pvchObservationStartDate = @dtObservationStartDate1,
		@pvchObservationEndDate = @dtObservationEndDate

		if object_id(N'Tempdb.dbo.#TempBRLast20D') is not null
			drop table #TempBRLast20D

		create table #TempBRLast20D
		(
			ASXCode varchar(10) not null,
			ObservationDate date,
			BrokerCode varchar(50),
			[BuyValue] [bigint] NULL,
			[SellValue] [bigint] NULL,
			[NetValue] [bigint] NULL,
			[TotalValue] [bigint] NULL,
			[BuyVolume] [bigint] NULL,
			[SellVolume] [bigint] NULL,
			[NetVolume] [bigint] NULL,
			[TotalVolume] [bigint] NULL,
			[NoBuys] [bigint] NULL,
			[NoSells] [bigint] NULL,
			[Trades] [bigint] NULL,
			[BuyPrice] [decimal](20, 4) NULL,
			[SellPrice] [decimal](20, 4) NULL
		)

		insert into #TempBRLast20D
		exec [Report].[usp_Get_BrokerReportStartFrom_DEV]
		@pvchObservationStartDate = @dtObservationStartDate2,
		@pvchObservationEndDate = @dtObservationEndDate

		if object_id(N'Tempdb.dbo.#TempBRLast5DRank') is not null
			drop table #TempBRLast5DRank

		select 
			*, 
			row_number() over (partition by ASXCode order by NetValue desc) as PositiveRank,
			row_number() over (partition by ASXCode order by NetValue asc) as NegativeRank
		into #TempBRLast5DRank
		from #TempBRLast5D

		if object_id(N'Tempdb.dbo.#TempBRLast20DRank') is not null
			drop table #TempBRLast20DRank

		select 
			*, 
			row_number() over (partition by ASXCode order by NetValue desc) as PositiveRank,
			row_number() over (partition by ASXCode order by NetValue asc) as NegativeRank
		into #TempBRLast20DRank
		from #TempBRLast20D

		if object_id(N'Tempdb.dbo.#TempHighWinCandidates') is not null
			drop table #TempHighWinCandidates

		select *
		into #TempHighWinCandidates
		from
		(
			select 
				@dtObservationEndDateTPlus3 as ObservationEndDateTPlus3,
				@dtObservationStartDate1 as ObservationStartDate1,
				@dtObservationStartDate2 as ObservationStartDate2,
				@dtObservationEndDate as ObservationEndDate,
				a.ASXCode,
				a.BrokerCode as MasterBrokerCode, 
				b.BrokerCode as ChildBrokerCode, 
				a.NetValue as MasterNetValue,
				b.NetValue as ChildNetValue,
				a.NetVolume as MasterVolume,
				b.NetVolume as ChildVolume,
				a.BuyPrice as MasterBuyPrice,
				a.SellPrice as MasterSellPrice,
				b.BuyPrice as ChildBuyPrice,
				b.SellPrice as ChildSellPrice,
				a.PositiveRank as MasterPositiveRank,
				b.PositiveRank as ChildPositiveRank,
				row_number() over (partition by case when a.BrokerCode > b.BrokerCode then a.BrokerCode else b.BrokerCode end, case when a.BrokerCode < b.BrokerCode then a.BrokerCode else b.BrokerCode end, a.ASXCode order by a.NetValue desc) as RowNumber
			from #TempBRLast5DRank as a
			inner join #TempBRLast5DRank as b
			on a.ASXCode = b.ASXCode
			and a.BrokerCode in ('Macqua', 'CreSui', 'Belpot', 'PerShn', 'ShaSto', 'Eursec')
			and b.BrokerCode in ('Macqua', 'CreSui', 'Belpot', 'PerShn', 'ShaSto', 'Eursec')
			and a.PositiveRank <= 3
			and b.PositiveRank <= 3
			and a.NetValue > 50000
			and b.NetValue > 50000
			and a.BrokerCode != b.BrokerCode
			inner join #TempBRLast20DRank as c
			on a.ASXCode = c.ASXCode
			and c.BrokerCode in ('ComSec')
			and c.PositiveRank <= 3
		) as x
		where x.RowNumber = 1


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
