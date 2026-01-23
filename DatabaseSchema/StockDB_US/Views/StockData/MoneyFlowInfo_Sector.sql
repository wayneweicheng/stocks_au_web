-- View: [StockData].[MoneyFlowInfo_Sector]

CREATE view StockData.MoneyFlowInfo_Sector
as
select *, 100 - MFRank*100.0/MFTotal as RankScore
from StockData.MoneyFlowInfo
where ASXCode in ('TLT.US', 'GDX.US', 'SPY.US', 'XLK.US', 'XLE.US', 'XBI.US', 'XLC.US', 'XLY.US', 'XLP.US', 'XLV.US', 'XLB.US', 'XLF.US', 'XLU.US', 'XLI.US', 'XLRE.US', 'XOP.US')
and ObservationDate >= '2022-08-30'
--and ASXCode = 'XBI.US'
and MoneyFlowType = 'daily'