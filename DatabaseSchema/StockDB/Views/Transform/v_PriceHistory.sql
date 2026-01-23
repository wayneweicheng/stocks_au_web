-- View: [Transform].[v_PriceHistory]


CREATE view [Transform].[v_PriceHistory]
as
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
      ,[VWAP]
      ,[PrevClose]
      ,[PriceChangeVsPrevClose]
      ,[PriceChangeVsOpen]
      ,[Spread]
      ,[CreateDate]
      ,[ModifyDate]
      ,[TransformDate]
from Transform.PriceHistory
union all
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
      ,[VWAP]
      ,[PrevClose]
      ,null as [PriceChangeVsPrevClose]
      ,null as [PriceChangeVsOpen]
      ,null as [Spread]
      ,DateFrom as [CreateDate]
      ,LastVerifiedDate as [ModifyDate]
      ,null as [TransformDate]
from StockData.v_PriceSummary_Latest as a
where exists
(
	select 1
	from 
	(
		select ASXCode, max(ObservationDate) as ObservationDate
		from Transform.PriceHistory
		group by ASXCode
	) as b
	where a.ASXCode = b.ASXCode
	and a.ObservationDate >  b.ObservationDate
)
