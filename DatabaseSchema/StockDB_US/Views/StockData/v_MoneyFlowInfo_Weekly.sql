-- View: [StockData].[v_MoneyFlowInfo_Weekly]

create view StockData.v_MoneyFlowInfo_Weekly
as
select *
from
(
	select MoneyFlowInfoID, ASXCode, MoneyFlowType, ObservationDate as WeekStartDate, dateadd(day, 4, ObservationDate) as WeekEndDate, LongShort, Sentiment, MFRank, MFTotal, 
		lead(ObservationDate) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevObservationDate, 
		lead(Sentiment) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevSentiment, 
		lead(MFRank) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as PrevMFRank, 
		lead(ObservationDate, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2ObservationDate, 
		lead(Sentiment, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2Sentiment, 
		lead(MFRank, 2) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev2MFRank, 
		lead(ObservationDate, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3ObservationDate, 
		lead(Sentiment, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3Sentiment, 
		lead(MFRank, 3) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev3MFRank, 
		lead(ObservationDate, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4ObservationDate, 
		lead(Sentiment, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4Sentiment, 
		lead(MFRank, 4) over (partition by ASXCode, MoneyFlowType order by ObservationDate desc) as Prev4MFRank, 
		LastValidateDate 
	from [StockData].[v_MoneyFlowInfo]
	where 1 = 1
	and MoneyFlowType = 'Weekly'
) as a
