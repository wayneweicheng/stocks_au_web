-- View: [StockData].[v_OptionTrade]




CREATE view [StockData].[v_OptionTrade]
as
select 
	   [OptionTradeID]
      ,[ASXCode]
      ,[Underlying]
      ,[OptionSymbol]
	  ,ObservationDate
      ,SaleTime
	  ,ExpiryDate
	  ,Expiry
	  ,Strike
	  ,PorC
      ,[Price]
      ,[Size]
      ,[Exchange]
      ,[SpecialConditions]
	  ,Multiplier
	  ,TradeValue
      ,[CreateDateTime]
      ,[UpdateDateTime]
      ,[BuySellIndicator]
	  ,LongShortIndicator
	  ,QueryBidAskAt
	  ,QueryBidNum
from
(
  SELECT 
       [OptionTradeID]
      ,a.[ASXCode]
      ,a.[Underlying]
      ,a.[OptionSymbol]
	  ,a.ObservationDateLocal as ObservationDate
      ,CONVERT(datetime, SWITCHOFFSET(SaleTime, DATEPART(TZOFFSET, SaleTime AT TIME ZONE 'AUS Eastern Standard Time'))) as SaleTime
	  ,ExpiryDate
	  ,Expiry
	  ,Strike
	  ,PorC
      ,[Price]
      ,[Size]
      ,[Exchange]
      ,[SpecialConditions]
	  ,100 as Multiplier
	  ,a.Price*a.Size*100 as TradeValue
      ,a.[CreateDateTime]
      ,a.[UpdateDateTime]
      ,[BuySellIndicator]
	  ,LongShortIndicator
	  ,QueryBidAskAt
	  ,QueryBidNum
  FROM [StockData].[OptionTrade] as a
  where len(a.OptionSymbol) > 0
) as x
