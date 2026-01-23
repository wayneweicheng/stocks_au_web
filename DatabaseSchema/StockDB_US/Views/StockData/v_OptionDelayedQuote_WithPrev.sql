-- View: [StockData].[v_OptionDelayedQuote_WithPrev]










CREATE view [StockData].[v_OptionDelayedQuote_WithPrev]
as
select 
	a.*
from
(
	select
		ASXCode,
		OptionSymbol,
		ObservationDate,
		Volume,
		OpenInterest,
		Delta,
		Gamma,
		lead(Volume) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Volume,
		lead(OpenInterest) over (partition by OptionSymbol order by ObservationDate desc) as Prev1OpenInterest,
		lead(Delta) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Delta,
		lead(Gamma) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Gamma
	from [StockData].[v_OptionDelayedQuote]
) as a

