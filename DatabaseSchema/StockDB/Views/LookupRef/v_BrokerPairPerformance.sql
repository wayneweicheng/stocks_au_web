-- View: [LookupRef].[v_BrokerPairPerformance]



CREATE view [LookupRef].[v_BrokerPairPerformance]
as
SELECT [BrokerCode1]
      ,[BrokerCode2]
      --,[T2DaysNumObservations]
      --,[T5DaysNumObservations]
      --,[T10DaysNumObservations]
      --,[T20DaysNumObservations]
      --,[T2DaysNumWin]
      --,cast([T2DaysWinRate] as decimal(20, 2)) as [T2DaysWinRate]
      --,cast([AvgT2DaysPerformance] as decimal(20, 2)) as [AvgT2DaysPerformance]
      --,[T5DaysNumWin]
      --,cast([T5DaysWinRate] as decimal(20, 2)) as [T5DaysWinRate]
      --,cast([AvgT5DaysPerformance] as decimal(20, 2)) as [AvgT5DaysPerformance]
      --,[T10DaysNumWin]
      --,cast([T10DaysWinRate] as decimal(20, 2)) as [T10DaysWinRate]
      --,cast([AvgT10DaysPerformance] as decimal(20, 2)) as [AvgT10DaysPerformance]
      --,[T20DaysNumWin]
      --,cast([T20DaysWinRate] as decimal(20, 2)) as [T20DaysWinRate]
      --,cast([AvgT20DaysPerformance] as decimal(20, 2)) as [AvgT20DaysPerformance]
FROM [LookupRef].[BrokerPairPerformance]
union
SELECT 'Belpot' as [BrokerCode1]
      ,'Macqua' as [BrokerCode2]
union
SELECT 'Argsec' as [BrokerCode1]
      ,'Macqua' as [BrokerCode2]


