-- View: [StockData].[v_PriceSummary_MatchVolume]


create view [StockData].[v_PriceSummary_MatchVolume]
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
union all
SELECT 
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
FROM Transform.PriceSummaryMatchVolume as a
where not exists
(
	select 1
	from [StockData].[PriceSummaryToday]
	where ObservationDate = a.ObservationDate
)
