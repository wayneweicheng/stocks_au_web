-- View: [StockData].[v_OptionDelayedQuote_V2]







CREATE view [StockData].[v_OptionDelayedQuote_V2]
as
select
	   Strike 
	  ,PorC
	  ,ExpiryDate
	  ,Expiry
	  ,[ASXCode]
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
from StockData.OptionDelayedQuote_V2
