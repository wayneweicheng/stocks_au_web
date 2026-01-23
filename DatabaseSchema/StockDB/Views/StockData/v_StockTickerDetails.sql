-- View: [StockData].[v_StockTickerDetails]



create view StockData.v_StockTickerDetails
as
select 
	a.ASXCode,
	a.CreateDate,
	TickerJson,
	json_value(TickerJson, '$.contract.exchange') as exchange,
	json_value(TickerJson, '$.bid') as bid,
	json_value(TickerJson, '$.bidSize') as bidSize,
	json_value(TickerJson, '$.ask') as ask,
	json_value(TickerJson, '$.askSize') as askSize,
	json_value(TickerJson, '$.last') as last,
	json_value(TickerJson, '$.lastSize') as lastSize,
	json_value(TickerJson, '$.prevBid') as prevBid,
	json_value(TickerJson, '$.prevBidSize') as prevBidSize,
	json_value(TickerJson, '$.prevAsk') as prevAsk,
	json_value(TickerJson, '$.prevAskSize') as prevAskSize,
	json_value(TickerJson, '$.prevLast') as prevLast,
	json_value(TickerJson, '$.prevLastSize') as prevLastSize,
	json_value(TickerJson, '$.volume') as volume,
	json_value(TickerJson, '$.open') as [open],
	json_value(TickerJson, '$.high') as [high],
	json_value(TickerJson, '$.low') as [low],
	json_value(TickerJson, '$.close') as [close],
	json_value(TickerJson, '$.vwap') as [vwap],
	json_value(TickerJson, '$.markPrice') as [markPrice],
	json_value(TickerJson, '$.halted') as [halted],
	json_value(TickerJson, '$.rtVolume') as [rtVolume],
	json_value(TickerJson, '$.rtTradeVolume') as [rtTradeVolume],
	json_value(TickerJson, '$.auctionVolume') as [auctionVolume],
	json_value(TickerJson, '$.auctionPrice') as [auctionPrice],
	json_value(TickerJson, '$.auctionImbalance') as [auctionImbalance]
from [StockData].[StockTickerDetail] as a
where 1 = 1
and isjson(TickerJson)=1;
