-- View: [Order].[v_Order]





CREATE view [Order].[v_Order]
as
SELECT [OrderID]
      ,a.[ASXCode]
      ,[UserID]
      ,a.[OrderTypeID]
	  ,b.BuySellFlag
	  ,[Common].[RoundStockPrice](
	   case when a.OrderPriceType in ('Price') then [OrderPrice] + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick]([OrderPrice])
		    when a.OrderPriceType in ('SMA') and a.OrderPrice = 5 then c.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage5d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 10 then c.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage10d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 20 then c.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage20d)
	   end
	  ) as [OrderPrice]
	  ,[OrderPrice] as RawOrderPrice
   --   ,case when a.OrderPriceType in ('Price') then [OrderPrice] + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick]([OrderPrice])
		 --   when a.OrderPriceType in ('SMA') and a.OrderPrice = 5 then c.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage5d)
			--when a.OrderPriceType in ('SMA') and a.OrderPrice = 10 then c.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage10d)
			--when a.OrderPriceType in ('SMA') and a.OrderPrice = 20 then c.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage20d)
	  -- end as [OrderPrice]
      ,[VolumeGt]
      ,[OrderVolume]
      ,[ValidUntil]
      ,a.[CreateDate]
      ,[OrderTriggerDate]
      ,[OrderProcessDate]
      ,[OrderPlaceDate]
      ,[TradeAccountName]
      ,[OrderPriceType]
      ,[OrderPriceBufferNumberOfTick]
      ,[OrderValue]
	  ,ActualOrderPrice
FROM [Order].[Order] as a
inner join LookupRef.OrderType as b
on a.OrderTypeID = b.OrderTypeID
left join Alert.StockStatsHistoryPlusCurrent as c
on a.ASXCode = c.ASXCode
where c.ASXCode is null or 
	 [Common].[RoundStockPrice](
	   case when a.OrderPriceType in ('Price') then [OrderPrice] + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick]([OrderPrice])
		    when a.OrderPriceType in ('SMA') and a.OrderPrice = 5 then c.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage5d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 10 then c.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage10d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 20 then c.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage20d)
	   end
	  ) > 0
