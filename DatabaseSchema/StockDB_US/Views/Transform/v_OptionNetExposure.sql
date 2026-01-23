-- View: [Transform].[v_OptionNetExposure]


--select top 100 * from [Transform].[v_OptionNetExposure]

CREATE view [Transform].[v_OptionNetExposure]
as
with exposure as
(
select b.*, a.TotalCallGamma, a.TotalPutGamma, TotalNetGamma
from
(
select 
	ASXCode, [Close], [ObservationDate], sum(CallGamma) as TotalCallGamma, sum(PutGamma) as TotalPutGamma, sum(CallGamma) + sum(PutGamma) as TotalNetGamma,
	case when sum(CallGamma) + sum(PutGamma) > 0 then 'Positive' else 'Negative' end as TotalExposure
from Transform.v_GammaWall
where 1 = 1 
and Strike <= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 1.1 else 1.3 end
and Strike >= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 0.9 else 0.7 end
--and ObservationDate = '2024-08-12'
--and ASXCode = 'SPXW.US'
group by ASXCode, [Close], [ObservationDate]
) as a
inner join
(
select 
	Strike, ASXCode, [Close], [ObservationDate], sum(CallGamma) as CallGamma, sum(PutGamma) as PutGamma, sum(CallGamma) + sum(PutGamma) as NetGamma,
	case when sum(CallGamma) + sum(PutGamma) > 0 then 'Positive' else 'Negative' end as Exposure
from Transform.v_GammaWall
where 1 = 1 
and Strike <= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 1.1 else 1.3 end
and Strike >= [Close]*case when ASXCode in ('SPXW.US', 'QQQ.US', 'SPY.US', 'DIA.US', 'IWM.US', 'TLT.US') then 0.9 else 0.7 end
--and ObservationDate = '2024-08-12'
--and ASXCode = 'SPXW.US'
group by Strike, ASXCode, [Close], [ObservationDate]
) as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate
)

select 
	*,
	[Close] - lead([Close]) over (partition by ASXCode order by ObservationDate desc) as CloseChange,
	[TotalNetGamma] - lead([TotalNetGamma]) over (partition by ASXCode order by ObservationDate desc) as TotalNetGammaChange
from exposure
