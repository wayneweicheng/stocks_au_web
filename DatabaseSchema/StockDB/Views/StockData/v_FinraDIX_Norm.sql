-- View: [StockData].[v_FinraDIX_Norm]




CREATE view [StockData].[v_FinraDIX_Norm]
as
with output as
(
	select 
		 [FinraDIXID]
		,ObservationDate
		,[Symbol]
		,[ShortVolume]
		,[ShortExemptVolume]
		,TotalVolume
		,Bought
		,Sold
		,BuyRatio
		,DPIndex
		,InstBuyPerc
		,lag([InstBuyPerc]) over (partition by Symbol order by ObservationDate asc) as Prev_InstBuyPerc
		,Market
		,[CreateDate]
	from 
	(
		select 
			*, 
			cast(ShortVolume*100.0/TotalVolume as decimal(10, 4)) as InstBuyPerc,
			ShortVolume as Bought,
			TotalVolume-ShortVolume as Sold,
			case when TotalVolume-ShortVolume > 0 then cast(ShortVolume*1.0/(TotalVolume-ShortVolume) as decimal(10, 2)) else null end as BuyRatio, 
			case when TotalVolume > 0 then cast(ShortVolume*100.0/TotalVolume as decimal(10, 1)) else null end DPIndex
		from [StockData].[FinraDIX]
		where TotalVolume > 0
	) as a
	where dateadd(day, -365, getdate()) < ObservationDate
)

select 
	x.*,
	case when MaxInstBuyPerc - MinInstBuyPerc =  0 then null else cast((InstBuyPerc - MinInstBuyPerc)/(MaxInstBuyPerc - MinInstBuyPerc) as decimal(20, 2)) end as NormInstBuyPerc,
	case when StdevInstBuyPerc = 0 then null else cast((InstBuyPerc - AvgInstBuyPerc)/StdevInstBuyPerc as decimal(20, 4)) end as ZScoreInstBuyPerc,
	avg(x.InstBuyPerc) over (partition by x.Symbol order by x.ObservationDate asc rows 4 preceding) as InstBuyPerc_SMA5,
	avg(x.InstBuyPerc) over (partition by x.Symbol order by x.ObservationDate asc rows 9 preceding) as InstBuyPerc_SMA10,
	avg(x.InstBuyPerc) over (partition by x.Symbol order by x.ObservationDate asc rows 19 preceding) as InstBuyPerc_SMA20
from output as x
inner join 
(
	select Symbol, max(InstBuyPerc) as MaxInstBuyPerc, min(InstBuyPerc) as MinInstBuyPerc, avg(InstBuyPerc) as AvgInstBuyPerc, STDEV(InstBuyPerc) as StdevInstBuyPerc
	from output
	group by Symbol
) as y
on x.Symbol = y.Symbol;
