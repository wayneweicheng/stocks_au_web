-- View: [StockData].[v_PriceSummary_Latest_Future_MA]





CREATE view [StockData].[v_PriceSmmary_Latest_Future_MA]
as
select 
	*, 
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 4 preceding) as MovingAverage5d,
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 9 preceding) as MovingAverage10d,
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 19 preceding) as MovingAverage20d,
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 29 preceding) as MovingAverage30d,
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 49 preceding) as MovingAverage50d,
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 59 preceding) as MovingAverage60d,
	avg([Close]) over (partition by ASXCode order by ObservationDate asc rows 99 preceding) as MovingAverage100d,
	avg([Volume]) over (partition by ASXCode order by ObservationDate asc rows 49 preceding) as MovingAverage50dVol,
	row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber
from
(
select 
	ASXCode,
	Common.DateAddBusinessDay(1, ObservationDate) as ObservationDate,
	[Close],
	[Volume]
from [StockData].[v_PriceSummary_Latest_Today] with(nolock)
union all
select 
	ASXCode,
	ObservationDate,
	[Close],
	[Volume]
from [StockData].[v_PriceSummary_Latest] with(nolock)
) as x
