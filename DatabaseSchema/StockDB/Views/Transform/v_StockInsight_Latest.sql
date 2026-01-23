-- View: [Transform].[v_StockInsight_Latest]


create view Transform.v_StockInsight_Latest
as
select *
from
(
	select *, row_number() over (partition by ASXCode order by cast(CreateDate as date) desc) as RowNumber
	from [Transform].[StockInsight]
) as a
where RowNumber = 1