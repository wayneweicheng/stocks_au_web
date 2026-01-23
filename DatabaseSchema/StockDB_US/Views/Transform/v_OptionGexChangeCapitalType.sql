-- View: [Transform].[v_OptionGexChangeCapitalType]







CREATE view [Transform].[v_OptionGexChangeCapitalType]
as

with output as
(
	select 
	   [ObservationDate]
      ,[ASXCode]
	  ,[GEXDelta] as RawGEXDelta
      ,abs([GEXDelta]) as [GEXDelta]
	  ,sum([GEXDelta]) OVER (partition by ASXCode, CapitalType ORDER BY ObservationDate) AS CumulativeDelta
      ,[CapitalType]
      ,[Close]
      ,[VWAP]
	from Transform.OptionGEXChangeCapitalType
	where 1 = 1
	--and ObservationDate > dateadd(day, -365*40, getdate())
	and CapitalType is not null
),

output_sum as
(
	select 
		ASXCode, 
		ObservationDate, 
		sum(abs(GEXDelta)) as TotalGEXDelta, 
		case when sum(abs(GEXDelta)) = 0 then null else sum(case when CapitalType = 'BC' then abs(GEXDelta) else 0 end)*100.0/sum(abs(GEXDelta)) end as BuyCallPerc,
		case when sum(abs(GEXDelta)) = 0 then null else sum(case when CapitalType = 'BP' then abs(GEXDelta) else 0 end)*100.0/sum(abs(GEXDelta)) end as BuyPutPerc
	from Transform.OptionGEXChangeCapitalType
	where 1 = 1
	--and ObservationDate > dateadd(day, -365*4, getdate())
	and CapitalType is not null
	group by ASXCode, ObservationDate
),

output_norm as
(
	select 
		x.*,
		cast(case when z.TotalGEXDelta = 0 then 0 else abs(x.GEXDelta)*100.0/z.TotalGEXDelta end as decimal(10, 2)) as GEXDeltaPerc,
		AvgGEXDelta,
		NumObs,
		case when MaxGEXDelta - MinGEXDelta > 0 then cast((GEXDelta - MinGEXDelta)*1.0/(MaxGEXDelta - MinGEXDelta) as decimal(20, 4)) end as NormGEXDelta,
		case when StdevGEXDelta != 0 then cast((GEXDelta - AvgGEXDelta)/StdevGEXDelta as decimal(20, 4)) end as ZScoreGEXDelta,
		case when BuyCallPerc > 0 then BuyPutPerc*1.0/BuyCallPerc else null end as PutCallRatio
	from output as x
	inner join
	(
		select ASXCode, CapitalType, max(GEXDelta) as MaxGEXDelta, min(GEXDelta) as MinGEXDelta, avg(GEXDelta) as AvgGEXDelta, STDEV(GEXDelta) as StdevGEXDelta, count(*) as NumObs
		from output
		group by ASXCode, CapitalType
	) as y
	on x.ASXCode = y.ASXCode
	and x.CapitalType = y.CapitalType
	inner join output_sum as z
	on x.ASXCode = z.ASXCode
	and x.ObservationDate = z.ObservationDate
)

select 
	*, 
	lead(ZScoreGEXDelta) over (partition by CapitalType, ASXCode order by ObservationDate desc) as Prev1ZScoreGEXDelta,
	lead(NormGEXDelta) over (partition by CapitalType, ASXCode order by ObservationDate desc) as Prev1NormGEXDelta,
	lead(GEXDeltaPerc) over (partition by CapitalType, ASXCode order by ObservationDate desc) as Prev1GEXDeltaPerc
from output_norm

