-- View: [Transform].[SmartDumbCapitalTypeRatio_Norm]


create view [Transform].[SmartDumbCapitalTypeRatio_Norm]
as
select 
	a.*,
	cast((DumbAggPerc-b.MinDumbAggPerc)*1.0/(b.MaxDumbAggPerc - b.MinDumbAggPerc) as decimal(10, 2)) as NormDumbAggPerc,
	cast((SmartAggPerc-c.MinSmartAggPerc)*1.0/(c.MaxSmartAggPerc - c.MinSmartAggPerc) as decimal(10, 2)) as NormSmartAggPerc
from [Transform].[SmartDumbCapitalTypeRatio] as a
inner join
(
	select ASXCode, CapitalType, max(DumbAggPerc) as MaxDumbAggPerc, min(DumbAggPerc) as MinDumbAggPerc
	from [Transform].[SmartDumbCapitalTypeRatio] 
	group by ASXCode, CapitalType
) as b
on a.ASXCode = b.ASXCode
and a.CapitalType = b.CapitalType
inner join
(
	select ASXCode, CapitalType, max(SmartAggPerc) as MaxSmartAggPerc, min(SmartAggPerc) as MinSmartAggPerc
	from [Transform].[SmartDumbCapitalTypeRatio] 
	group by ASXCode, CapitalType
) as c
on a.ASXCode = c.ASXCode
and a.CapitalType = c.CapitalType