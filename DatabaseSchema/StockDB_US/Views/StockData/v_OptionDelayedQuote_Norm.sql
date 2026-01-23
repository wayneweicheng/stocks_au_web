-- View: [StockData].[v_OptionDelayedQuote_Norm]




create view [StockData].[v_OptionDelayedQuote_Norm]
as

with output1 as
(
	select
		  *
	from StockData.OptionDelayedQuote
),

output2 as
(
	select 
		OptionSymbol,
		max(Volume) as MaxVolume, min(Volume) as MinVolume, avg(Volume) as AvgVolume, STDEV(Volume) as StdevVolume
	from output1 
	group by OptionSymbol
),

output3 as 
(
	select 
		a.*,
		case when MaxVolume - MinVolume =  0 then null else cast((Volume - MinVolume)/(MaxVolume - MinVolume) as decimal(20, 2)) end as NormVolume,
		case when StdevVolume = 0 then null else cast((Volume - AvgVolume)/StdevVolume as decimal(20, 4)) end as ZScoreVolume
	from output1 as a
	inner join output2 as b
	on a.OptionSymbol = b.OptionSymbol
)

select * from output3
