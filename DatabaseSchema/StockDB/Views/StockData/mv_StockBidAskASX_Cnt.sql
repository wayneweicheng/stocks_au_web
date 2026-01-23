-- View: [StockData].[mv_StockBidAskASX_Cnt]


create view [StockData].[mv_StockBidAskASX_Cnt] with schemabinding
as
select ASXCode, ObservationDate, ObservationTime, count(distinct PriceBid) as CntPriceBid, count(distinct PriceAsk) as CntPriceAsk
from [StockData].[StockBidAskASX]
group by ASXCode, ObservationDate, ObservationTime
