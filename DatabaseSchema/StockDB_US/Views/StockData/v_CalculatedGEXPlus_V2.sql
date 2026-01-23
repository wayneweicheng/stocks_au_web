-- View: [StockData].[v_CalculatedGEXPlus_V2]









	CREATE view [StockData].[v_CalculatedGEXPlus_V2]
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
	case when Prev1GEX = 0 then null else cast((GEX-Prev1GEX)*100.0/Prev1GEX as decimal(10, 2)) end as GEXChange,
	case when Prev1Close = 0 then null else cast(([Close]-Prev1Close)*100.0/Prev1Close as decimal(10, 2)) end as ClosePriceChange
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
		from StockData.v_CalculatedGEX_V2 as a
		where a.[Close] is not null
	) as x
	where not exists
	(
		select 1
		from Transform.OptionGEXChange
		where ASXCode = x.ASXCode
		and ObservationDate = X.ObservationDate
		AND GEXDeltaAdjusted = 0
	)
	
