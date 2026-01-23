-- View: [Transform].[v_OptionGexByPutCall]



CREATE view [Transform].[v_OptionGexByPutCall]
as
select a.*, b.[Close]
from Transform.OptionGEXByPutCall as a
left join (
	select 
		 [ASXCode]
		,[ObservationDate]
		,[Close]
		,[Open]
		,[Low]
		,[High]
		,[Volume]
		,[Value]
		,[Trades]
		,[CreateDate]
		,[ModifyDate]
		,[VWAP]
	from StockData.PriceHistory
	union
	select 
		'SPXW.US' as [ASXCode]
		,[ObservationDate]
		,[Close]
		,[Open]
		,[Low]
		,[High]
		,[Volume]
		,[Value]
		,[Trades]
		,[CreateDate]
		,[ModifyDate]
		,NULL AS [VWAP]
	from StockDB.StockData.PriceHistory
	where ASXCode in ('SPX')
	union all
	select 
		'SPX.US' as [ASXCode]
		,[ObservationDate]
		,[Close]
		,[Open]
		,[Low]
		,[High]
		,[Volume]
		,[Value]
		,[Trades]
		,[CreateDate]
		,[ModifyDate]
		,NULL AS [VWAP]
	from StockDB.StockData.PriceHistory
	where ASXCode in ('SPX')
	union all
	select 
		'_VIX.US' as [ASXCode]
		,[ObservationDate]
		,[Close]
		,[Open]
		,[Low]
		,[High]
		,[Volume]
		,[Value]
		,[Trades]
		,[CreateDate]
		,[ModifyDate]
		,NULL AS [VWAP]
	from StockDB.StockData.PriceHistory
	where ASXCode in ('VIX')
) as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate

