-- View: [Transform].[v_SPX_SPXW_OptionMoneyFlow]


create view Transform.v_SPX_SPXW_OptionMoneyFlow
as
select *
from
(
	select 
		a.ObservationDate as ObservationDate, 
		a.SwingIndicator as SwingIndicator
	from
	(
		select SwingIndicator, ObservationDate	
		from [Transform].[v_SPXOptionMoneyFlow]
		where SwingIndicator in ('Swing Up', 'Swing Down')
	) as a
	left join
	(
		select SwingIndicator, ObservationDate	
		from [Transform].[v_SPXWOptionMoneyFlow]
		where SwingIndicator in ('Swing Up', 'Swing Down')
	) as b
	on a.ObservationDate = b.ObservationDate
	where a.SwingIndicator = isnull(b.SwingIndicator, a.SwingIndicator)
	union
	select 
		a.ObservationDate as ObservationDate, 
		a.SwingIndicator as SwingIndicator
	from
	(
		select SwingIndicator, ObservationDate	
		from [Transform].[v_SPXWOptionMoneyFlow]
		where SwingIndicator in ('Swing Up', 'Swing Down')
	) as a
	left join
	(
		select SwingIndicator, ObservationDate	
		from [Transform].[v_SPXOptionMoneyFlow]
		where SwingIndicator in ('Swing Up', 'Swing Down')
	) as b
	on a.ObservationDate = b.ObservationDate
	where a.SwingIndicator = isnull(b.SwingIndicator, a.SwingIndicator)
) as x