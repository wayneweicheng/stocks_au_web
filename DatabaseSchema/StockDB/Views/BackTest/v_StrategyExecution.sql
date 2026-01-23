-- View: [BackTest].[v_StrategyExecution]


--select top 1000 * from BackTest.v_StrategyExecution

CREATE view BackTest.v_StrategyExecution
as
SELECT [StrategyExecutionID]
      ,[ExecutionID]
      ,[ASXCode]
      ,[ObservationDate]
	  ,case when a.EntryPrice between 0 and 0.01 then '0 - 0.01'
				when a.EntryPrice between 0.01 and 0.02 then '0.01 - 0.02'
				when a.EntryPrice between 0.02 and 0.03 then '0.02 - 0.03'
				when a.EntryPrice between 0.03 and 0.05 then '0.03 - 0.05'
				when a.EntryPrice between 0.05 and 0.07 then '0.05 - 0.07'
				when a.EntryPrice between 0.07 and 0.10 then '0.07 - 0.10'
				when a.EntryPrice between 0.10 and 0.12 then '0.10 - 0.12'
				when a.EntryPrice between 0.12 and 0.15 then '0.12 - 0.15'
				when a.EntryPrice between 0.15 and 0.17 then '0.15 - 0.17'
				when a.EntryPrice between 0.17 and 0.20 then '0.17 - 0.20'
				when a.EntryPrice between 0.20 and 0.25 then '0.20 - 0.25'
				when a.EntryPrice between 0.25 and 0.30 then '0.25 - 0.30'
				when a.EntryPrice between 0.30 and 0.40 then '0.30 - 0.40'
				when a.EntryPrice between 0.40 and 0.50 then '0.40 - 0.50'
				when a.EntryPrice between 0.50 and 0.75 then '0.50 - 0.75'
				when a.EntryPrice between 0.75 and 1.00 then '0.75 - 1.00'
				when a.EntryPrice between 1.00 and 1.50 then '1.00 - 1.50'
				when a.EntryPrice between 1.50 and 2.00 then '1.50 - 2.00'
				when a.EntryPrice between 2.00 and 2.50 then '2.00 - 2.50'
				when a.EntryPrice between 2.50 and 3.50 then '2.50 - 3.50'
				when a.EntryPrice between 3.50 and 5.00 then '3.50 - 5.00'
				when a.EntryPrice between 5.00 and 7.50 then '5.00 - 7.50'
				when a.EntryPrice between 7.50 and 10.00 then '7.50 - 10.00'
				when a.EntryPrice between 10.00 and 15.00 then '10 - 15'
				when a.EntryPrice between 15 and 20 then '15 - 20'
				else '20 +'
	   end as PriceBand
      ,[EntryPrice]
      ,[ActualBuyPrice]
      ,[ActualBuyDateTime]
      ,[ExitPrice]
      ,[StopLossPrice]
      ,[ActualSellPrice]
      ,[ActualSellDateTime]
      ,[Volume]
      ,[BuyTotalValue]
      ,[SellTotalValue]
      ,[BrokerageFee]
      ,[ActualHoldDays]
      ,[ProfitLost]
      ,[CreateDate]
      ,[ObservationDayPriceIncreasePerc]
  FROM [BackTest].[StrategyExecution] as a
