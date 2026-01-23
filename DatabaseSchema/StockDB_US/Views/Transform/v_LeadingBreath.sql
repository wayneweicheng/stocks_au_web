-- View: [Transform].[v_LeadingBreath]


CREATE view [Transform].[v_LeadingBreath]
as
with output1 as
(
	select 
		*,
		--case when TodayValueChange > TodayChange*case when TodayChange > 0 then 1.10 else 0.90 end then 1
		--	 when TodayValueChange < TodayChange*case when TodayChange > 0 then 1.10 else 0.90 end then 0
		--	 else null
		--end as BreathUp
		TodayValueChange - TodayChange as BreathUp
	from Transform.LeadingBreath
),

output2 as
(
	select 
		max(BreathUp) as MaxBreathUp, min(BreathUp) as MinBreathUp, avg(BreathUp) as AvgBreathUp, STDEV(BreathUp) as StdevBreathUp
	from output1
)

select 
	a.*,
	case when MaxBreathUp - MinBreathUp =  0 then null else cast((BreathUp - MinBreathUp)/(MaxBreathUp - MinBreathUp) as decimal(20, 2)) end as NormBreathUp,
	case when StdevBreathUp = 0 then null else cast((BreathUp - AvgBreathUp)/StdevBreathUp as decimal(20, 4)) end as ZScoreBreathUp
from output1 as a
inner join output2 as b
on 1 = 1

