-- View: [Transform].[v_MarketPotentialReverseByCLV_NASDAQ]





CREATE view [Transform].[v_MarketPotentialReverseByCLV_NASDAQ]
as
select 
	a.ObservationDate,
	a.NASDAQChange,
	a.PrevNASDAQChange,
	b.CLV,
	b.PrevCLV,
	case when abs(CLV) >= 0.3 then 1 else 0 end IsSignificant,
	case when (a.NASDAQChange > a.PrevNASDAQChange and b.CLV < b.PrevCLV) or (a.NASDAQChange < a.PrevNASDAQChange and b.CLV > b.PrevCLV) then 1 else 0 end as ReverseFromPrev,
	case when (a.NASDAQChange < 0 and b.CLV > 0) or (a.NASDAQChange > 0 and b.CLV < 0) then 1 else 0 end as PotentialReversed
from
(
	select ObservationDate, NASDAQChange, lag(NASDAQChange) over (partition by MarketCap order by ObservationDate asc) as PrevNASDAQChange
	from Transform.MarketCLVTrend
	where MarketCap in (
	'h. 300B+'
	--'g. 10B+'
	)
) as a
inner join
(
	select ObservationDate, CLV, lag(CLV) over (partition by MarketCap order by ObservationDate asc) as PrevCLV
	from Transform.MarketCLVTrend
	where MarketCap in (
	'h. 300B+'
	--'g. 10B+'
	)
) as b
on a.ObservationDate = b.ObservationDate
