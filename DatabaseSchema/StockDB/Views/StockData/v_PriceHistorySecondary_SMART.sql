-- View: [StockData].[v_PriceHistorySecondary_SMART]


CREATE view [StockData].[v_PriceHistorySecondary_SMART] with schemabinding
as
select 
	 [ASXCode]
    ,[ObservationDate]
    ,lag([ObservationDate], 1) over (partition by ASXCode order by ObservationDate) as Prev1ObservationDate
    ,lag([ObservationDate], 2) over (partition by ASXCode order by ObservationDate) as Prev2ObservationDate
    ,lag([ObservationDate], 3) over (partition by ASXCode order by ObservationDate) as Prev3ObservationDate
    ,[Close]
    ,[Open]
    ,[Low]
    ,[High]
    ,[Volume]
    ,[Value]
    ,[Trades]
    ,[Exchange]
    ,[CreateDate]
    ,[ModifyDate]
    ,[VWAP]
    ,[AdditionalElements]
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.SMA5') as float) as SMA5
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.SMA10') as float) as SMA10
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.SMA20') as float) as SMA20
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.SMA50') as float) as SMA50
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.SMA100') as float) as SMA100
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.SMA200') as float) as SMA200
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.BBand_Upper') as float) as BBand_Upper
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.BBand_Middle') as float) as BBand_Middle
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.BBand_Lower') as float) as BBand_Lower
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.ATR') as float) as ATR
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.NATR') as float) as NATR
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.TRANGE') as float) as TRANGE
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.RSI6') as float) as RSI6
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.RSI14') as float) as RSI14
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.Stoch_SlowK') as float) as Stoch_SlowK
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.Stoch_SlowD') as float) as Stoch_SlowD
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.MACD_MACD') as float) as MACD_MACD
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.MACD_Signal') as float) as MACD_Signal
	,cast(json_value(replace(a.AdditionalElements, 'NaN', 'null'), '$.MACD_Hist') as float) as MACD_Hist
from StockData.PriceHistorySecondary as a
where 1 = 1
--and (a.AdditionalElements is null or len(a.AdditionalElements) > 0)
and len(a.AdditionalElements) > 0
and Exchange = 'ASX'
