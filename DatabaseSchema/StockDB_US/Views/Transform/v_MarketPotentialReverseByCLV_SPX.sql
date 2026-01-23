-- View: [Transform].[v_MarketPotentialReverseByCLV_SPX]







CREATE view [Transform].[v_MarketPotentialReverseByCLV_SPX]
as
select 
	a.ObservationDate,
	a.SPXChange,
	a.PrevSPXChange,
	b.CLV,
	b.PrevCLV,
	case when abs(b.CLV) >= 0.3 then 1 else 0 end IsSignificant,
	case when (a.SPXChange > a.PrevSPXChange and b.CLV < b.PrevCLV) or (a.SPXChange < a.PrevSPXChange and b.CLV > b.PrevCLV) then 1 else 0 end as ReverseFromPrev,
	case when (a.SPXChange < 0 and b.CLV > 0) or (a.SPXChange > 0 and (b.CLV < 0 or (b.CLV < 0.4 and c.CLV < 0.15))) then 1 else 0 end as PotentialReversed,
	case when a.SPXChange < 0 and b.CLV > 0 and b.CLV > c.CLV then 'Swing Up' 
		 when a.SPXChange > 0 and b.CLV < 0 and b.CLV < c.CLV then 'Swing Down' 
	end as SwingIndicator
from
(
	select ObservationDate, SPXChange, lag(SPXChange) over (partition by MarketCap order by ObservationDate asc) as PrevSPXChange
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
inner join
(
	select ObservationDate, CLV, lag(CLV) over (partition by MarketCap order by ObservationDate asc) as PrevCLV
	from Transform.MarketCLVTrend
	where MarketCap in (
	'g. 10B+'
	)
) as c
on a.ObservationDate = c.ObservationDate

--and 
--(
--	(a.SPXChange < 0 and b.CLV > 0)
--	or
--	(a.SPXChange > 0 and b.CLV < 0)
--)
