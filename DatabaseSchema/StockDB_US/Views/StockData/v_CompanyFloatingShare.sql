-- View: [StockData].[v_CompanyFloatingShare]


CREATE view [StockData].[v_CompanyFloatingShare]
as
select 
	ASXCode, 
	FloatingShares, 
	FloatingSharesPerc,
	cast(case when FloatingSharesPerc > 0 then FloatingShares*100.0/FloatingSharesPerc else null end as decimal(10, 2)) as SharesIssued
from
(
	select 
		a.ASXCode, 
		cast((a.SharesOnIssue - b.MajorHolderShares)/1000000.0 as decimal(20, 2)) as FloatingShares, 
		cast((a.SharesOnIssue - b.MajorHolderShares)*100.0/a.SharesOnIssue as decimal(10, 2)) as FloatingSharesPerc
	from StockData.CompanyInfo as a
	inner join
	(
		select ASXCode, sum(CurrShares) as MajorHolderShares
		from StockData.v_Top20HolderLatest
		where CurrRank <= 5
		group by ASXCode
	) as b
	on a.ASXCode = b.ASXCode
	where a.SharesOnIssue - b.MajorHolderShares > 0
) as a
