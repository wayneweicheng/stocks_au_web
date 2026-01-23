-- View: [StockData].[v_DarkPoolIndex]


create view StockData.v_DarkPoolIndex
as
select 
	*,
case when (GEX > Prev1GEX and [Price] < Prev1Price) then 'swing up'
		when (GEX < Prev1GEX and [Price] > Prev1Price) then 'swing down'
end as SwingIndicator
from
(
	select 
		*,
		lead(GEX) over (partition by IndexCode order by ObservationDate desc) as Prev1GEX,
		lead([Dix]) over (partition by IndexCode order by ObservationDate desc) as Prev1Dix,
		lead([Price]) over (partition by IndexCode order by ObservationDate desc) as Prev1Price
	from StockData.DarkPoolIndex
) as x