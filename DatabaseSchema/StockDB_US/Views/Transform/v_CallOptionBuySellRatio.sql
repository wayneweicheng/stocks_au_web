-- View: [Transform].[v_CallOptionBuySellRatio]


create view Transform.v_CallOptionBuySellRatio
as
with outpt as
(
	select a.ObservationDate, a.ASXCode, (a.DumbGEX)*1.0/(b.DumbGEX) as CallBuyVsSell
	from [Transform].[SmartDumbCapitalTypeRatio] as a
	inner join [Transform].[SmartDumbCapitalTypeRatio] as b
	on a.ASXCode = b.ASXCode
	and a.ObservationDate = b.ObservationDate
	where a.ObservationDate >= '2023-01-01'
	--and a.ASXCode = 'SPY.US'
	and a.CapitalType = 'a. Long In'
	and b.CapitalType = 'd. Long out'
	group by a.ObservationDate, a.ASXCode, a.SmartGEX, a.DumbGEX, b.SmartGEX, b.DumbGEX
),

outpt2 as
(
	select a.ObservationDate, a.ASXCode, (a.SmartGEX)*1.0/(b.SmartGEX) as CallBuyVsSell
	from [Transform].[SmartDumbCapitalTypeRatio] as a
	inner join [Transform].[SmartDumbCapitalTypeRatio] as b
	on a.ASXCode = b.ASXCode
	and a.ObservationDate = b.ObservationDate
	where a.ObservationDate >= '2023-01-01'
	--and a.ASXCode = 'SPY.US'
	and a.CapitalType = 'a. Long In'
	and b.CapitalType = 'd. Long out'
	group by a.ObservationDate, a.ASXCode, a.SmartGEX, a.DumbGEX, b.SmartGEX, b.DumbGEX
)

select x.ObservationDate, x.ASXCode, x.NormCallBuyVsSell as DumbNormCallBuyVsSell, y.NormCallBuyVsSell as SmartNormCallBuyVsSell
from
(
	select a.*, (CallBuyVsSell - MinCallBuyVsSell)*1.0/(MaxCallBuyVsSell - MinCallBuyVsSell) as NormCallBuyVsSell 
	from outpt as a
	inner join
	(
		select ASXCode, min(CallBuyVsSell) as MinCallBuyVsSell, max(CallBuyVsSell) as MaxCallBuyVsSell
		from outpt
		group by ASXCode
	) as b
	on a.ASXCode = b.ASXCode
) as x
inner join
(
	select a.*, (CallBuyVsSell - MinCallBuyVsSell)*1.0/(MaxCallBuyVsSell - MinCallBuyVsSell) as NormCallBuyVsSell 
	from outpt2 as a
	inner join
	(
		select ASXCode, min(CallBuyVsSell) as MinCallBuyVsSell, max(CallBuyVsSell) as MaxCallBuyVsSell
		from outpt2
		group by ASXCode
	) as b
	on a.ASXCode = b.ASXCode
) as y
on x.ObservationDate = y.ObservationDate
and x.ASXCode = y.ASXCode
--order by x.ObservationDate, y.ASXCode

