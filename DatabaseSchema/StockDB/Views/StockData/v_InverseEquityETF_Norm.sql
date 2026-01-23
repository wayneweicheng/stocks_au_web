-- View: [StockData].[v_InverseEquityETF_Norm]




CREATE view [StockData].[v_InverseEquityETF_Norm]
as
with output as
(
	select 
		 [InverseEquityETFID]
		,[EquityCode]
		,[SharesOutstandingInM]
		,lag([SharesOutstandingInM], 1) over (partition by EquityCode order by NAVDate asc) as Prev_SharesOutstandingInM
		,([SharesOutstandingInM]-lag([SharesOutstandingInM]) over (partition by EquityCode order by NAVDate asc))*TotalNAV as InflowValueInM
		,[TotalNetAssetsInM]
		,[TotalNAV]
		,[NAVDate]
		,[AverageVolumeInM]
		,[CreateDate]
	from [StockData].[InverseEquityETF]
	where dateadd(day, -365*2, getdate()) < NAVDate
),

output_rank AS (
  SELECT *, ROW_NUMBER() OVER (partition by EquityCode ORDER BY NAVDate asc) AS RowNum
  FROM output
),

rolling_sum as
(
	SELECT 
		cte.EquityCode, 
		cte.NAVDate, 
		SUM(cte.InflowValueInM) OVER (partition by EquityCode ORDER BY cte.RowNum ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS RollingSum3D,
		SUM(cte.InflowValueInM) OVER (partition by EquityCode ORDER BY cte.RowNum ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS RollingSum10D,
		SUM(cte.InflowValueInM) OVER (partition by EquityCode ORDER BY cte.RowNum ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS RollingSum20D,
		SUM(cte.InflowValueInM) OVER (partition by EquityCode ORDER BY cte.RowNum ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS RollingSum30D
	FROM output_rank as cte
)

select 
	x.*,
	z.RollingSum3D,
	z.RollingSum10D,
	z.RollingSum20D,
	z.RollingSum30D,
	lag(InflowValueInM, 1) over (partition by x.EquityCode order by x.NAVDate asc) as Prev1_InflowValueInM,
	lag(InflowValueInM, 2) over (partition by x.EquityCode order by x.NAVDate asc) as Prev2_InflowValueInM,
	InflowValueInM + lag(InflowValueInM, 1) over (partition by x.EquityCode order by x.NAVDate asc) + lag(InflowValueInM, 2) over (partition by x.EquityCode order by x.NAVDate asc) as InflowValueInM_3DCumulative,
	cast((InflowValueInM - MinInflowValueInM)/(MaxInflowValueInM - MinInflowValueInM) as decimal(20, 2)) as NormInflowValueInM,
	cast((InflowValueInM - AvgInflowValueInM)/StdevInflowValueInM as decimal(20, 4)) as ZScoreInflowValueInM
from output as x
inner join 
(
	select EquityCode, max(InflowValueInM) as MaxInflowValueInM, min(InflowValueInM) as MinInflowValueInM, avg(InflowValueInM) as AvgInflowValueInM, STDEV(InflowValueInM) as StdevInflowValueInM 
	from output
	group by EquityCode
) as y
on x.EquityCode = y.EquityCode
left join rolling_sum as z
on x.EquityCode = z.EquityCode
and x.NAVDate = z.NAVDate
