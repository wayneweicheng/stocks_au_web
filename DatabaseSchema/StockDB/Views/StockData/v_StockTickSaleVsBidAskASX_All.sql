-- View: [StockData].[v_StockTickSaleVsBidAskASX_All]



CREATE view [StockData].[v_StockTickSaleVsBidAskASX_All]
as
select 
	   --[CourseOfSaleSecondaryID]
       [SaleDateTime]
      ,[ObservationDate]
      ,[Price]
      ,[Quantity]
      ,[SaleValue]
      ,[FormatedSaleValue]
      ,[ASXCode]
      ,[Exchange]
      ,[SpecialCondition]
      ,[ActBuySellInd]
      ,[DerivedBuySellInd]
      ,[DerivedInstitute]
      --,[StockBidAskID]
      ,[PriceBid]
      ,[SizeBid]
      ,[PriceAsk]
      ,[SizeAsk]
      ,[DateFrom]
      ,[DateTo]
from Transform.StockTickSaleVsBidAskASX
union
select --[CourseOfSaleSecondaryID]
       [SaleDateTime]
      ,[ObservationDate]
      ,[Price]
      ,[Quantity]
      ,[SaleValue]
      ,[FormatedSaleValue]
      ,[ASXCode]
      ,[Exchange]
      ,[SpecialCondition]
      ,[ActBuySellInd]
      ,[DerivedBuySellInd]
      ,[DerivedInstitute]
      --,[StockBidAskID]
      ,[PriceBid]
      ,[SizeBid]
      ,[PriceAsk]
      ,[SizeAsk]
      ,[DateFrom]
      ,[DateTo]
from
(
	select 
		a.CourseOfSaleSecondaryID,
		a.SaleDateTime,
		a.ObservationDate,
		a.Price,
		a.Quantity,
		cast(a.Price*a.Quantity as int) as SaleValue,
		format(cast(a.Price*a.Quantity as int), 'N0') as FormatedSaleValue,
		a.ASXCode, 
		a.Exchange,
		a.SpecialCondition,
		a.ActBuySellInd,
		case when b.PriceBid < b.PrevPriceBid then 'S'
			 when b.PriceAsk > b.PrevPriceAsk then 'B'
			 else case when a.Price <= b.PriceBid then 'S' 
					   when a.Price >= b.PriceAsk then 'B' 
					   else null
				  end
		end as DerivedBuySellInd,
		a.DerivedInstitute,
		b.StockBidAskASXID,
		b.PriceBid,
		b.SizeBid,
		b.PriceAsk,
		b.SizeAsk,
		b.DateFrom,
		b.DateTo
	from StockData.v_CourseOfSaleSecondaryASX_By_Min as a with(nolock)
	inner join [StockData].[v_StockBidAskASX] as b with(nolock)
	on a.SaleDateTime > b.DateFrom and a.SaleDateTime <= b.DateTo
	and a.ASXCode = b.ASXCode
	and a.ObservationDate = b.ObservationDate
	where 1 = 1
	union all
	select 
		null as CourseOfSaleSecondaryID,
		b.ObservationTime as SaleDateTime,
		b.ObservationDate,
		null as Price,
		null as Quantity,
		null as SaleValue,
		null as FormatedSaleValue,
		b.ASXCode as ASXCode, 
		null as Exchange,
		null as SpecialCondition,
		null as ActBuySellInd,
		null as DerivedBuySellInd,
		null as DerivedInstitute,
		b.StockBidAskASXID,
		b.PriceBid,
		b.SizeBid,
		b.PriceAsk,
		b.SizeAsk,
		b.DateFrom,
		b.DateTo
	from [StockData].[v_StockBidAskASX] as b with(nolock)
	left join StockData.v_CourseOfSaleSecondaryASX_By_Min as a with(nolock)
	on a.SaleDateTime > b.DateFrom and a.SaleDateTime <= b.DateTo
	and a.ASXCode = b.ASXCode
	and a.ObservationDate = b.ObservationDate
	where a.ASXCode is null
) as x
