-- View: [StockData].[v_OptionDelayedQuote_All]









CREATE view [StockData].[v_OptionDelayedQuote_All]
as
select 
	a.*, 
	case when Prev1LastTradePrice > 0 then cast((LastTradePrice - Prev1LastTradePrice)*100.0/Prev1LastTradePrice as decimal(10, 2)) else null end as PriceChange,
	b.[Close] as [UnderlyingClose],
	b.TodayChange as UnderlyingPriceChange
from
(
	select
		*,
		lead(Volume) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Volume,
		lead(OpenInterest) over (partition by OptionSymbol order by ObservationDate desc) as Prev1OpenInterest,
		lead(Delta) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Delta,
		lead(Gamma) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Gamma,
		lead(LastTradePrice) over (partition by OptionSymbol order by ObservationDate desc) as Prev1LastTradePrice
	from [StockData].[v_OptionDelayedQuote]
) as a
left join StockData.v_PriceHistory as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate


