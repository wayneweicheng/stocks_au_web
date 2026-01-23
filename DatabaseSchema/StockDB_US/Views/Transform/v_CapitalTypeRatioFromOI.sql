-- View: [Transform].[v_CapitalTypeRatioFromOI]




CREATE view [Transform].[v_CapitalTypeRatioFromOI]
as
with outpt as
(
	select 
		*,
		case when CapitalType = 'a. Long In' and [Close] > [PrevClose] and [AggPerc] < [PrevAggPerc] then -2
			 when [CapitalType] ='a. Long In' and [Close] < [PrevClose] and [AggPerc] > [PrevAggPerc] then 2
			 else null
		end as SwingIndicatorLongIn,
		case when CapitalType = 'c. Short In' and [Close] > [PrevClose] and [AggPerc] > [PrevAggPerc] then -2
			 when [CapitalType] ='c. Short In' and [Close] < [PrevClose] and [AggPerc] < [PrevAggPerc] then 2
			 else null
		end as SwingIndicatorShortIn,
		case when CapitalType = 'd. Long out' and [Close] > [PrevClose] and [AggPerc] < [PrevAggPerc] then -1
			 when [CapitalType] ='d. Long out' and [Close] < [PrevClose] and [AggPerc] > [PrevAggPerc] then 1
			 else null
		end as SwingIndicatorLongOut,
		case when CapitalType = 'b. Short out' and [Close] > [PrevClose] and [AggPerc] > [PrevAggPerc] then -1
			 when [CapitalType] ='b. Short out' and [Close] < [PrevClose] and [AggPerc] < [PrevAggPerc] then 1
			 else null
		end as SwingIndicatorShortOut
		--null as SwingIndicatorLongOut,
		--null as SwingIndicatorShortOut
	from
	(
		select 
			*,
			lead([Close]) over (partition by ASXCode, CapitalType order by ObservationDate desc) as PrevClose,
			lead([GEX]) over (partition by ASXCode, CapitalType order by ObservationDate desc) as PrevGEX,
			lead([AggPerc]) over (partition by ASXCode, CapitalType order by ObservationDate desc) as PrevAggPerc
		from
		(
			select a.*, b.[Close] from Transform.CapitalTypeRatioFromOI as a
			left join StockData.v_PriceHistory as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate = b.ObservationDate
		) as b
	) as c
)

select a.*, nullif(b.SwingIndicatorTotal, 0) as SwingIndicatorTotal
from outpt as a
inner join
(
	select ASXCode, ObservationDate, sum(isnull(SwingIndicatorLongIn, 0) + isnull(SwingIndicatorShortIn, 0) + isnull(SwingIndicatorLongOut, 0) + isnull(SwingIndicatorShortOut, 0)) as SwingIndicatorTotal
	from outpt
	group by ASXCode, ObservationDate
) as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate
