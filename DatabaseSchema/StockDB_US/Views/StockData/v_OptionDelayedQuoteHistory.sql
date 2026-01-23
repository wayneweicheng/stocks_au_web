-- View: [StockData].[v_OptionDelayedQuoteHistory]






CREATE view [StockData].[v_OptionDelayedQuoteHistory]
as
select
	   case when [ASXCode] = '_SPX.US' and OptionSymbol like 'SPXW%' then 'SPXW.US' 
			when [ASXCode] = '_SPX.US' and OptionSymbol not like 'SPXW%' then 'SPX.US' 
			else [ASXCode]
	   end as [ASXCode]
      ,[ObservationDate]
      ,[OptionSymbol]
      ,[Bid]
      ,[BidSize]
      ,[Ask]
      ,[AskSize]
      ,[IV]
      ,[OpenInterest]
      ,[Volume]
      ,[Delta]
      ,[Gamma]
      ,[Theta]
      ,[RHO]
      ,[Vega]
      ,[Theo]
      ,[Change]
      ,[Open]
      ,[High]
      ,[Low]
      ,[Tick]
      ,[LastTradePrice]
      ,[LastTradeTime]
      ,[PrevDayClose]
      ,[CreateDate]
	  ,[Strike]
      ,[PorC]
      ,[ExpiryDate]
      ,[Expiry]
from StockData.OptionDelayedQuoteHistory
