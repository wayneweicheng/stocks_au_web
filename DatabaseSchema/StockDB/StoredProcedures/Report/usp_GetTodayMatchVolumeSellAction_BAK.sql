-- Stored procedure: [Report].[usp_GetTodayMatchVolumeSellAction_BAK]


CREATE PROCEDURE [Report].[usp_GetTodayMatchVolumeSellAction]
@pbitDebug AS BIT = 0,
@pvchASXCode varchar(10),
@pdtObservationDate date = null,
@pdecIndicativePrice decimal(20, 4) = null,
@pintMatchVolume int = null,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetTodayMatchVolumeSellAction.sql
Stored Procedure Name: usp_GetTodayMatchVolumeSellAction
Overview
-----------------
usp_GetTodayMatchVolumeSellAction

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
Date:		2021-10-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTodayMatchVolumeSellAction'
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
		--declare @pvchASXCode as varchar(10) = 'GBR.AX'
		--declare @pdtObservationDate as date = '2021-10-25'

		--select 'Y' as BuyAction, 1000 as BuyValue

		if @pdtObservationDate is null
		begin
			select @pdtObservationDate = cast(getdate() as date)
		end

		if object_id(N'Tempdb.dbo.#TempMatchVolume') is not null
			drop table #TempMatchVolume
		
		select 
		   [ASXCode]
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
		  ,[MatchVolume]
		  ,[SeqNumber]
		into #TempMatchVolume
		from StockData.PriceSummary with(nolock)
		where 1 != 1
		
		if @pdtObservationDate  = cast(getdate() as date) and cast(getdate() as time) < cast('17:00:00' as time)
		begin
			insert into #TempMatchVolume
			(
			   [ASXCode]
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
			  ,[MatchVolume]
			  ,[SeqNumber]
			)
			select 
			   [ASXCode]
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
			  ,[MatchVolume]
			  ,[SeqNumber]
			from StockData.PriceSummaryToday with(nolock)
			where ASXCode = @pvchASXCode
			and ObservationDate = @pdtObservationDate
			order by DateFrom asc;
		end
		else
		begin
			insert into #TempMatchVolume
			(
			   [ASXCode]
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
			  ,[MatchVolume]
			  ,[SeqNumber]
			)
			select 
			   [ASXCode]
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
			  ,[MatchVolume]
			  ,[SeqNumber]
			from StockData.PriceSummary with(nolock)
			where ASXCode = @pvchASXCode
			and ObservationDate = @pdtObservationDate
			order by DateFrom asc;
		end

		--if exists
		--(
		--	select 1
		--	from #TempMatchVolume
		--	where DateTo is null
		--	and Volume > 0
		--) and @pdtObservationDate = cast(getdate() as date)
		--begin
		--	select 'N' as BuyAction, cast(null as decimal(20, 4)) as BuyValue
		--	return
		--end

		delete a
		from #TempMatchVolume as a
		where Volume > 0
		or IndicativePrice = 0

		if object_id(N'Tempdb.dbo.#TempMatchVolume2') is not null
			drop table #TempMatchVolume2

		select 
			row_number() over (order by DateFrom desc) as VolumeOrder, 
			row_number() over (order by DateFrom asc) as InverseVolumeOrder, 
			cast(null as bit) as BidDown,
			*
		into #TempMatchVolume2
		from #TempMatchVolume as a
		where datediff(second, datefrom, (select max(SysCreateDate) from #TempMatchVolume)) < 120

		update a
		set a.BidDown = 1
		from #TempMatchVolume2 as a
		inner join #TempMatchVolume2 as b
		on a.VolumeOrder + 1 = b.VolumeOrder
		and a.IndicativePrice < b.IndicativePrice
		where a.BidDown is null	

		update a
		set a.BidDown = 1
		from #TempMatchVolume2 as a
		inner join #TempMatchVolume2 as b
		on a.VolumeOrder + 1 = b.VolumeOrder
		and a.IndicativePrice = b.IndicativePrice 
		and a.SurplusVolume < b.SurplusVolume
		where a.BidDown is null

		delete a
		from #TempMatchVolume2 as a
		where InverseVolumeOrder = 1

		if exists
		(
			select 1
			from #TempMatchVolume2 as a
			inner join #TempMatchVolume2 as b
			on a.VolumeOrder = 2
			and b.VolumeOrder in (3, 4)
			and a.IndicativePrice < b.IndicativePrice
		 )
		begin
			select 'Y' as SellAction, null as SellValue

			insert into [Working].[TempTradeAction]
			(
				[ASXCode],
				[TradeAction],
				[TradeValue],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				'S' as [TradeAction],
				cast(null as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
			
			return
		end

		if exists
		(
			select 1
			from #TempMatchVolume2 as a
			inner join #TempMatchVolume2 as b
			on a.VolumeOrder = 1
			and b.VolumeOrder in (2, 3)
			and a.IndicativePrice < b.IndicativePrice
		 )
		begin
			select 'Y' as SellAction, null as SellValue

			insert into [Working].[TempTradeAction]
			(
				[ASXCode],
				[TradeAction],
				[TradeValue],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				'S' as [TradeAction],
				cast(null as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
			
			return
		end

		declare @decBidDownRate as decimal(20, 4)
		select @decBidDownRate = sum(case when BidDown = 1 then 1 else 0 end)*1.0/count(*)
		from #TempMatchVolume2 
				
		if @decBidDownRate > 0.4
		begin
			select 'Y' as SellAction, null as SellValue

			insert into [Working].[TempTradeAction]
			(
				[ASXCode],
				[TradeAction],
				[TradeValue],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				'S' as [TradeAction],
				cast(null as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
			
			return
		end
		else
		begin
			select 'N' as SellAction, cast(null as decimal(20, 4)) as SellValue
		end		

		if exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 3
			and BidDown = 1
		) 
		and exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 2
			and BidDown = 1
		) 
		and exists
		(
			select 1
			from #TempMatchVolume2 
			where VolumeOrder = 1
			and BidDown = 1
		) 
		begin
			select 'Y' as SellAction, null as SellValue

			insert into [Working].[TempTradeAction]
			(
				[ASXCode],
				[TradeAction],
				[TradeValue],
				[CreateDate]
			)
			select
				@pvchASXCode as ASXCode,
				'S' as [TradeAction],
				cast(null as decimal(20, 4)) as [TradeValue],
				getdate() as CreateDate
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
