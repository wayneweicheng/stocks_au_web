-- View: [StockData].[v_CalculatedGEXPlus]





	CREATE view [StockData].[v_CalculatedGEXPlus]
	as
	select 
		*,
		format(Prev1GEX, 'N0') as FormattedPrev1GEX,
	case when (GEX > Prev1GEX and [Close] < Prev1Close) then 'swing up'
		 when (GEX < Prev1GEX and [Close] > Prev1Close) then 'swing down'
	end as SwingIndicator,
	case when (GEX > Prev1GEX and [Close] < Prev2Close) then 'Potential swing up'
		 when (GEX < Prev1GEX and [Close] > Prev2Close) then 'Potential swing down'
	end as PotentialSwingIndicator,
	cast((GEX-Prev1GEX)*100.0/Prev1GEX as decimal(10, 2)) as GEXChange,
	cast(([Close]-Prev1Close)*100.0/Prev1Close as decimal(10, 2)) as ClosePriceChange
	from
	(
		select 
			a.ASXCode,
			a.ObservationDate,
			a.NoOfOption,
			a.GEX,
			a.FormattedGEX,
			a.[Close],
			lead(GEX) over (partition by ASXCode order by ObservationDate desc) as Prev1GEX,
			lead([Close]) over (partition by ASXCode order by ObservationDate desc) as Prev1Close,
			lead([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Close
		from StockData.v_CalculatedGEX as a
		where [Close] is not null
	) as x
	
