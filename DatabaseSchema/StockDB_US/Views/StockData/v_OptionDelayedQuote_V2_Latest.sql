-- View: [StockData].[v_OptionDelayedQuote_V2_Latest]








create view [StockData].[v_OptionDelayedQuote_V2_Latest]
as
select
	   Strike 
	  ,PorC
	  ,ExpiryDate
	  ,Expiry
	  ,a.[ASXCode]
      ,a.[ObservationDate]
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
from StockData.OptionDelayedQuote_V2 as a
inner join
(
	select ASXCode, max(ObservationDate) as ObservationDate
	from StockData.OptionDelayedQuote_V2
	group by ASXCode
) as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate
