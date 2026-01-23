-- View: [StockData].[v_Top20HolderLatest]

CREATE view [StockData].[v_Top20HolderLatest]
as
select 
	a.[ASXCode],
	a.[NumberOfSecurity],
	a.[HolderName],
	a.[CurrDate],
	a.[PrevDate],
	a.[CurrRank],
	a.[PrevRank],
	a.[CurrShares],
	a.[PrevShares],
	case when c.SharesOnIssue > 0 then cast(a.[CurrShares]*100.0/c.SharesOnIssue as decimal(10, 2)) else null end as [CurrSharesPerc],
	case when c.SharesOnIssue > 0 then cast(a.[PrevShares]*100.0/c.SharesOnIssue as decimal(10, 2)) else null end as [PrevSharesPerc],
	cast(case when a.[PrevShares] > 0 then (a.[CurrShares] - a.[PrevShares])*100.0/a.[PrevShares] else null end as decimal(20, 2)) as [ShareDiffPerc]
from StockData.Top20Holder as a
inner join
(
	select ASXCode, max(CurrDate) as MaxCurrDate
	from StockData.Top20Holder
	group by ASXCode
) as b
on a.ASXCode = b.ASXCode
and a.CurrDate = b.MaxCurrDate
left join StockData.CompanyInfo as c
on a.ASXCode = c.ASXCode
