-- View: [StockData].[v_RORO_Norm]




CREATE view [StockData].[v_RORO_Norm]
as
with output as
(
	select 
		'SPX' as Symbol,
		xlk.[ObservationDate], 
		xlk.[Close]/xlu.[Close] as RORO_XLKXLU,
		xly.[Close]/xlp.[Close] as RORO_XLYXLP,
		(xlk.[Close]/xlu.[Close]) * (xly.[Close]/xlp.[Close]) as RORO, 
		spx.[Close] as SPX
	from
	(
		select ObservationDate, [Close]
		from StockData.v_PriceHistory
		where ASXCode = 'XLK.US'
	) as xlk
	inner join 
	(
		select ObservationDate, [Close]
		from StockData.v_PriceHistory
		where ASXCode = 'XLU.US'
	) as xlu
	on xlk.ObservationDate = xlu.ObservationDate
	inner join
	(
		select ObservationDate, [Close]
		from StockData.v_PriceHistory
		where ASXCode = 'XLY.US'
	) as xly
	on xlk.ObservationDate = xly.ObservationDate
	inner join 
	(
		select ObservationDate, [Close]
		from StockData.v_PriceHistory
		where ASXCode = 'XLP.US'
	) as xlp
	on xlk.ObservationDate = xlp.ObservationDate
	inner join 
	(
		select ObservationDate, [Close]
		from StockDB.StockData.v_PriceHistory
		where ASXCode = 'SPX'
	) as spx
	on xlk.ObservationDate = spx.ObservationDate
),

output2 as
(
	select 
		x.*,
		case when MaxRORO - MinRORO =  0 then null else cast((RORO - MinRORO)/(MaxRORO - MinRORO) as decimal(20, 2)) end as NormRORO,
		case when StdevRORO = 0 then null else cast((RORO - AvgRORO)/StdevRORO as decimal(20, 4)) end as ZScoreRORO,
		case when MaxSPX - MinSPX =  0 then null else cast((SPX - MinSPX)/(MaxSPX - MinSPX) as decimal(20, 2)) end as NormSPX,
		case when StdevSPX = 0 then null else cast((SPX - AvgSPX)/StdevSPX as decimal(20, 4)) end as ZScoreSPX
	from output as x
	inner join 
	(
		select 
			Symbol, 
			max(RORO) as MaxRORO, min(RORO) as MinRORO, avg(RORO) as AvgRORO, STDEV(RORO) as StdevRORO,
			max(SPX) as MaxSPX, min(SPX) as MinSPX, avg(SPX) as AvgSPX, STDEV(SPX) as StdevSPX
		from output
		group by Symbol
	) as y
	on x.Symbol = y.Symbol
),

output3 as
(
	select 
		*,
		lead(RORO) over (partition by Symbol order by ObservationDate desc) as PrevRORO,
		lead(SPX) over (partition by Symbol order by ObservationDate desc) as PrevSPX
	from output2
),

output4 as
(
	select 
		*,
		case when PrevRORO < RORO and PrevSPX > SPX then 1 
			 when PrevRORO > RORO and PrevSPX < SPX then 0
		end as ROROSwing		 
	from output3
)

select * from output4;
