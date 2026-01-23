-- View: [Transform].[v_PutSellingPerc]



CREATE view [Transform].[v_PutSellingPerc]
as
select 
	a.*,
	case when MaxPutSellPerc - MinPutSellPerc = 0 then null else cast((PutSellPerc - MinPutSellPerc)/(MaxPutSellPerc - MinPutSellPerc) as decimal(20, 2)) end as NormPutSellPerc,
	case when StdevPutSellPerc = 0 then 0 else cast((PutSellPerc - AvgPutSellPerc)/StdevPutSellPerc as decimal(20, 4)) end as ZScorePutSellPerc
from Transform.PutSellingPerc as a
inner join 
(
	select ASXCode, max(PutSellPerc) as MaxPutSellPerc, min(PutSellPerc) as MinPutSellPerc, avg(PutSellPerc) as AvgPutSellPerc, STDEV(PutSellPerc) as StdevPutSellPerc
	from Transform.PutSellingPerc
	group by ASXCode
) as y
on a.ASXCode = y.ASXCode


