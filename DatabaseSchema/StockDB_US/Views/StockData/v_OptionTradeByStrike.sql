-- View: [StockData].[v_OptionTradeByStrike]


CREATE view StockData.v_OptionTradeByStrike
as
select a.ObservationDate, a.Strike, a.PorC, sum(b.Gamma*a.Size*100) as GEX
from StockData.v_OptionTrade as a
inner join StockData.v_OptionDelayedQuote as b
on a.OptionSymbol = b.OptionSymbol
where a.ASXCode = 'SPXW.US'
--and a.ObservationDate = '2023-12-22'
and a.ExpiryDate <= Common.DateAddBusinessDay(3, a.ObservationDate)
group by a.ObservationDate, a.Strike, a.PorC