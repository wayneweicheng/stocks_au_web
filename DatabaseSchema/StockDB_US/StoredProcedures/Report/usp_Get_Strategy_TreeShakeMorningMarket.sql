-- Stored procedure: [Report].[usp_Get_Strategy_TreeShakeMorningMarket]


CREATE PROCEDURE [Report].[usp_Get_Strategy_TreeShakeMorningMarket]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0
AS
/******************************************************************************
File: usp_Get_Strategy_TreeShakeMorningMarket.sql
Stored Procedure Name: usp_Get_Strategy_TreeShakeMorningMarket
Overview
-----------------
usp_Get_Strategy_TreeShakeMorningMarket

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
Date:		2020-01-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_TreeShakeMorningMarket'
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
		--declare @pintNumPrevDay as int = 4
		declare @dtObservationDate as date = dateadd(day, -1 * @pintNumPrevDay, cast(getdate() as date))	

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select *
		into #TempPriceSummary
		from
		(
			SELECT [PriceSummaryID]
				  ,[ASXCode]
				  ,[Bid]
				  ,[Offer]
				  ,[Open]
				  ,[High]
				  ,[Low]
				  ,[Close]
				  ,[Volume]
				  ,[Value]
				  ,[Trades]
				  ,[VWAP]
				  ,[DateFrom]
				  ,[DateTo]
				  ,[LastVerifiedDate]
				  ,[bids]
				  ,[bidsTotalVolume]
				  ,[offers]
				  ,[offersTotalVolume]
				  ,[IndicativePrice]
				  ,[SurplusVolume]
				  ,[PrevClose]
				  ,[SysLastSaleDate]
				  ,[SysCreateDate]
				  ,[Prev1PriceSummaryID]
				  ,[Prev1Bid]
				  ,[Prev1Offer]
				  ,[Prev1Volume]
				  ,[Prev1Value]
				  ,[VolumeDelta]
				  ,[ValueDelta]
				  ,[TimeIntervalInSec]
				  ,[BuySellInd]
				  ,[Prev1Close]
				  ,[LatestForTheDay]
				  ,[ObservationDate]
			FROM [StockData].[PriceSummary] with(index(idx_stockdatapricesummary_observationdate))
			where ObservationDate = @dtObservationDate 
			union all
			SELECT [PriceSummaryID]
				  ,[ASXCode]
				  ,[Bid]
				  ,[Offer]
				  ,[Open]
				  ,[High]
				  ,[Low]
				  ,[Close]
				  ,[Volume]
				  ,[Value]
				  ,[Trades]
				  ,[VWAP]
				  ,[DateFrom]
				  ,[DateTo]
				  ,[LastVerifiedDate]
				  ,[bids]
				  ,[bidsTotalVolume]
				  ,[offers]
				  ,[offersTotalVolume]
				  ,[IndicativePrice]
				  ,[SurplusVolume]
				  ,[PrevClose]
				  ,[SysLastSaleDate]
				  ,[SysCreateDate]
				  ,[Prev1PriceSummaryID]
				  ,[Prev1Bid]
				  ,[Prev1Offer]
				  ,[Prev1Volume]
				  ,[Prev1Value]
				  ,[VolumeDelta]
				  ,[ValueDelta]
				  ,[TimeIntervalInSec]
				  ,[BuySellInd]
				  ,[Prev1Close]
				  ,[LatestForTheDay]
				  ,[ObservationDate]
			FROM [StockData].[PriceSummaryToday]
			where ObservationDate = @dtObservationDate 
		) as a
		
		if object_id(N'Tempdb.dbo.#TempLowBefore11') is not null
			drop table #TempLowBefore11

		select ASXCode, min([Low]) as LowBefore11
		into #TempLowBefore11
		from #TempPriceSummary
		where ObservationDate = @dtObservationDate 
		and cast(DateFrom as time) < '11:05:00'
		and [Low] > 0
		group by ASXCode

		if object_id(N'Tempdb.dbo.#TempLatestAt15') is not null
			drop table #TempLatestAt15

		select a.*
		into #TempLatestAt15
		from #TempPriceSummary as a
		inner join
		(
			select 
				ASXCode, DateFrom, row_number() over (partition by ASXCode order by DateFrom desc) as RowNumber
			from #TempPriceSummary
			where ObservationDate = @dtObservationDate 
			and cast(DateFrom as time) < '15:05:00'
		) as b
		on a.ASXCode = b.ASXCode
		and a.DateFrom = b.DateFrom
		and a.ObservationDate = @dtObservationDate 
		and b.RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempLatest') is not null
			drop table #TempLatest

		select a.*
		into #TempLatest
		from #TempPriceSummary as a
		inner join
		(
			select 
				ASXCode, DateFrom, row_number() over (partition by ASXCode order by DateFrom desc) as RowNumber
			from #TempPriceSummary
			where ObservationDate = @dtObservationDate 
		) as b
		on a.ASXCode = b.ASXCode
		and a.DateFrom = b.DateFrom
		and a.ObservationDate = @dtObservationDate 
		and b.RowNumber = 1

		select 
			b.LowBefore11, 
			a.PrevClose, 
			a.ASXCode, 
			a.ObservationDate,
			c.[Close], 
			c.[VWAP], 
			format(a.Volume, 'N0') as TradeVolume,
			format(cast(a.[Value] as bigint), 'N0') as TradeValue,
			format(h.MedianTradeValue, 'N0') as MedianTradeValue,
			a.Trades,
			a.DateFrom,
			a.LastVerifiedDate,
			l.TrendMovingAverage60d,
			l.TrendMovingAverage200d
		from #TempLatest as a
		inner join #TempLowBefore11 as b
		on a.ASXCode = b.ASXCode
		and b.LowBefore11 < a.[PrevClose]*0.97
		inner join #TempLatestAt15 as c
		on a.ASXCode = c.ASXCode
		and c.[Close] > c.[VWAP]
		left join 
		(
			select ASXCode, MedianTradeValue from StockData.MedianTradeValue
		) as h
		on a.ASXCode = h.ASXCode
		left join StockData.StockStatsHistoryPlusCurrent as l
		on a.ASXCode = l.ASXCode
		where a.[Value] > 200000
		order by a.ASXCode

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
