-- View: [StockData].[v_MoneyFlowInfo]






CREATE view [StockData].[v_MoneyFlowInfo]
as
SELECT [MoneyFlowInfoID]
      ,a.[ASXCode]
      ,[MoneyFlowType]
      ,a.[ObservationDate]
      ,[LongShort]
      ,[Sentiment]
      ,[MFRank]
	  ,avg([MFRank]) over (partition by a.ASXCode, [MoneyFlowType] order by a.ObservationDate asc rows 20 preceding) as MovingAverage20dMFRank
	  ,cast(avg(100 - cast(MFRank*100.0/MFTotal as decimal(10, 2))) over (partition by a.ASXCode, [MoneyFlowType] order by a.ObservationDate asc rows 9 preceding) as decimal(10, 2)) as MFRankPercMovingAverage10d
      ,[MFTotal]
      ,[NearScore]
      ,[TotalScore]
	  ,format(TotalScore - NearScore, 'N0') as FormatLongTermScore
	  ,format(NearScore, 'N0') as FormatShortTermScore
	  ,format(TotalScore, 'N0') as FormatTotalScore
	  ,100 - cast(MFRank*100.0/MFTotal as decimal(10, 2)) as MFRankPerc
      ,[LastValidateDate]
      ,[CreateDateTime]
	  ,b.[Close]
  FROM [StockData].[MoneyFlowInfo] as a
  left join StockData.PriceHistory as b
  on a.ASXCode = b.ASXCode
  and a.ObservationDate = b.ObservationDate

