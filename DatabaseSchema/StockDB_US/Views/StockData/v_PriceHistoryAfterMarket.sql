-- View: [StockData].[v_PriceHistoryAfterMarket]








CREATE view [StockData].[v_PriceHistoryAfterMarket]
as
select 
	*, 
	cast(([Close]-PrevClose)*100.0/[PrevClose] as decimal(10, 2)) as TodayChange,
	cast((NextClose-[Close])*100.0/[Close] as decimal(10, 2)) as TomorrowChange,
	cast((Next2Close-[Close])*100.0/[Close] as decimal(10, 2)) as Next2DaysChange,
	cast((Next5Close-[Close])*100.0/[Close] as decimal(10, 2)) as Next5DaysChange,
	case when [Close] > 0 then cast(([Close]-[Open])*100.0/[Open] as decimal(10, 2)) end as TodayOpenToCloseChange,
	case when [NextClose] > 0 then cast(([NextClose]-NextOpen)*100.0/[NextOpen] as decimal(10, 2)) end as TomorrowOpenToCloseChange
from
(
	select 
		*, 
		lead([Close]) over (partition by ASXCode order by ObservationDate desc) as PrevClose,
		lag([Open], 1) over (partition by ASXCode order by ObservationDate desc) as NextOpen,
		lag([Close], 1) over (partition by ASXCode order by ObservationDate desc) as NextClose,
		lag([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Next2Close,
		lag([Close], 5) over (partition by ASXCode order by ObservationDate desc) as Next5Close
	from StockData.PriceHistoryAfterMarket
) as a
