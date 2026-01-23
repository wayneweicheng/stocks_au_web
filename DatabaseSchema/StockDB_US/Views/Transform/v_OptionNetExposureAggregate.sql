-- View: [Transform].[v_OptionNetExposureAggregate]



CREATE view [Transform].[v_OptionNetExposureAggregate]
as
with exposure as
(
	select 
		*,
		lead([Close]) over (partition by ASXCode order by ObservationDate desc) as Prev1Close,
		lead(TotalNetGamma) over (partition by ASXCode order by ObservationDate desc) as Prev1TotalNetGamma,
		lead(NetGamma) over (partition by ASXCode, Strike order by ObservationDate desc) as Prev1NetGamma,
		NetGamma - lead(NetGamma) over (partition by ASXCode, Strike order by ObservationDate desc) as NetGammaChange
	from [StockDB_US].[Transform].[OptionNetExposureAggregate]
)

select *
from exposure
