-- View: [StockData].[v_PriceHistory]













CREATE view [StockData].[v_PriceHistory]
as
select 
	*, 
	cast(([Close]-PrevClose)*100.0/[PrevClose] as decimal(10, 2)) as TodayChange,
	cast((NextClose-[Close])*100.0/[Close] as decimal(10, 2)) as TomorrowChange,
	cast((Next2Close-[Close])*100.0/[Close] as decimal(10, 2)) as Next2DaysChange,
	cast((Next5Close-[Close])*100.0/[Close] as decimal(10, 2)) as Next5DaysChange,
	case when [Close] > 0 then cast((Next10Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next10DaysChange,
	case when [Close] > 0 then cast((Next20Close-[Close])*100.0/[Close] as decimal(10, 2)) end as Next20DaysChange,
	case when [Close] > 0 then cast(([Close]-[Open])*100.0/[Open] as decimal(10, 2)) end as TodayOpenToCloseChange,
	case when [NextClose] > 0 then cast(([NextClose]-NextOpen)*100.0/[NextOpen] as decimal(10, 2)) end as TomorrowOpenToCloseChange,
	case when [Prev2Close] > 0 then cast(([PrevClose]-Prev2Close)*100.0/[Prev2Close] as decimal(10, 2)) end as YesterdayChange,
	case when [Prev3Close] > 0 then cast(([PrevClose]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Prev2DaysChange,
	case when [Prev3Close] > 0 then cast(([PrevClose]-Prev11Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Prev10DaysChange,
	case when [Prev2Close] > 0 then cast(([Close]-Prev2Close)*100.0/[Prev2Close] as decimal(10, 2)) end as Last2DaysChange,
	case when [Prev3Close] > 0 then cast(([Close]-Prev3Close)*100.0/[Prev3Close] as decimal(10, 2)) end as Last3DaysChange
from
(
	select 
		*, 
		lead([Close]) over (partition by ASXCode order by ObservationDate desc) as PrevClose,
		lead([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Prev2Close,
		lead([Close], 3) over (partition by ASXCode order by ObservationDate desc) as Prev3Close,
		lead([Close], 11) over (partition by ASXCode order by ObservationDate desc) as Prev11Close,
		lag([Open], 1) over (partition by ASXCode order by ObservationDate desc) as NextOpen,
		lag([Close], 1) over (partition by ASXCode order by ObservationDate desc) as NextClose,
		lag([Close], 2) over (partition by ASXCode order by ObservationDate desc) as Next2Close,
		lag([Close], 5) over (partition by ASXCode order by ObservationDate desc) as Next5Close,
		lag([Close], 10) over (partition by ASXCode order by ObservationDate desc) as Next10Close,
		lag([Close], 20) over (partition by ASXCode order by ObservationDate desc) as Next20Close
	from 
	(
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
		union all
		select 
		   'BTC' as [ASXCode]
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
		where ASXCode in ('BTC')
		union all
		select 
		   'EUR/USD' as [ASXCode]
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
		where ASXCode in ('EUR/USD')
		union all
		select 
		   '2YTNOTE' as [ASXCode]
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
		where ASXCode in ('2YTNOTE')
		union all
		select 
		   '10YTNOTE' as [ASXCode]
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
		where ASXCode in ('10YTNOTE')
		union all
		select 
		   'GOLD' as [ASXCode]
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
		where ASXCode in ('GOLD')
		union all
		select 
		   'OIL' as [ASXCode]
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
		where ASXCode in ('OIL')
		union all
		select 
		   'NASDAQ' as [ASXCode]
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
		where ASXCode in ('NASDAQ')
	) as x
) as a
