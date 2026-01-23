-- Stored procedure: [Report].[usp_GetRiseFromDip]



CREATE PROCEDURE [Report].[usp_GetRiseFromDip]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetRiseFromDip.sql
Stored Procedure Name: usp_GetRiseFromDip
Overview
-----------------
usp_GetRiseFromDip

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
Date:		2018-02-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetRiseFromDip'
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
		if object_id(N'Tempdb.dbo.#TempAnn') is not null
			drop table #TempAnn

		select distinct ASXCode
		into #TempAnn
		from StockData.WatchListStock as a with(nolock)
		where WatchListName = 'WL260'

		--declare @dtObservationDate as date = '2021-09-22'

		--select distinct ASXCode, cast(AnnDateTime as date) as ObservationDate
		--into #TempAnn
		--from StockData.Announcement with(nolock)
		--where cast(AnnDateTime as date) = @dtObservationDate
		--and MarketSensitiveIndicator = 1
		--and cast(AnnDateTime as time) < '10:10:30'		

		if object_id(N'Tempdb.dbo.#TempTradeCandidate') is not null
			drop table #TempTradeCandidate

		select *
		into #TempTradeCandidate
		from
		(
			select c.DateFrom as SecondDateFrom, b.DateFrom FirstDateFrom, c.[Close] as SecondClose, c.VWAP as SecondVWAP, c.Trades as SecondTrades, c.Value as SecondValue, b.*, row_number() over (partition by a.ASXCode order by c.DateFrom) as RowNumber
			from #TempAnn as a
			inner join StockData.PriceSummaryToday as b with(nolock)
			on a.ASXCode = b.ASXCode
			and cast(b.DateFrom as time) < '10:30:00'
			and
			(
				left(a.ASXCode, 1) in ('A', 'B') and cast(b.DateFrom as time) > cast('10:03:15' as time)
				or
				left(a.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(b.DateFrom as time) > cast('10:05:30' as time)
				or
				left(a.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(b.DateFrom as time) > cast('10:07:45' as time)
				or
				left(a.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(b.DateFrom as time) > cast('10:10:00' as time)
				or
				left(a.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(b.DateFrom as time) > cast('10:12:15' as time)
			)
			and b.[Open] > 0
			and b.[Close] < b.[Open]
			inner join StockData.PriceSummaryToday as c with(nolock)
			on a.ASXCode = c.ASXCode
			and cast(c.DateFrom as time) < '14:30:00'
			and cast(c.DateFrom as time) > '10:15:00'
			and c.[Close] > b.[Open]
			and c.[Close] >= c.VWAP 
			and c.DateFrom > b.DateFrom
			--and c.[Close] < 10
			--and c.Trades > 150
			and datediff(second, b.DateFrom, c.DateFrom) > 360
		) as x
		where x.RowNumber = 1

		delete a
		from #TempTradeCandidate as a
		where SecondTrades < 200
		or SecondValue < 300000

		insert into [StockAPI].[TradeCandidateRiseFromDip]
		(
		   OrderPrice
		  ,OrderVolume
		  ,[SecondDateFrom]
		  ,[FirstDateFrom]
		  ,[SecondClose]
		  ,[SecondVWAP]
		  ,[SecondTrades]
		  ,[SecondValue]
		  ,[PriceSummaryID]
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
		  ,[MatchVolume]
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
		  ,[RowNumber]
		  ,CreateDate
		  ,[ProcessDate]
		)
		select 
		   [SecondClose] as OrderPrice
		  ,cast(2000.0/[SecondClose] as int) as OrderVolume
		  ,[SecondDateFrom]
		  ,[FirstDateFrom]
		  ,[SecondClose]
		  ,[SecondVWAP]
		  ,[SecondTrades]
		  ,[SecondValue]
		  ,[PriceSummaryID]
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
		  ,[MatchVolume]
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
		  ,[RowNumber]
		  ,getdate() as CreateDate
		  ,null as [ProcessDate]
		from #TempTradeCandidate as a
		where not exists
		(
			select 1
			from [StockAPI].[TradeCandidateRiseFromDip]
			where ASXCode = a.ASXCode
			and cast(CreateDate as date) = cast(getdate() as date)	
		)

		select *
		from [StockAPI].[TradeCandidateRiseFromDip]
		where cast(CreateDate as date) = cast(getdate() as date)	
		and ProcessDate is null
		and datediff(second, CreateDate, getdate()) < 180

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
