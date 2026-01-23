-- View: [StockData].[v_PriceSummary_Latest_Plus]


create view [StockData].[v_PriceSummary_Latest_Plus]
as
select 
	*
    ,lag([ObservationDate], 1) over (partition by ASXCode order by ObservationDate) as Prev1ObservationDate
    ,lag([ObservationDate], 2) over (partition by ASXCode order by ObservationDate) as Prev2ObservationDate
    ,lag([ObservationDate], 3) over (partition by ASXCode order by ObservationDate) as Prev3ObservationDate
from StockData.v_PriceSummary_Latest