-- View: [StockData].[v_OptionDelayedQuoteBackSeries_V2]


CREATE view [StockData].[v_OptionDelayedQuoteBackSeries_V2]
as
select
	   Strike 
	  ,PorC
	  ,ExpiryDate
	  ,cast(datepart(year, ExpiryDate) as varchar(20)) + right('0' + cast(datepart(month, ExpiryDate) as varchar(20)), 2) + right('0' + cast(datepart(day, ExpiryDate) as varchar(20)), 2) as Expiry
	  ,[ASXCode]
      ,[ObservationDate]
      ,ASXCode + '|' + cast(datepart(year, ExpiryDate) as varchar(20)) + right('0' + cast(datepart(month, ExpiryDate) as varchar(20)), 2) + right('0' + cast(datepart(day, ExpiryDate) as varchar(20)), 2) + '|' + PorC + '|' + cast(Strike as varchar(20)) as [OptionSymbol]
      ,null as [Bid]
      ,null as [BidSize]
      ,null as [Ask]
      ,null as [AskSize]
      ,null as [IV]
      ,OpenInterest as [OpenInterest]
      ,null as [Volume]
      ,null as [Delta]
      ,cast(case when OpenInterest = 0 then 0 else GEX/(OpenInterest*case when PorC = 'C' then 100.0 else -100.0 end) end as decimal(20, 4)) as [Gamma]
      ,null as [Theta]
      ,null as [RHO]
      ,null as [Vega]
      ,null as [Theo]
      ,null as [Change]
      ,null as [Open]
      ,null as [High]
      ,null as [Low]
      ,null as [Tick]
      ,null as [LastTradePrice]
      ,null as [LastTradeTime]
      ,null as [PrevDayClose]
      ,[CreateDate]
from [StockData].[GEXDetailsParsed] as a
where not exists
(
	select 1
	from StockData.OptionDelayedQuote_V2
	where ObservationDate = a.ObservationDate
	and ASXCode = a.ASXCode
)