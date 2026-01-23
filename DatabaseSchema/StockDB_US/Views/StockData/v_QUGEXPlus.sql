-- View: [StockData].[v_QUGEXPlus]





CREATE view [StockData].[v_QUGEXPlus]
as
select 
	*,
	case when (GEX > Prev1GEX and [ClosePrice] < Prev1Close) then 'swing up'
		 when (GEX < Prev1GEX and [ClosePrice] > Prev1Close) then 'swing down'
		 --else case when abs(case when Prev1GEX = 0 then null else cast((GEX-Prev1GEX)*100.0/Prev1GEX as decimal(10, 2)) end) < 8 then 'Possible swing' end
	end as SwingIndicator,
	case when (GEX > Prev1GEX and [ClosePrice] < Prev2Close) then 'Potential swing up'
		 when (GEX < Prev1GEX and [ClosePrice] > Prev2Close) then 'Potential swing down'
	end as PotentialSwingIndicator,
	case when Prev1GEX = 0 then null else cast((GEX-Prev1GEX)*100.0/Prev1GEX as decimal(10, 2)) end as GEXChange,
	case when Prev1Close = 0 then null else cast(([ClosePrice]-Prev1Close)*100.0/Prev1Close as decimal(10, 2)) end as ClosePriceChange
from
(
	select 
		a.*, 
		lag(GEX) over (partition by ASXCode, TimeFrame order by ObservationDate asc) as Prev1GEX,
		lag(ClosePrice) over (partition by ASXCode, TimeFrame order by ObservationDate asc) as Prev1Close,
		lead([ClosePrice], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Close
	from StockData.TotalGex as a
	where 1 = 1 
) as x
where 1 = 1
