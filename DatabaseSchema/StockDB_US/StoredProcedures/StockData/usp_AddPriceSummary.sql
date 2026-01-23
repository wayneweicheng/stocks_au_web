-- Stored procedure: [StockData].[usp_AddPriceSummary]






CREATE PROCEDURE [StockData].[usp_AddPriceSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchQuoteTime as varchar(100),
@pdecBid decimal(20, 4),
@pdecOffer decimal(20, 4),
@pdecOpen decimal(20, 4),
@pdecHigh decimal(20, 4),
@pdecLow decimal(20, 4),
@pdecClose decimal(20, 4),
@pintVolume bigint,
@pdecValue decimal(20, 4),
@pintTrades int,
@pdecVWAP decimal(20, 4),
@pdecBids decimal(20, 4),
@pdecBidsTotalVolume bigint,
@pdecOffers decimal(20, 4),
@pdecOffersTotalVolume bigint,
@pdecIndicativePrice decimal(20, 4),
@pintSurplusVolume int,
@pdecPrevClose decimal(20, 4)
AS
/******************************************************************************
File: usp_AddPriceSummary.sql
Stored Procedure Name: usp_AddPriceSummary
Overview
-----------------
usp_AddPriceSummary

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
Date:		2018-06-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddPriceSummary'
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
		--begin transaction
		
		--@pxmlMarketDepth
		--declare @pvchQuoteTime as varchar(100) = '06/13/2018 23:04:46'
		declare @vchModifiedDateTime as varchar(100) = substring(@pvchQuoteTime, 7, 4) + '-' + substring(@pvchQuoteTime, 1, 2) + '-' + substring(@pvchQuoteTime, 4, 2) + ' ' + right(@pvchQuoteTime, 8)
		
		set dateformat ymd
		--select convert(smalldatetime, @vchModifiedDateTime, 121)

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select
			@pvchASXCode as ASXCode,
			@pdecBid as Bid,
			@pdecOffer as Offer,
			@pdecOpen as [Open],
			@pdecHigh as High,
			@pdecLow as Low,
			case when @pdecClose = 0 then @pdecPrevClose else @pdecClose end as [Close],
			@pintVolume as Volume,
			@pdecValue as Value,
			@pintTrades as Trades,
			@pdecVWAP as VWAP,
			convert(datetime, @vchModifiedDateTime, 121) as QuoteTime,
			@pdecBids as bids,
			@pdecBidsTotalVolume as bidsTotalVolume,
			@pdecOffers as offers,
			@pdecOffersTotalVolume as offersTotalVolume,
			@pdecIndicativePrice as IndicativePrice,
			@pintSurplusVolume as SurplusVolume,
			@pdecPrevClose as PrevClose
		into #TempPriceSummary

		--insert into Working.TempPriceSummary
		--(
		--   [ASXCode]
		--  ,[Bid]
		--  ,[Offer]
		--  ,[Open]
		--  ,[High]
		--  ,[Low]
		--  ,[Close]
		--  ,[Volume]
		--  ,[Value]
		--  ,[Trades]
		--  ,[VWAP]
		--  ,[QuoteTime]
		--  ,[bids]
		--  ,[bidsTotalVolume]
		--  ,[offers]
		--  ,[offersTotalVolume]
		--  ,[IndicativePrice]
		--  ,[SurplusVolume]
		--  ,[PrevClose]
		--  ,CreateDate
		--)
		--select
		--   [ASXCode]
		--  ,[Bid]
		--  ,[Offer]
		--  ,[Open]
		--  ,[High]
		--  ,[Low]
		--  ,[Close]
		--  ,[Volume]
		--  ,[Value]
		--  ,[Trades]
		--  ,[VWAP]
		--  ,[QuoteTime]
		--  ,[bids]
		--  ,[bidsTotalVolume]
		--  ,[offers]
		--  ,[offersTotalVolume]
		--  ,[IndicativePrice]
		--  ,[SurplusVolume]
		--  ,[PrevClose]
		--  ,getdate() as CreateDate			
		--from #TempPriceSummary

		if 
		(
			left(@pvchASXCode, 1) in ('A', 'B') and cast(convert(datetime, @vchModifiedDateTime, 121) as time) <= cast('10:00:15' as time)
			or
			left(@pvchASXCode, 1) in ('C', 'D', 'E', 'F') and cast(convert(datetime, @vchModifiedDateTime, 121) as time) <= cast('10:02:30' as time)
			or
			left(@pvchASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(convert(datetime, @vchModifiedDateTime, 121) as time) <= cast('10:04:45' as time)
			or
			left(@pvchASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(convert(datetime, @vchModifiedDateTime, 121) as time) <= cast('10:07:00' as time)
			or
			left(@pvchASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(convert(datetime, @vchModifiedDateTime, 121) as time) <= cast('10:09:15' as time)
			or 
			cast(convert(datetime, @vchModifiedDateTime, 121) as time) >= cast('16:00:00' as time)
			or
			@pdecOffer <= @pdecBid
		)
		begin
			print 'Aggregation Auction Time'
		end
		else
		begin

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = @pdecClose
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			where a.TradingAlertTypeID = 1
			and AlertTriggerDate is null
			and ASXCode = @pvchASXCode
			and @pdecClose > 0 
			and @pdecClose <= AlertPrice

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = @pdecClose
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			where a.TradingAlertTypeID = 2
			and AlertTriggerDate is null
			and ASXCode = @pvchASXCode
			and @pdecClose > 0 
			and @pdecClose >= AlertPrice

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = @pdecBid
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			where a.TradingAlertTypeID = 3
			and AlertTriggerDate is null
			and ASXCode = @pvchASXCode
			and @pdecBid > 0 
			and @pdecBid >= AlertPrice

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = @pdecOffer
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			where a.TradingAlertTypeID = 4
			and AlertTriggerDate is null
			and ASXCode = @pvchASXCode
			and @pdecOffer > 0 
			and @pdecOffer <= AlertPrice

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualVolume = @pintVolume
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			where a.TradingAlertTypeID = 5
			and AlertTriggerDate is null
			and ASXCode = @pvchASXCode
			and @pintVolume > 0 
			and @pintVolume >= AlertVolume

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualVolume = @pintVolume
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			where a.TradingAlertTypeID = 6
			and AlertTriggerDate is null
			and ASXCode = @pvchASXCode
			and cast(getdate() as time) > cast('15:40:00' as time)
			and cast(getdate() as time) < cast('15:55:00' as time)
			and @pintVolume > 0 
			and @pintVolume < AlertVolume

		end

		update a
		set a.DateTo = b.QuoteTime
		from StockData.PriceSummaryToday as a
		inner join #TempPriceSummary as b
		on a.ASXCode = b.ASXCode
		and cast(a.DateFrom as date) = cast(b.QuoteTime as date)
		left join #TempPriceSummary as c
		on a.ASXCode = c.ASXCode
		and cast(a.DateFrom as date) = cast(c.QuoteTime as date)
		and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		and isnull(a.[High], -1) = isnull(c.[High], -1)
		and isnull(a.Low, -1) = isnull(c.Low, -1)
		and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		and isnull(a.Value, -1) = isnull(c.Value, -1)
		and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--and isnull(a.bids, -1) = isnull(c.bids, -1)
		--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
		--and isnull(a.offers, -1) = isnull(c.offers, -1)
		--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
		and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
		and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
		where a.DateTo is null
		and c.ASXCode is null
		and a.ASXCode = @pvchASXCode

		update a
		set a.LastVerifiedDate = c.QuoteTime,
			a.VWAP = c.VWAP
		from StockData.PriceSummaryToday as a
		inner join #TempPriceSummary as c
		on a.ASXCode = c.ASXCode
		and cast(a.DateFrom as date) = cast(c.QuoteTime as date)
		and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		and isnull(a.[High], -1) = isnull(c.[High], -1)
		and isnull(a.Low, -1) = isnull(c.Low, -1)
		and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		and isnull(a.Value, -1) = isnull(c.Value, -1)
		and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--and isnull(a.bids, -1) = isnull(c.bids, -1)
		--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
		--and isnull(a.offers, -1) = isnull(c.offers, -1)
		--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
		and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
		and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
		where a.DateTo is null
		and isnull(a.LastVerifiedDate, '2050-01-12') != c.QuoteTime
		and a.ASXCode = @pvchASXCode

		if exists
		(
			select 1
			from #TempPriceSummary as a
			where not exists
			(
				select 1
				from StockData.PriceSummaryToday as c
				where a.ASXCode = c.ASXCode
				and cast(a.QuoteTime as date) = cast(c.DateFrom as date)
				and isnull(a.Bid, -1) = isnull(c.Bid, -1)
				and isnull(a.Offer, -1) = isnull(c.Offer, -1)
				and isnull(a.[Open], -1) = isnull(c.[Open], -1)
				and isnull(a.[High], -1) = isnull(c.[High], -1)
				and isnull(a.Low, -1) = isnull(c.Low, -1)
				and isnull(a.[Close], -1) = isnull(c.[Close], -1)
				and isnull(a.Volume, -1) = isnull(c.Volume, -1)
				and isnull(a.Value, -1) = isnull(c.Value, -1)
				and isnull(a.Trades, -1) = isnull(c.Trades, -1)
				--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
				--and isnull(a.bids, -1) = isnull(c.bids, -1)
				--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
				--and isnull(a.offers, -1) = isnull(c.offers, -1)
				--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
				and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
				and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
				and c.DateTo is null
				and c.ASXCode = @pvchASXCode
			)
		)
		begin
			update a
			set a.LatestForTheDay = 0
			from StockData.PriceSummaryToday as a
			where a.ASXCode = @pvchASXCode
			and a.ObservationDate = cast(getdate() as date)
			and a.LatestForTheDay = 1
		end

		declare @intPriceSummaryID as int 
		insert into StockData.PriceSummaryToday
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
			,LastVerifiedDate
			,bids
			,bidsTotalVolume
			,offers
			,offersTotalVolume
			,IndicativePrice
			,SurplusVolume
			,PrevClose
			,SysCreateDate
			,ObservationDate
			,LatestForTheDay
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
			,QuoteTime as [DateFrom]
			,null as [DateTo]
			,QuoteTime as LastVerifiedDate
			,bids
			,bidsTotalVolume
			,offers
			,offersTotalVolume
			,IndicativePrice
			,SurplusVolume
			,PrevClose
			,getdate() as SysCreateDate
			,cast(getdate() as date) as ObservationDate
			,1 as LatestForTheDay
		from #TempPriceSummary as a
		where not exists
		(
			select 1
			from StockData.PriceSummaryToday as c
			where a.ASXCode = c.ASXCode
			and cast(a.QuoteTime as date) = cast(c.DateFrom as date)
			and isnull(a.Bid, -1) = isnull(c.Bid, -1)
			and isnull(a.Offer, -1) = isnull(c.Offer, -1)
			and isnull(a.[Open], -1) = isnull(c.[Open], -1)
			and isnull(a.[High], -1) = isnull(c.[High], -1)
			and isnull(a.Low, -1) = isnull(c.Low, -1)
			and isnull(a.[Close], -1) = isnull(c.[Close], -1)
			and isnull(a.Volume, -1) = isnull(c.Volume, -1)
			and isnull(a.Value, -1) = isnull(c.Value, -1)
			and isnull(a.Trades, -1) = isnull(c.Trades, -1)
			--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
			--and isnull(a.bids, -1) = isnull(c.bids, -1)
			--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
			--and isnull(a.offers, -1) = isnull(c.offers, -1)
			--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
			and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
			and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
			and c.DateTo is null
			and c.ASXCode = @pvchASXCode
		)

		select @intPriceSummaryID = @@identity

		if @intPriceSummaryID > 0
		begin
			update x
			set x.SysLastSaleDate = y.SysLastSaleDate
			from StockData.PriceSummaryToday as x
			inner join
			(
				select
					a.ASXCode,
					a.Volume,
					min(a.SysCreateDate) as SysLastSaleDate
				from StockData.PriceSummaryToday as a
				where cast(a.DateFrom as date) = cast(getdate() as date)
				and a.ASXCode = @pvchASXCode
				group by
					a.ASXCode,
					a.Volume
			) as y
			on x.ASXCode = y.ASXCode
			and x.Volume = y.Volume
			and x.ASXCode = @pvchASXCode

			update x
			set x.Prev1PriceSummaryID = y.Prev1PriceSummaryID
			from StockData.PriceSummaryToday as x
			inner join
			(
				select
					a.ASXCode,
					a.DateFrom,
					max(b.PriceSummaryID) as Prev1PriceSummaryID
				from StockData.PriceSummaryToday as a
				inner join StockData.PriceSummaryToday as b
				on cast(a.DateFrom as date) = cast(getdate() as date)
				and a.ASXCode = b.ASXCode
				and a.DateFrom > b.DateFrom
				and a.ASXCode = @pvchASXCode
				and a.DateTo is null
				group by a.ASXCode, a.DateFrom
			) as y
			on x.ASXCode = y.ASXCode
			and x.DateFrom = y.DateFrom

			update x
			set x.Prev1Bid = y.Bid,
				x.Prev1Offer = y.Offer,
				x.Prev1Volume = y.Volume,
				x.Prev1Value = y.[Value],
				x.VolumeDelta = x.Volume - y.Volume,
				x.ValueDelta = x.[Value] - y.[Value],
				x.TimeIntervalInSec = datediff(second, y.LastVerifiedDate, x.DateFrom),
				x.Prev1Close = y.[close]
			from StockData.PriceSummaryToday as x
			inner join StockData.PriceSummaryToday as y
			on x.Prev1PriceSummaryID = y.PriceSummaryID 
			and x.DateTo is null
			and x.ASXCode = @pvchASXCode

			update x
			set x.BuySellInd = case when x.VolumeDelta > 0 and x.[close] = x.Prev1Offer and x.[close] > x.Prev1Bid then 'B'
									when x.VolumeDelta > 0 and x.[close] = x.Prev1Bid and x.[close] < x.Prev1Offer then 'S'
									when x.VolumeDelta > 0 and x.[close] > x.[Prev1Close] then 'B'
									when x.VolumeDelta > 0 and x.[close] < x.[Prev1Close] then 'S'
									else null
							   end
			from StockData.PriceSummaryToday as x
			where x.DateTo is null
			and x.ASXCode = @pvchASXCode



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
