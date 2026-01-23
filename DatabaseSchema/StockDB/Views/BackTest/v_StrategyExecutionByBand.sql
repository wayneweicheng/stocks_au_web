-- View: [BackTest].[v_StrategyExecutionByBand]


CREATE view BackTest.v_StrategyExecutionByBand
as
select 
	ExecutionID,
	PriceBand, 
	count(*) as TotalNumTrade, 
	cast(sum(ProfitLost) as decimal(20, 3)) as TotalProfitLoss,
	cast(sum(ProfitLost)/count(*) as decimal(20, 3)) as AvgProfitPerTrade, 
	sum(case when ProfitLost > 0 then 1 else 0 end) as NumProfitTrade,
	sum(case when ProfitLost < 0 then 1 else 0 end) as NumLossTrade,
	cast(
	case when sum(case when ProfitLost < 0 then 1 else 0 end) = 0 and sum(case when ProfitLost > 0 then 1 else 0 end) = 0 then null
		 else sum(case when ProfitLost > 0 then 1 else 0 end)*100.0/(sum(case when ProfitLost > 0 then 1 else 0 end) + sum(case when ProfitLost < 0 then 1 else 0 end))
	end as decimal(10, 2)) as ProfitTradePerc
from BackTest.v_StrategyExecution
group by ExecutionID, PriceBand
