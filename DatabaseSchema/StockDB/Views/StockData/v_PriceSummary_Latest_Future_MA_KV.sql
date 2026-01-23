-- View: [StockData].[v_PriceSummary_Latest_Future_MA_KV]


create view StockData.v_PriceSummary_Latest_Future_MA_KV
as
select
	ASXCode,
	RowNumber,
	'MovingAverage5d' as MAKey,
	MovingAverage5d as MAValue
from Transform.PriceSummaryLatestFutureMA
union all
select
	ASXCode,
	RowNumber,
	'MovingAverage10d' as MAKey,
	MovingAverage10d as MAValue
from Transform.PriceSummaryLatestFutureMA
union all
select
	ASXCode,
	RowNumber,
	'MovingAverage20d' as MAKey,
	MovingAverage20d as MAValue
from Transform.PriceSummaryLatestFutureMA
union all
select
	ASXCode,
	RowNumber,
	'MovingAverage30d' as MAKey,
	MovingAverage30d as MAValue
from Transform.PriceSummaryLatestFutureMA
union all
select
	ASXCode,
	RowNumber,
	'MovingAverage50d' as MAKey,
	MovingAverage50d as MAValue
from Transform.PriceSummaryLatestFutureMA
union all
select
	ASXCode,
	RowNumber,
	'MovingAverage60d' as MAKey,
	MovingAverage60d as MAValue
from Transform.PriceSummaryLatestFutureMA
union all
select
	ASXCode,
	RowNumber,
	'MovingAverage100d' as MAKey,
	MovingAverage100d as MAValue
from Transform.PriceSummaryLatestFutureMA

