-- View: [Transform].[v_OptionDexChangeCapitalType]












CREATE view [Transform].[v_OptionDexChangeCapitalType]
as

with output as
(
	select 
	   [ObservationDate]
      ,[ASXCode]
	  ,[DEXDelta] as RawDEXDelta
      ,abs([DEXDelta]) as [DEXDelta]
	  ,sum([DEXDelta]) OVER (partition by ASXCode, CapitalType ORDER BY ObservationDate) AS CumulativeDelta
      ,[CapitalType]
      ,[Close]
      ,[VWAP]
	from [Transform].[OptionDexChangeCapitalType]
	where 1 = 1
	--and ObservationDate > dateadd(day, -365*40, getdate())
	and CapitalType is not null
),

output_sum as
(
	select 
		ASXCode, 
		ObservationDate, 
		sum(abs(DEXDelta)) as TotalDEXDelta, 
		case when sum(abs(DEXDelta)) = 0 then null else sum(case when CapitalType = 'BC' then abs(DEXDelta) else 0 end)*100.0/sum(abs(DEXDelta)) end as BuyCallPerc,
		case when sum(abs(DEXDelta)) = 0 then null else sum(case when CapitalType = 'BP' then abs(DEXDelta) else 0 end)*100.0/sum(abs(DEXDelta)) end as BuyPutPerc
	from [Transform].[OptionDexChangeCapitalType]
	where 1 = 1
	--and ObservationDate > dateadd(day, -365*4, getdate())
	and CapitalType is not null
	group by ASXCode, ObservationDate
),

output_norm as
(
	select 
		x.*,
		cast(case when z.TotalDEXDelta = 0 then 0 else abs(x.DEXDelta)*100.0/z.TotalDEXDelta end as decimal(10, 2)) as DEXDeltaPerc,
		AvgDEXDelta,
		NumObs,
		case when MaxDEXDelta - MinDEXDelta > 0 then cast((DEXDelta - MinDEXDelta)*1.0/(MaxDEXDelta - MinDEXDelta) as decimal(20, 4)) end as NormDEXDelta,
		case when StdevDEXDelta != 0 then cast((DEXDelta - AvgDEXDelta)/StdevDEXDelta as decimal(20, 4)) end as ZScoreDEXDelta,
		case when BuyCallPerc > 0 then BuyPutPerc*1.0/BuyCallPerc else null end as PutCallRatio
	from output as x
	inner join
	(
		select ASXCode, CapitalType, max(DEXDelta) as MaxDEXDelta, min(DEXDelta) as MinDEXDelta, avg(DEXDelta) as AvgDEXDelta, STDEV(DEXDelta) as StdevDEXDelta, count(*) as NumObs
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
	lead(ZScoreDEXDelta) over (partition by CapitalType, ASXCode order by ObservationDate desc) as Prev1ZScoreDEXDelta,
	lead(NormDEXDelta) over (partition by CapitalType, ASXCode order by ObservationDate desc) as Prev1NormDEXDelta,
	lead(DEXDeltaPerc) over (partition by CapitalType, ASXCode order by ObservationDate desc) as Prev1DEXDeltaPerc
from output_norm

