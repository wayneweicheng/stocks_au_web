-- View: [Analysis].[v_PLLRSScannerResults]


create view [Analysis].[v_PLLRSScannerResults]
as
SELECT a.[ASXCode]
      ,a.[ObservationDate]
      ,[OpenPrice]
      ,[ClosePrice]
      ,a.[PrevClose]
      ,[TodayPriceChange]
	  ,b.[Value] as TradeValue
      ,[MeetsCriteria]
      ,[SupportPrice]
      ,[ResistancePrice]
      ,[DistanceToSupportPct]
      ,[NetAggressorFlow]
      ,[AggressorBuyRatio]
      ,[BidAskReloadRatio]
      ,[TotalActiveBuyVolume]
      ,[TotalActiveSellVolume]
      ,[EntryPrice]
      ,[TargetPrice]
      ,[StopPrice]
      ,[PotentialGainPct]
      ,[PotentialLossPct]
      ,[RewardRiskRatio]
      ,[Reasons]
      ,[ScanDateTime]
      ,[CreatedAt]
      ,[UpdatedAt]
FROM [Analysis].[PLLRSScannerResults] as a
left join Transform.PriceHistory24Month as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate


