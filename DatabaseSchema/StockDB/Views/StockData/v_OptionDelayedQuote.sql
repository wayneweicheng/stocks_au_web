-- View: [StockData].[v_OptionDelayedQuote]


CREATE view [StockData].[v_OptionDelayedQuote]
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
from StockData.OptionDelayedQuote
