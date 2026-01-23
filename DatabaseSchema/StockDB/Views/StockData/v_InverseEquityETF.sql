-- View: [StockData].[v_InverseEquityETF]


CREATE view StockData.v_InverseEquityETF
as
select 
	 [InverseEquityETFID]
	,[EquityCode]
	,[SharesOutstandingInM]
	,lag([SharesOutstandingInM]) over (partition by EquityCode order by NAVDate asc) as Prev_SharesOutstandingInM
	,([SharesOutstandingInM]-lag([SharesOutstandingInM]) over (partition by EquityCode order by NAVDate asc))*TotalNAV as InflowValueInM
	,[TotalNetAssetsInM]
	,[TotalNAV]
	,[NAVDate]
	,[AverageVolumeInM]
	,[CreateDate]
from [StockData].[InverseEquityETF]
