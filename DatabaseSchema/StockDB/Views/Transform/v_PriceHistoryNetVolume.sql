-- View: [Transform].[v_PriceHistoryNetVolume]


CREATE view [Transform].[v_PriceHistoryNetVolume]
as
SELECT [PriceHistoryNetVolume]
      ,[ASXCode]
      ,[ObservationDate]
      ,[NetVolume]
      ,[NetValue]
      ,[TotalVolume]
      ,[TotalValue]
      ,[CreateDate]
	  ,avg(NetVolume) over (partition by ASXCode order by ObservationDate asc rows 9 preceding) as AvgNetVolume
	  ,row_number() over (partition by ASXCode order by ObservationDate desc) as ReverseDateSeq
  FROM [Transform].[PriceHistoryNetVolume]
