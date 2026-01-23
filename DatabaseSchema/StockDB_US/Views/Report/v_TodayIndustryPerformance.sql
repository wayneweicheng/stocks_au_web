-- View: [Report].[v_TodayIndustryPerformance]



create view Report.v_TodayIndustryPerformance
as
select 
	a.IndustryGroup, 
	a.IndustrySubGroup, 
	cast(sum(case when a.PriceChange > 1 then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceUpPerc,
	cast(sum(case when a.PriceChange < -1 then 1 else 0 end)*100.0/count(*) as decimal(10, 2)) as PriceDownPerc,
	sum(cast(a.[Value]/1000000.0 as decimal(20, 1))) as TotalValueInM,
	count(*) as NoObservations
from (
	select 
		a.ASXCode, 
		b.IndustryGroup, 
		b.IndustrySubGroup, 
		(a.[Close] - a.PrevClose)*100.0/a.PrevClose as PriceChange, 
		a.[Value]
	from StockData.v_PriceSummary as a
	inner join StockData.CompanyInfo as b
	on a.ASXCode = b.ASXCode
	where ObservationDate = cast(getdate() as date)
	and a.DateTo is null
	and a.LatestForTheDay = 1
	and a.PrevClose > 0
) as a
where a.PriceChange > 1 or a.PriceChange < -1
group by 
	a.IndustryGroup, 
	a.IndustrySubGroup
having count(*) >= 3
