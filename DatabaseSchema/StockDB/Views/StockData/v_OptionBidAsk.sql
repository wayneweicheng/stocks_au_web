-- View: [StockData].[v_OptionBidAsk]






CREATE view [StockData].[v_OptionBidAsk]
as
SELECT [OptionBidAskID]
      ,a.[ASXCode]
      ,a.[Underlying]
      ,a.[OptionSymbol]
	  ,ObservationDateLocal as ObservationDate
	  ,b.ExpiryDate as ExpiryDate
	  ,b.Expiry as Expiry
	  ,b.Strike as Strike
	  ,b.PorC as PorC
	  ,CONVERT(datetime, SWITCHOFFSET(ObservationTime, DATEPART(TZOFFSET, ObservationTime AT TIME ZONE 'AUS Eastern Standard Time'))) as ObservationTime
      ,[PriceBid]
      ,[SizeBid]
      ,[PriceAsk]
      ,[SizeAsk]
      ,a.[CreateDateTime]
      ,a.[UpdateDateTime]
	  ,UpDown
  FROM [StockData].[OptionBidAsk] as a
  inner join
  (
	select OptionSymbol, min(Expiry) as Expiry, min(Strike) as Strike, min(ExpiryDate) as ExpiryDate, min(PorC) as PorC
	from StockData.OptionTrade
	group by OptionSymbol
  ) as b
  on a.OptionSymbol = b.OptionSymbol
  where len(a.OptionSymbol) > 0


