-- View: [Transform].[v_OptionGexChange]


CREATE view [Transform].[v_OptionGexChange]
as

with output as
(
	select *
	from Transform.OptionGEXChange
	where ObservationDate > dateadd(day, -365, getdate())
)

select 
	x.*,
	AvgGEXDelta,
	NumObs,
	case when MaxGEXDelta - MinGEXDelta > 0 then cast((GEXDelta - MinGEXDelta)*1.0/(MaxGEXDelta - MinGEXDelta) as decimal(20, 4)) end as NormGEXDelta,
	case when StdevGEXDelta != 0 then cast((GEXDelta - AvgGEXDelta)/StdevGEXDelta as decimal(20, 4)) end as ZScoreGEXDelta
from output as x
inner join
(
	select ASXCode, max(GEXDelta) as MaxGEXDelta, min(GEXDelta) as MinGEXDelta, avg(GEXDelta) as AvgGEXDelta, STDEV(GEXDelta) as StdevGEXDelta, count(*) as NumObs
	from output
	group by ASXCode
) as y
on x.ASXCode = y.ASXCode
