-- View: [StockData].[v_PriceSummaryToday_MatchVolume]



create view [StockData].[v_PriceSummaryToday_MatchVolume]
as
select 
	   [PriceSummaryID]
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
      ,[MatchVolume]
from
(
	select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
	from StockData.PriceSummaryToday with(nolock)
	where 1 = 1
	and MatchVolume > 0
	and Volume = 0
) as a
where RowNumber = 1
