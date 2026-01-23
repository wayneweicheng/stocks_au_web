-- View: [StockData].[v_PriceHistory]






CREATE view [StockData].[v_PriceHistory]
as
select 
	*, 
	case when [PrevClose] > 0 then cast(([Close]-PrevClose)*100.0/[PrevClose] as decimal(10, 2)) end as TodayChange,
	case when [Close] > 0 then cast((NextClose-[Close])*100.0/[Close] as decimal(10, 2)) end as TomorrowChange,
	case when [Close] > 0 then cast((NextOpen-[Close])*100.0/[Close] as decimal(10, 2)) end as TomorrowOpenChange,
	case when [Close] > 0 then cast((Next2Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next2DaysChange,
	case when [Close] > 0 then cast((Next5Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next5DaysChange,
	case when [Close] > 0 then cast((Next10Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next10DaysChange,
	case when [Prev2Close] > 0 then cast(([PrevClose]-Prev2Close)*100.0/[Prev2Close] as decimal(10, 2)) end as YesterdayChange,
	case when [Prev3Close] > 0 then cast(([PrevClose]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Prev2DaysChange,
	case when [Prev3Close] > 0 then cast(([PrevClose]-Prev11Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Prev10DaysChange,
	case when [Prev2Close] > 0 then cast(([Close]-Prev2Close)*100.0/[Prev2Close] as decimal(10, 2)) end as Last2DaysChange,
	case when [Prev3Close] > 0 then cast(([Close]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Last3DaysChange
from
(
	select 
		*, 
		lead([Low]) over (partition by ASXCode order by ObservationDate desc) as PrevLow,
		lead([High]) over (partition by ASXCode order by ObservationDate desc) as PrevHigh,
		lead([Close]) over (partition by ASXCode order by ObservationDate desc) as PrevClose,
		lag([Open], 1) over (partition by ASXCode order by ObservationDate desc) as NextOpen,
		lag([Low], 1) over (partition by ASXCode order by ObservationDate desc) as NextLow,
		lag([High], 1) over (partition by ASXCode order by ObservationDate desc) as NextHigh,
		lag([Close], 1) over (partition by ASXCode order by ObservationDate desc) as NextClose,
		lead([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Close,
		lead([Close], 3) over (partition by ASXCode order by ObservationDate desc) as Prev3Close,
		lead([Close], 11) over (partition by ASXCode order by ObservationDate desc) as Prev11Close,
		lag([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Next2Close,
		lag([Close], 5) over (partition by ASXCode order by ObservationDate desc) as Next5Close,
		lag([Close], 10) over (partition by ASXCode order by ObservationDate desc) as Next10Close
	from StockData.PriceHistory
) as a
