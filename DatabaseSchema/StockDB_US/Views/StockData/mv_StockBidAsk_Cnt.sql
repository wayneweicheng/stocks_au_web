-- View: [StockData].[mv_StockBidAsk_Cnt]



create view [StockData].[mv_StockBidAsk_Cnt] with schemabinding
as
select ASXCode, ObservationDate, ObservationTime, count(distinct PriceBid) as CntPriceBid, count(distinct PriceAsk) as CntPriceAsk
from [StockData].[StockBidAsk]
group by ASXCode, ObservationDate, ObservationTime
