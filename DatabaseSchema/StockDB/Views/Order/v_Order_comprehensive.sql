-- View: [Order].[v_Order_comprehensive]





create view [Order].[v_Order_comprehensive]
as
SELECT [OrderID]
      ,a.[ASXCode]
      ,[UserID]
      ,a.[OrderTypeID]
	  ,b.BuySellFlag
	  ,[Common].[RoundStockPrice](
	   case when a.OrderPriceType in ('Price') then [OrderPrice] + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick]([OrderPrice])
		    when a.OrderPriceType in ('SMA') and a.OrderPrice = 3 then c.MovingAverage3d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage3d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 5 then c.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage5d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 10 then c.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage10d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 20 then c.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage20d)
			when a.OrderPriceType in ('SMAWK') and a.OrderPrice = 5 then d.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](d.MovingAverage5d)
			when a.OrderPriceType in ('SMAWK') and a.OrderPrice = 10 then d.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](d.MovingAverage10d)
			when a.OrderPriceType in ('SMAWK') and a.OrderPrice = 20 then d.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](d.MovingAverage20d)
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
	  ,a.IsDisabled
	  ,a.AdditionalSettings
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.TriggerPrice') as numeric(20, 4)) else null end as AS_TriggerPrice
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.TotalVolume') as int) else null end as AS_TotalVolume
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.Entry1Price') as decimal(20, 4)) else null end as AS_Entry1Price
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.Entry2Price') as decimal(20, 4)) else null end as AS_Entry2Price
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.StopLossPrice') as decimal(20, 4)) else null end as AS_StopLossPrice
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.ExitStrategy') else null end as AS_ExitStrategy
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.Exit1Price') as decimal(20, 4)) else null end as AS_Exit1Price
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.Exit2Price') as decimal(20, 4)) else null end as AS_Exit2Price
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.BarCompletedInMin') else null end as AS_BarCompletedInMin
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.OptionSymbol') else null end as OptionSymbol
	  ,null as OptionSymbolDetails
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.OptionBuySell') else null end as OptionBuySell
FROM [Order].[Order] as a
inner join LookupRef.OrderType as b
on a.OrderTypeID = b.OrderTypeID
left join Alert.StockStatsHistoryPlusCurrent as c
on a.ASXCode = c.ASXCode
left join StockData.StockStatsHistoryPlusWeeklyCurrent as d
on a.ASXCode = d.ASXCode
--left join 
--(
--	select ASXCode, OptionSymbol, Strike, PorC, ExpiryDate, Expiry, ASXCode + '|' + Expiry + '|' + PorC + '|' + cast(Strike as varchar(20)) as OptionSymbolDetails
--	from StockDB_US.StockData.v_OptionDelayedQuote_V2_Latest 
--	where ASXCode in ('SPY.US', 'QQQ.US', 'NVDA.US', 'TSLA.US', 'IWM.US', 'DIA.US', 'TLT.US', 'GDX.US', 'GLD.US')
--) as e
--on e.ASXCode = a.ASXCode
--and e.OptionSymbol = case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.OptionSymbol') else null end
where c.ASXCode is null or 
	 d.ASXCode is null or
	 a.OrderPriceType in ('Price') or
	 [Common].[RoundStockPrice](
	   case when a.OrderPriceType in ('Price') then [OrderPrice] + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick]([OrderPrice])
		    when a.OrderPriceType in ('SMA') and a.OrderPrice = 3 then c.MovingAverage3d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage3d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 5 then c.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage5d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 10 then c.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage10d)
			when a.OrderPriceType in ('SMA') and a.OrderPrice = 20 then c.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](c.MovingAverage20d)
			when a.OrderPriceType in ('SMAWK') and a.OrderPrice = 5 then d.MovingAverage5d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](d.MovingAverage5d)
			when a.OrderPriceType in ('SMAWK') and a.OrderPrice = 10 then d.MovingAverage10d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](d.MovingAverage10d)
			when a.OrderPriceType in ('SMAWK') and a.OrderPrice = 20 then d.MovingAverage20d + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick](d.MovingAverage20d)

	   end
	  ) > 0
