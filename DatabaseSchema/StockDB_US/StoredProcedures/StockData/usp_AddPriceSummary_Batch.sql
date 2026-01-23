-- Stored procedure: [StockData].[usp_AddPriceSummary_Batch]


CREATE PROCEDURE [StockData].[usp_AddPriceSummary_Batch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchPriceSummaryJson as varchar(max),
@pvchWatchListName as varchar(100),
@pbitTriggerAlert as bit = 1,
@pbitTriggerOrder as bit = 1
AS
/******************************************************************************
File: usp_AddPriceSummary_Batch.sql
Stored Procedure Name: usp_AddPriceSummary_Batch
Overview
-----------------
usp_AddPriceSummary_Batch

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
Date:		2019-10-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddPriceSummary_Batch'
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

		if object_id(N'Tempdb.dbo.#TempPriceSummaryRaw') is not null
			drop table #TempPriceSummaryRaw

		insert into StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate,
			WatchListName
		)
		select
			case when @pvchWatchListName != 'WL99' then 60 else 61 end as DataTypeID,
			@pvchPriceSummaryJson as RawData,
			getdate() as CreateDate,
			getdate() as SourceSystemDate,
			@pvchWatchListName as WatchListName

		select 
			--EvId, PackageStatus, Responses, Response.TId, Quotes, Quote.ExchangeId, 
			Quote.StockCode, 
			Quote.LastPrice, 
			Quote.BestBuyPrice,
			Quote.BestSellPrice, 
			Quote.HighSalePrice, 
			Quote.LowSalePrice,
			Quote.TotalVolumeTraded,
			Quote.TotalValueTraded,
			Quote.TotalNumberOfTrades,
			Quote.VWapPrice,
			Quote.PriceChange,
			Quote.PriceChangePercent,
			Quote.Bids,
			Quote.BidsTotalVolume,
			Quote.Offers,
			Quote.OffersTotalVolume,
			Quote.QuoteTime,
			Quote.SurplusVolume,
			Quote.ClosingPrice,
			Quote.OpeningPrice,
			Quote.IndicativePrice,
			Quote.MatchVolume
		into #TempPriceSummaryRaw
		from openjson (@pvchPriceSummaryJson)
		with
		(
			EvId varchar(100),
			Success varchar(100),
			PackageStatus varchar(100),
			Responses nvarchar(max) AS JSON,
			Date varchar(100),
			PollFreqMin int,
			Et varchar(100)
		) as FullJson
		cross apply openjson (FullJson.Responses)
		with
		(
			TId varchar(100),
			Model nvarchar(max) as Json
		) as Response
		cross apply openjson (Response.Model) 
		with
		(
			Quotes nvarchar(max) as Json
		) as Quotes
		cross apply openjson(Quotes.Quotes)
		with
		(
			ExchangeId varchar(100),
			StockCode varchar(100),
			LastPrice varchar(100),
			BestBuyPrice varchar(100),
			BestSellPrice varchar(100),
			HighSalePrice varchar(100),
			LowSalePrice varchar(100),
			TotalVolumeTraded varchar(100),
			TotalValueTraded varchar(100),
			TotalNumberOfTrades varchar(100),
			VWapPrice varchar(100),
			PriceChange varchar(100),
			PriceChangePercent varchar(100),
			Bids varchar(100),
			BidsTotalVolume varchar(100),
			Offers varchar(100),
			OffersTotalVolume varchar(100),
			QuoteTime varchar(100),
			SurplusVolume varchar(100),
			ClosingPrice varchar(100),
			OpeningPrice varchar(100),
			IndicativePrice varchar(100),
			MatchVolume varchar(100)
		) as Quote

		set dateformat ymd
		
		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select
			case when StockCode like '%:US' then replace(StockCode, ':US', '.US') else StockCode + '.AX' end as ASXCode,
			cast(BestBuyPrice as decimal(20, 4)) as Bid,
			cast(BestSellPrice as decimal(20, 4)) as Offer,
			cast(OpeningPrice as decimal(20, 4)) as [Open],
			cast(HighSalePrice as decimal(20, 4)) as High,
			cast(LowSalePrice as decimal(20, 4)) as Low,
			case when try_cast(LastPrice as decimal(20, 4)) = 0 then try_cast(ClosingPrice as decimal(20, 4)) else try_cast(LastPrice as decimal(20, 4)) end as [Close],
			cast(TotalVolumeTraded as bigint) as Volume,
			cast(TotalValueTraded as decimal(20, 4)) as Value,
			cast(TotalNumberOfTrades as int) as Trades,
			cast(VWapPrice as decimal(20, 4)) as VWAP,
			convert(datetime, substring(QuoteTime, 1, 10) + ' ' + right(QuoteTime, 8), 121) as QuoteTime,
			cast(Bids as decimal(20, 4)) as bids,
			cast(BidsTotalVolume as bigint) as bidsTotalVolume,
			cast(Offers as decimal(20, 4)) as offers,
			cast(OffersTotalVolume as bigint) as offersTotalVolume,
			cast(IndicativePrice as decimal(20, 4)) as IndicativePrice,
			cast(SurplusVolume as bigint) as SurplusVolume,
			cast(ClosingPrice as decimal(20, 4)) as PrevClose,
			cast(MatchVolume as bigint) as MatchVolume
		into #TempPriceSummary
		from #TempPriceSummaryRaw

		if 
		(
			@pbitTriggerAlert = 1
		)
		begin

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.[Close]
			from [Alert].[v_TradingAlert] as a with(nolock)
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Close] > 0
			and c.[Close] <= a.AlertPrice
			where a.TradingAlertTypeID = 1
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.[Close]
			from [Alert].[v_TradingAlert] as a with(nolock)
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Close] > 0
			and c.[Close] >= a.AlertPrice
			where a.TradingAlertTypeID = 2
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.Bid
			from [Alert].[v_TradingAlert] as a with(nolock)
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Bid] > 0
			and c.[Bid] >= a.AlertPrice
			where a.TradingAlertTypeID = 3
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.[Offer]
			from [Alert].[v_TradingAlert] as a with(nolock)
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Offer] > 0
			and c.[Offer] <= a.AlertPrice
			where a.TradingAlertTypeID = 4
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualVolume = c.Volume
			from [Alert].[v_TradingAlert] as a with(nolock)
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Volume] > 0
			and c.[Volume] >= a.AlertVolume
			where a.TradingAlertTypeID = 5
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualVolume = c.Volume
			from [Alert].[v_TradingAlert] as a with(nolock)
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Volume] > 0
			and c.[Volume] < a.AlertVolume
			where a.TradingAlertTypeID = 6
			and AlertTriggerDate is null
			and cast(getdate() as time) > cast('15:40:00' as time)
			and cast(getdate() as time) < cast('15:55:00' as time)
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
		end

		if 
		(
			@pbitTriggerOrder = 1
		)
		begin
			print 'Trigger conditional orders'

			update a
			set a.OrderTriggerDate = getdate(),
				a.ActualOrderPrice = a.OrderPrice
			from [Order].[v_Order] as a with(nolock)
			inner join LookupRef.OrderType as b
			on a.OrderTypeID = b.OrderTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.Bid > 0
			and c.Bid >= a.OrderPrice
			where a.OrderTypeID in (1, 5)
			and a.OrderTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				c.Offer <= c.Bid
			)

			--if @@ROWCOUNT > 0
			--begin
			--	exec [Order].[usp_PlaceOrder]
			--end

			update a
			set a.OrderTriggerDate = getdate(),
				a.ActualOrderPrice = a.OrderPrice
			from [Order].[v_Order] as a with(nolock)
			inner join LookupRef.OrderType as b
			on a.OrderTypeID = b.OrderTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.Offer > 0
			and c.Offer <= a.OrderPrice
			where a.OrderTypeID in (2, 4)
			and a.OrderTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				c.Offer <= c.Bid
			)

			--if @@ROWCOUNT > 0
			--begin
			--	exec [Order].[usp_PlaceOrder]
			--end
			
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
		and isnull(a.MatchVolume, -1) = isnull(c.MatchVolume, -1)
		where a.DateTo is null
		and c.ASXCode is null
		and a.WatchListName = @pvchWatchListName
		
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
		and isnull(a.MatchVolume, -1) = isnull(c.MatchVolume, -1)
		where a.DateTo is null
		and isnull(a.LastVerifiedDate, '2050-01-12') != c.QuoteTime
		and a.WatchListName = @pvchWatchListName

		update c
		set c.LatestForTheDay = 0
		from StockData.PriceSummaryToday as c
		inner join #TempPriceSummary as b
		on c.ASXCode = b.ASXCode
		and cast(c.DateFrom as date) = cast(b.QuoteTime as date)
		where c.ObservationDate = cast(getdate() as date)
		and c.LatestForTheDay = 1
		and not exists
		(
			select 1
			from #TempPriceSummary as a
			where ASXCode = a.ASXCode
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
			and isnull(a.MatchVolume, -1) = isnull(c.MatchVolume, -1)
		)
		and c.DateTo is null
		and c.WatchListName = @pvchWatchListName

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
			,MatchVolume
			,PrevClose
			,SysCreateDate
			,ObservationDate
			,LatestForTheDay
			,SeqNumber
			,WatchListName
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
			,MatchVolume
			,PrevClose
			,getdate() as SysCreateDate
			,cast(QuoteTime as date) as ObservationDate
			,1 as LatestForTheDay
			,null as SeqNumber
			,@pvchWatchListName as WatchListName
		from #TempPriceSummary as a
		where not exists
		(
			select 1
			from StockData.PriceSummaryToday as c
			where a.ASXCode = c.ASXCode
			and cast(a.QuoteTime as date) = c.ObservationDate
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
			and isnull(a.MatchVolume, -1) = isnull(c.MatchVolume, -1)
			and c.DateTo is null
			and c.WatchListName = @pvchWatchListName
		) 
		--and not exists
		--(
		--	select 1
		--	from StockData.PriceSummaryToday as c
		--	where cast(a.QuoteTime as date) = c.ObservationDate
		--	and c.ASXCode = a.ASXCode
		--	and c.[Volume] > a.[Volume]
		--)

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
			and exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
			)
			group by
				a.ASXCode,
				a.Volume
		) as y
		on x.ASXCode = y.ASXCode
		and x.Volume = y.Volume
		and x.WatchListName = @pvchWatchListName

		update x
		set x.SeqNumber = y.SeqNumber
		from StockData.PriceSummaryToday as x
		inner join
		(
			select 
				a.PriceSummaryID,
				a.ASXCode,
				a.DateFrom,
				a.ObservationDate,
				row_number() over (partition by ASXCode, ObservationDate order by DateFrom asc) as SeqNumber
			from StockData.PriceSummaryToday as a
			where exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
			)
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		and x.PriceSummaryID = y.PriceSummaryID
		and x.WatchListName = @pvchWatchListName

		update x
		set x.Prev1Bid = y.Bid,
			x.Prev1Offer = y.Offer,
			x.Prev1Volume = y.Volume,
			x.Prev1Value = y.Value,
			x.VolumeDelta = x.Volume - y.Volume,
			x.ValueDelta = x.[Value] - y.[Value] ,
			x.TimeIntervalInSec = datediff(second, y.DateFrom, x.DateFrom),
			x.Prev1Close = y.[Close]
		from StockData.PriceSummaryToday as x
		inner join StockData.PriceSummaryToday as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		and x.SeqNumber = y.SeqNumber + 1
		--and x.DateTo is null
		and exists
		(
			select 1
			from #TempPriceSummary
			where ASXCode = x.ASXCode
		)
		and x.WatchListName = @pvchWatchListName
		and y.WatchListName = @pvchWatchListName
			
		update x
		set x.BuySellInd = case when x.VolumeDelta > 0 and x.[close] = x.Prev1Offer and x.[close] > x.Prev1Bid then 'B'
								when x.VolumeDelta > 0 and x.[close] = x.Prev1Bid and x.[close] < x.Prev1Offer then 'S'
								when x.VolumeDelta > 0 and x.[close] > x.[Prev1Close] then 'B'
								when x.VolumeDelta > 0 and x.[close] < x.[Prev1Close] then 'S'
								else null
							end
		from StockData.PriceSummaryToday as x
		where x.DateTo is null
		and exists
		(
			select 1
			from #TempPriceSummary
			where ASXCode = x.ASXCode
		)
		and x.WatchListName = @pvchWatchListName

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
