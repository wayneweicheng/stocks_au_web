-- View: [Transform].[v_PutOptionBuySellRatio]


create view Transform.v_PutOptionBuySellRatio
as
with outpt as
(
	select a.ObservationDate, a.ASXCode, (a.DumbGEX)*1.0/(b.DumbGEX) as PutBuyVsSell
	from [Transform].[SmartDumbCapitalTypeRatio] as a
	inner join [Transform].[SmartDumbCapitalTypeRatio] as b
	on a.ASXCode = b.ASXCode
	and a.ObservationDate = b.ObservationDate
	where a.ObservationDate >= '2023-01-01'
	and a.ASXCode = 'SPY.US'
	and a.CapitalType = 'c. Short In'
	and b.CapitalType = 'b. Short out'
	group by a.ObservationDate, a.ASXCode, a.SmartGEX, a.DumbGEX, b.SmartGEX, b.DumbGEX
),

outpt2 as
(
	select a.ObservationDate, a.ASXCode, (a.SmartGEX)*1.0/(b.SmartGEX) as PutBuyVsSell
	from [Transform].[SmartDumbCapitalTypeRatio] as a
	inner join [Transform].[SmartDumbCapitalTypeRatio] as b
	on a.ASXCode = b.ASXCode
	and a.ObservationDate = b.ObservationDate
	where a.ObservationDate >= '2023-01-01'
	and a.ASXCode = 'SPY.US'
	and a.CapitalType = 'c. Short In'
	and b.CapitalType = 'b. Short out'
	group by a.ObservationDate, a.ASXCode, a.SmartGEX, a.DumbGEX, b.SmartGEX, b.DumbGEX
)

select x.ObservationDate, x.ASXCode, x.NormPutBuyVsSell as DumbNormPutBuyVsSell, y.NormPutBuyVsSell as SmartNormPutBuyVsSell
from
(
	select a.*, (PutBuyVsSell - MinPutBuyVsSell)*1.0/(MaxPutBuyVsSell - MinPutBuyVsSell) as NormPutBuyVsSell 
	from outpt as a
	inner join
	(
		select ASXCode, min(PutBuyVsSell) as MinPutBuyVsSell, max(PutBuyVsSell) as MaxPutBuyVsSell
		from outpt
		group by ASXCode
	) as b
	on a.ASXCode = b.ASXCode
) as x
inner join
(
	select a.*, (PutBuyVsSell - MinPutBuyVsSell)*1.0/(MaxPutBuyVsSell - MinPutBuyVsSell) as NormPutBuyVsSell 
	from outpt2 as a
	inner join
	(
		select ASXCode, min(PutBuyVsSell) as MinPutBuyVsSell, max(PutBuyVsSell) as MaxPutBuyVsSell
		from outpt2
		group by ASXCode
	) as b
	on a.ASXCode = b.ASXCode
) as y
on x.ObservationDate = y.ObservationDate
and x.ASXCode = y.ASXCode
--order by x.ObservationDate, y.ASXCode

