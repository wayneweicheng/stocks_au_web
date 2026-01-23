-- View: [StockData].[v_ASXShortSale]






CREATE view [StockData].[v_ASXShortSale]
as
with 
cte_data as
(
	select 
		*, 
		format(ShareSales, 'N0') as PrettyShortVolume,
		format(Volume, 'N0') as PrettyVolume,
		format(Value, 'N0') as PrettyValue,
		cast(case when y.ShortPerc_SMA20 > 0 then (y.ShortPerc - y.ShortPerc_SMA20)*100.0/y.ShortPerc_SMA20 end as decimal(10, 2)) as VarianceToSMA20
	from
	(
		select 
			*, 
			cast(avg(ShortPerc) over (partition by x.ASXCode order by x.ObservationDate asc rows 20 preceding) as decimal(10, 2)) as ShortPerc_SMA20
		from
		(
			select 
				a.*, 
				cast(ShareSales*100.0/b.Volume as decimal(10, 2)) as ShortPerc, 	
				b.[Close], 
				b.[Volume], 
				b.Value, 
				cast(b.[Value]/b.[Volume] as decimal(20, 4)) as VWAP
			from StockData.ShortSale as a
			left join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
			where 1 = 1
			and isnull(b.Volume, 9999) > 0
			and a.ObservationDate > dateadd(day, -365, getdate())
		) as x
	) as y
),
MinMax as
(
	select ASXCode, min(ShortPerc) as MinShortPerc, max(ShortPerc) as MaxShortPerc, avg(ShortPerc) as AvgShortPerc, STDEV(ShortPerc) as StdDevShortPerc, min(ShareSales) as MinShareSales, max(ShareSales) as MaxShareSales, avg(ShareSales) AvgShareSales, STDEV(ShareSales) as StdDevShareSales 
	from cte_data
	group by ASXCode
)

select 
	a.*, 
	case when b.MaxShortPerc - b.MinShortPerc != 0 then cast((a.ShortPerc - b.MinShortPerc)/(b.MaxShortPerc - b.MinShortPerc) as decimal(20, 2)) end as NormShortPerc,
	case when b.StdDevShortPerc != 0 then cast((a.ShortPerc - b.AvgShortPerc)/b.StdDevShortPerc as decimal(20, 4)) end as ZScoreShortPerc,
	case when b.MaxShareSales - b.MinShareSales != 0 then cast((a.ShareSales - b.MinShareSales)*1.0/(b.MaxShareSales - b.MinShareSales) as decimal(20, 2)) end as NormShortVolume,
	case when b.StdDevShareSales != 0 then cast((a.ShareSales - b.AvgShareSales)/b.StdDevShareSales as decimal(20, 4)) end as ZScoreShortVolume
from cte_data as a
inner join MinMax as b
on a.ASXCode = b.ASXCode;


