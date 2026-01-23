-- Stored procedure: [Report].[usp_Get_HighWinPairBrokerSetup]




CREATE PROCEDURE [Report].[usp_Get_HighWinPairBrokerSetup]
@pbitDebug AS BIT = 0,
@pdtObservationDate as date,
@pbitAddToTable as bit = 0,
@pbitFilterByPreviousPerformance as bit = 0,
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
		--declare @pdtObservationDate as date = '2021-01-22'

		--Code goes here 
		--begin transaction
		declare @dtObservationDate as date
		declare @dtObservationStartDate1 as date
		declare @dtObservationStartDate2 as date
		declare @dtObservationEndDate as date
		declare @dtObservationEndDateTPlus3 date
		select @dtObservationDate = @pdtObservationDate
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
			[BuyValue] varchar(50) NULL,
			[SellValue] varchar(50) NULL,
			[NetValue] varchar(50) NULL,
			[TotalValue] varchar(50) NULL,
			[BuyVolume] varchar(50) NULL,
			[SellVolume] varchar(50) NULL,
			[NetVolume] varchar(50) NULL,
			[TotalVolume] varchar(50) NULL,
			[NoBuys] varchar(50) NULL,
			[NoSells] varchar(50) NULL,
			[Trades] varchar(50) NULL,
			[BuyPrice] [decimal](20, 4) NULL,
			[SellPrice] [decimal](20, 4) NULL
		)

		insert into #TempBRLast5D
		exec [Report].[usp_Get_BrokerReportStartFrom]
		@pvchObservationStartDate = @dtObservationStartDate1,
		@pvchObservationEndDate = @dtObservationEndDate

		update a
		set [BuyValue] = replace([BuyValue], ',', ''),
			[SellValue] = replace([SellValue], ',', ''),
			[NetValue] = replace([NetValue], ',', ''),
			[TotalValue] = replace([TotalValue], ',', ''),
			[BuyVolume] = replace([BuyVolume], ',', ''),
			[SellVolume] = replace([SellVolume], ',', ''),
			[NetVolume] = replace([NetVolume], ',', ''),
			[TotalVolume] = replace([TotalVolume], ',', ''),
			[NoBuys] = replace([NoBuys], ',', ''),
			[NoSells] = replace([NoSells], ',', ''),
			[Trades] = replace([Trades], ',', '')
		from #TempBRLast5D as a

		if object_id(N'Tempdb.dbo.#TempBRLast20D') is not null
			drop table #TempBRLast20D

		create table #TempBRLast20D
		(
			ASXCode varchar(10) not null,
			ObservationDate date,
			BrokerCode varchar(50),
			[BuyValue] varchar(50) NULL,
			[SellValue] varchar(50) NULL,
			[NetValue] varchar(50) NULL,
			[TotalValue] varchar(50) NULL,
			[BuyVolume] varchar(50) NULL,
			[SellVolume] varchar(50) NULL,
			[NetVolume] varchar(50) NULL,
			[TotalVolume] varchar(50) NULL,
			[NoBuys] varchar(50) NULL,
			[NoSells] varchar(50) NULL,
			[Trades] varchar(50) NULL,
			[BuyPrice] [decimal](20, 4) NULL,
			[SellPrice] [decimal](20, 4) NULL
		)

		insert into #TempBRLast20D
		exec [Report].[usp_Get_BrokerReportStartFrom]
		@pvchObservationStartDate = @dtObservationStartDate2,
		@pvchObservationEndDate = @dtObservationEndDate

		update a
		set [BuyValue] = replace([BuyValue], ',', ''),
			[SellValue] = replace([SellValue], ',', ''),
			[NetValue] = replace([NetValue], ',', ''),
			[TotalValue] = replace([TotalValue], ',', ''),
			[BuyVolume] = replace([BuyVolume], ',', ''),
			[SellVolume] = replace([SellVolume], ',', ''),
			[NetVolume] = replace([NetVolume], ',', ''),
			[TotalVolume] = replace([TotalVolume], ',', ''),
			[NoBuys] = replace([NoBuys], ',', ''),
			[NoSells] = replace([NoSells], ',', ''),
			[Trades] = replace([Trades], ',', '')
		from #TempBRLast20D as a

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
			and a.BrokerCode in ('Macqua', 'CreSui', 'Belpot', 'PerShn', 'ShaSto', 'Eursec', 'EvaPar', 'ArgSec', 'AscSec', 'BaiHol', 'DeuSec', 'OrdMin', 'RBCSec', 'MorgFn', 'MorgSt', 'UBSAus', 'FinExe', 'MorSec', 'ClsAus')
			and b.BrokerCode in ('Macqua', 'CreSui', 'Belpot', 'PerShn', 'ShaSto', 'Eursec', 'EvaPar', 'ArgSec', 'AscSec', 'BaiHol', 'DeuSec', 'OrdMin', 'RBCSec', 'MorgFn', 'MorgSt', 'UBSAus', 'FinExe', 'MorSec', 'ClsAus')
			and a.PositiveRank <= 3
			and b.PositiveRank <= 3
			and a.NetValue > 50000
			and b.NetValue > 50000
			and a.BrokerCode != b.BrokerCode
			inner join #TempBRLast5DRank as c
			on a.ASXCode = c.ASXCode
			and c.BrokerCode in ('ComSec', 'CMCMar')
			and c.NegativeRank <= 2
			--inner join #TempBRLast20DRank as d
			--on a.ASXCode = d.ASXCode
			--and d.BrokerCode in ('ComSec')
			--and d.PositiveRank <= 3
		) as x
		where x.RowNumber = 1

		if @pbitAddToTable = 1
		begin
			delete a
			from Transform.BrokerPairPerformance as a
			inner join #TempHighWinCandidates as b
			on a.ObservationEndDateTPlus3 = b.ObservationEndDateTPlus3

			insert into Transform.BrokerPairPerformance
			(
				[ObservationEndDateTPlus3],
				[ObservationStartDate1],
				[ObservationStartDate2],
				[ObservationEndDate],
				[ASXCode],
				[MasterBrokerCode],
				[ChildBrokerCode],
				[MasterNetValue],
				[ChildNetValue],
				[MasterVolume],
				[ChildVolume],
				[MasterBuyPrice],
				[MasterSellPrice],
				[ChildBuyPrice],
				[ChildSellPrice],
				[MasterPositiveRank],
				[ChildPositiveRank],
				CreateDate
			)
			select 
				[ObservationEndDateTPlus3],
				[ObservationStartDate1],
				[ObservationStartDate2],
				[ObservationEndDate],
				[ASXCode],
				[MasterBrokerCode],
				[ChildBrokerCode],
				[MasterNetValue],
				[ChildNetValue],
				[MasterVolume],
				[ChildVolume],
				[MasterBuyPrice],
				[MasterSellPrice],
				[ChildBuyPrice],
				[ChildSellPrice],
				[MasterPositiveRank],
				[ChildPositiveRank],
				getdate() as CreateDate
			from #TempHighWinCandidates
		end
		else
		begin
			if @pbitFilterByPreviousPerformance = 0
			begin
				select * from #TempHighWinCandidates
			end
			else
			begin

				if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
					drop table #TempPriceSummary

				select distinct b.ASXCode, b.[Open], b.[Close], b.[DateFrom] 
				into #TempPriceSummary
				from StockData.v_PriceSummary as b
				inner join #TempHighWinCandidates as a
				on b.ObservationDate = a.ObservationEndDateTPlus3
				and a.ASXCode = b.ASXCode
				and b.DateTo is null
				and b.LatestForTheDay = 1
				
				delete a
				from #TempPriceSummary as a
				where exists
				(
					select 1
					from #TempPriceSummary 
					where ASXCode = a.ASXCode
					and DateFrom > a.DateFrom
				)

				select
				[ObservationEndDateTPlus3],
				[ObservationStartDate1] as [ObservationStartDate],
				a.[ASXCode],
				[ObservationEndDate] as [ObservationDate],
				c.CleansedMarketCap as MarketCap,
				d.[Close] as ObservationEndDateTPlus3Close,
				cast((coalesce(d.[Close], e.[Close]) - MasterBuyPrice)*100.0/MasterBuyPrice as decimal(20, 2)) as PriceChange,
				[MasterBrokerCode],
				[ChildBrokerCode],
				[MasterNetValue],
				[ChildNetValue],
				[MasterBuyPrice],
				[MasterSellPrice],
				[ChildBuyPrice],
				[ChildSellPrice],
				b.T2DaysWinRate,
				b.AvgT2DaysPerformance,
				b.T5DaysWinRate,
				b.AvgT5DaysPerformance,
				b.T10DaysWinRate,
				b.AvgT10DaysPerformance,
				b.T20DaysWinRate,
				b.AvgT20DaysPerformance
				from #TempHighWinCandidates as a
				inner join LookupRef.v_BrokerPairPerformance as b
				on case when a.MasterBrokerCode < a.ChildBrokerCode then a.MasterBrokerCode else a.ChildBrokerCode end = b.BrokerCode1
				and case when a.MasterBrokerCode > a.ChildBrokerCode then a.MasterBrokerCode else a.ChildBrokerCode end = b.BrokerCode2
				left join StockData.CompanyInfo as c
				on a.ASXCode = c.ASXCode
				left join StockData.PriceHistory as d
				on a.ObservationEndDateTPlus3 = d.ObservationDate
				and a.ASXCode = d.ASXCode
				left join #TempPriceSummary as e
				on a.ASXCode = e.ASXCode

				order by T5DaysWinRate desc, AvgT5DaysPerformance desc
			end
				
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
