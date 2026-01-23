-- View: [Alert].[v_TradingAlert]



CREATE view [Alert].[v_TradingAlert]
as
SELECT [TradingAlertID]
      ,a.[ASXCode]
      ,[UserID]
      ,[TradingAlertTypeID]
      ,[AlertPrice] as AlertPriceRaw
      ,case when AlertPriceType = 'Price' and [AlertPrice] > 0 then [AlertPrice]
		    when AlertPriceType = 'SMA' and [AlertPrice] = 5 then b.MovingAverage5d * (1 + isnull(Boost, 0)/100.0)
		    when AlertPriceType = 'SMA' and [AlertPrice] = 10 then b.MovingAverage10d * (1 + isnull(Boost, 0)/100.0)
		    when AlertPriceType = 'SMA' and [AlertPrice] = 20 then b.MovingAverage20d * (1 + isnull(Boost, 0)/100.0)
		    when AlertPriceType = 'SMA' and [AlertPrice] = 30 then b.MovingAverage30d * (1 + isnull(Boost, 0)/100.0)
		    when AlertPriceType = 'SMA' and [AlertPrice] = 60 then b.MovingAverage60d * (1 + isnull(Boost, 0)/100.0)
		    when AlertPriceType = 'SMA' and [AlertPrice] = 135 then b.MovingAverage135d * (1 + isnull(Boost, 0)/100.0)
		    when AlertPriceType = 'SMA' and [AlertPrice] = 200 then b.MovingAverage200d * (1 + isnull(Boost, 0)/100.0)
			else null
	   end as AlertPrice
      ,[AlertVolume]
	  ,ActualPrice
	  ,[ActualVolume]
	  ,AlertPriceType
	  ,Boost
      ,a.[CreateDate]
      ,[AlertTriggerDate]
      ,[NotificationSentDate]
FROM [Alert].[TradingAlert] as a
left join Alert.StockStatsHistoryPlusCurrent as b
on a.ASXCode = b.ASXCode
