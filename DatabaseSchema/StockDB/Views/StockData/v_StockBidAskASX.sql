-- View: [StockData].[v_StockBidAskASX]



CREATE view [StockData].[v_StockBidAskASX]
as
with outpt as
(
SELECT [StockBidAskASXID]
      ,a.[ASXCode]
	  ,a.ObservationDate
      ,a.ObservationTime
      ,[PriceBid]
      ,[SizeBid]
      ,[PriceAsk]
      ,[SizeAsk]
	  ,a.ObservationTime as DateFrom
	  ,row_number() over (partition by a.ASXCode, a.ObservationDate, a.ObservationTime order by CntPriceBid desc, CntPriceAsk desc, PriceBid asc, PriceAsk asc, SizeBid asc, SizeAsk asc) as RowNumber
  FROM [StockData].[StockBidAskASX] as a with(nolock)
  inner join 
  (
	select ASXCode, ObservationDate, ObservationTime, CntPriceBid, CntPriceAsk
	from [StockData].[mv_StockBidAskASX_Cnt] with(nolock)
  ) as b
  on a.ASXCode = b.ASXCode
  and a.ObservationDate = b.ObservationDate
  and a.ObservationTime = b.ObservationTime
)

select 
	*, 
	lag(PriceBid) over (partition by ASXCode, ObservationDate order by ObservationTime asc, StockBidAskASXID asc) as PrevPriceBid,
	lag(PriceAsk) over (partition by ASXCode, ObservationDate order by ObservationTime asc, StockBidAskASXID asc) as PrevPriceAsk,
	lead(DateFrom) over (partition by ASXCode, ObservationDate order by ObservationTime asc, StockBidAskASXID asc) as DateTo
from outpt
where RowNumber = 1;
