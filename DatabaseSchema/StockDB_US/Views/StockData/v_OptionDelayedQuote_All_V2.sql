-- View: [StockData].[v_OptionDelayedQuote_All_V2]





CREATE view [StockData].[v_OptionDelayedQuote_All_V2]
as
select
	*,
	lead(OpenInterest) over (partition by OptionSymbol order by ObservationDate desc) as Prev1OpenInterest,
	lead(Delta) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Delta,
	lead(Gamma) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Gamma
from [StockData].[v_OptionDelayedQuote_V2]
