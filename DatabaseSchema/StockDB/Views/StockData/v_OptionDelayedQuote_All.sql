-- View: [StockData].[v_OptionDelayedQuote_All]













CREATE view [StockData].[v_OptionDelayedQuote_All]
as
select
	case when b.[Close] >  0 then (a.Strike - b.[Close])*100.0/b.[Close] end as StrikeChange,
	b.[Close] as [UnderlyingClose],
	b.TodayChange as UnderlyingPriceChange,
	a.*, 
	case when Prev1LastTradePrice > 0 then cast((LastTradePrice - Prev1LastTradePrice)*100.0/Prev1LastTradePrice as decimal(10, 2)) else null end as PriceChange,
	OpenInterest - Prev1OpenInterest as OpenInterestChange,
	(OpenInterest - Prev1OpenInterest)*100*LastTradePrice as OIValueChange
from
(
	select
		*,
		lead(OpenInterest) over (partition by OptionSymbol order by ObservationDate desc) as Prev1OpenInterest,
		lead(Delta) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Delta,
		lead(Gamma) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Gamma,
		lead(LastTradePrice) over (partition by OptionSymbol order by ObservationDate desc) as Prev1LastTradePrice
	from [StockData].[v_OptionDelayedQuote]
) as a
left join StockData.v_PriceHistory as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate


