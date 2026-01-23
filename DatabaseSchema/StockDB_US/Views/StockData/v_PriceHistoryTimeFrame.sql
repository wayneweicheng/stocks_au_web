-- View: [StockData].[v_PriceHistoryTimeFrame]


create view StockData.v_PriceHistoryTimeFrame
as
SELECT [ASXCode]
      ,[TimeFrame]
      ,[TimeIntervalStart]
	  ,([TimeIntervalStart] at TIME ZONE 'Eastern Standard Time') at time zone 'AUS Eastern Standard Time' as [TimeIntervalStartAU]
      ,[Open]
      ,[High]
      ,[Low]
      ,[Close]
      ,[Volume]
      ,[FirstSale]
      ,[LastSale]
      ,[SaleValue]
      ,[NumOfSale]
      ,[AverageValuePerTransaction]
      ,[VWAP]
      ,[ObservationDate]
FROM [StockData].[PriceHistoryTimeFrame]
