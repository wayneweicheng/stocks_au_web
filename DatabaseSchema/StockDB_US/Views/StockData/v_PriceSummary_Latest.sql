-- View: [StockData].[v_PriceSummary_Latest]



CREATE view [StockData].[v_PriceSummary_Latest]
as
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
	  ,case when [PrevClose] > 0 then cast(([Close] - [PrevClose])*100.0/[PrevClose] as decimal(10, 2)) else null end as PriceChangeVsPrevClose
	  ,case when [Open] > 0 then cast(([Close] - [Open])*100.0/[Open] as decimal(10, 2)) else null end as PriceChangeVsOpen
	  ,([High] - [Low]) as Spread
FROM [StockData].[v_PriceSummary]
where DateTo is null
and LatestForTheDay = 1
