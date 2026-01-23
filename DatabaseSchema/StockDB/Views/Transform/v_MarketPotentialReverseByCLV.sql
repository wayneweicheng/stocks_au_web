-- View: [Transform].[v_MarketPotentialReverseByCLV]



create view [Transform].[v_MarketPotentialReverseByCLV]
as
select 
	a.ObservationDate,
	a.XAOChange,
	a.PrevXAOChange,
	b.CLV,
	b.PrevCLV,
	case when abs(CLV) >= 0.3 then 1 else 0 end IsSignificant,
	case when (a.XAOChange > a.PrevXAOChange and b.CLV < b.PrevCLV) or (a.XAOChange < a.PrevXAOChange and b.CLV > b.PrevCLV) then 1 else 0 end as ReverseFromPrev
from
(
	select ObservationDate, XAOChange, lag(XAOChange) over (partition by MarketCap order by ObservationDate asc) as PrevXAOChange
	from Transform.MarketCLVTrend
	where MarketCap in (
	'g. 10B+'
	)
) as a
inner join
(
	select ObservationDate, CLV, lag(CLV) over (partition by MarketCap order by ObservationDate asc) as PrevCLV
	from Transform.MarketCLVTrend
	where MarketCap in (
	'g. 10B+'
	)
) as b
on a.ObservationDate = b.ObservationDate
and 
(
	(a.XAOChange < 0 and b.CLV > 0)
	or
	(a.XAOChange > 0 and b.CLV < 0)
)
