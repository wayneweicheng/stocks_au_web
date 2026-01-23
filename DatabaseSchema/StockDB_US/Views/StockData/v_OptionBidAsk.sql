-- View: [StockData].[v_OptionBidAsk]




CREATE view [StockData].[v_OptionBidAsk]
as
SELECT [OptionBidAskID]
      ,[ASXCode]
      ,[Underlying]
      ,[OptionSymbol]
	  ,ObservationDateLocal as ObservationDate
	  ,'20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) as ExpiryDate
	  ,'20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) as Expiry
	  ,cast(reverse(substring(reverse(OptionSymbol), 1, 8)) as decimal(20, 4))/1000.0 as Strike
	  ,reverse(substring(reverse(OptionSymbol), 9, 1)) as PorC
	  ,CONVERT(datetime, SWITCHOFFSET(ObservationTime, DATEPART(TZOFFSET, ObservationTime AT TIME ZONE 'Eastern Standard Time'))) as ObservationTime
      ,[PriceBid]
      ,[SizeBid]
      ,[PriceAsk]
      ,[SizeAsk]
      ,[CreateDateTime]
      ,[UpdateDateTime]
	  ,UpDown
  FROM [StockData].[OptionBidAsk]
  where len(OptionSymbol) > 0

