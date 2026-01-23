-- View: [StockData].[v_MoneyFlowInfo_Daily]



CREATE view [StockData].[v_MoneyFlowInfo_Daily]
as
select *
from
(
	select MoneyFlowInfoID, ASXCode, MoneyFlowType, ObservationDate, LongShort, Sentiment, MFRank, NearScore, TotalScore,
	    avg([MFRank]) over (partition by ASXCode, [MoneyFlowType] order by ObservationDate asc rows 4 preceding) as MovingAverage5dMFRank,
	    cast(avg([MFRank]) over (partition by ASXCode, [MoneyFlowType] order by ObservationDate asc rows 4 preceding)*1.0/[MFRank] as decimal(10, 2)) as MF5dRankRate,
	    avg([MFRank]) over (partition by ASXCode, [MoneyFlowType] order by ObservationDate asc rows 19 preceding) as MovingAverage20dMFRank,
	    cast(avg([MFRank]) over (partition by ASXCode, [MoneyFlowType] order by ObservationDate asc rows 19 preceding)*1.0/[MFRank] as decimal(10, 2)) as MF20dRankRate,
		MFTotal, 
		lead(ObservationDate) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevObservationDate, 
		lead(Sentiment) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevSentiment, 
		lead(MFRank) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevMFRank, 
		lead(TotalScore) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevTotalScore, 
		lead(ObservationDate, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2ObservationDate, 
		lead(Sentiment, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2Sentiment, 
		lead(MFRank, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2MFRank, 
		lead(TotalScore, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2TotalScore,
		lead(ObservationDate, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3ObservationDate, 
		lead(Sentiment, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3Sentiment, 
		lead(MFRank, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3MFRank, 
		lead(TotalScore, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3TotalScore,
		lead(ObservationDate, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4ObservationDate, 
		lead(Sentiment, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4Sentiment, 
		lead(MFRank, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4MFRank, 
		lead(TotalScore, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4TotalScore,
		LastValidateDate 
	from [StockData].[v_MoneyFlowInfo]
	where 1 = 1
	and MoneyFlowType = 'Daily'
) as a
