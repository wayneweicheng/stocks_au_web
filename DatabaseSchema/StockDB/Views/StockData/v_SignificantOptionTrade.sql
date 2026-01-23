-- View: [StockData].[v_SignificantOptionTrade]


CREATE view [StockData].[v_SignificantOptionTrade]
as
SELECT [SignificantOptionTradeID]
      ,a.[ASXCode]
      ,a.[Underlying]
      ,a.[OptionSymbol]
	  ,cast(CONVERT(datetime, SWITCHOFFSET(SaleTime, DATEPART(TZOFFSET, SaleTime AT TIME ZONE 'Eastern Standard Time'))) as date) as ObservationDate
      ,CONVERT(datetime, SWITCHOFFSET(SaleTime, DATEPART(TZOFFSET, SaleTime AT TIME ZONE 'Eastern Standard Time'))) as SaleTime
      ,[Price]
      ,[Size]
      ,[Exchange]
      ,[SpecialConditions]
	  ,b.Multiplier
	  ,b.ExpiryDate
	  ,a.Price*a.Size*b.Multiplier as TradeValue
      ,a.[CreateDateTime]
      ,a.[UpdateDateTime]
      ,[BuySellIndicator]
	  ,LongShortIndicator
  FROM [StockData].[SignificantOptionTrade] as a
  left join StockData.OptionContract as b
  on a.OptionSymbol = b.OptionSymbol

