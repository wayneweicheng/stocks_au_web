-- View: [BackTest].[v_Order]


CREATE VIEW [BackTest].[v_Order]
AS
SELECT [OrderID]
      ,a.[ASXCode]
      ,[UserID]
      ,a.[OrderTypeID]
	  ,b.BuySellFlag
	  ,null as [OrderPrice]
	  ,[OrderPrice] as RawOrderPrice
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
	  ,case when len(a.AdditionalSettings) > 0 then cast(JSON_VALUE(a.AdditionalSettings, '$.BarCompletedInMin') as varchar(50)) else null end as AS_BarCompletedInMin
	  -- NEW: Extract BuyConditionType from AdditionalSettings
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.BuyConditionType') else null end as AS_BuyConditionType
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.OptionSymbol') else null end as OptionSymbol
	  ,null as OptionSymbolDetails
	  ,case when len(a.AdditionalSettings) > 0 then JSON_VALUE(a.AdditionalSettings, '$.OptionBuySell') else null end as OptionBuySell
FROM [BackTest].[Order] as a
inner join LookupRef.OrderType as b
on a.OrderTypeID = b.OrderTypeID
where a.OrderPriceType in ('Price') or
	 [Common].[RoundStockPrice](
	   case when a.OrderPriceType in ('Price') then [OrderPrice] + case when b.BuySellFlag = 'B' then 1 else -1 end*isnull(OrderPriceBufferNumberOfTick, 0)*[Common].[GetPriceTick]([OrderPrice])
	   end
	  ) > 0
