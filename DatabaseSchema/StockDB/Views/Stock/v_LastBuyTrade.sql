-- View: [Stock].[v_LastBuyTrade]



CREATE view [Stock].[v_LastBuyTrade]
as
select
	   [TradeID]
      ,[ASXCode]
      ,[TradeDateTime]
      ,[TradeType]
      ,[Price]
      ,[Volume]
      ,[TotalValue]
      ,[BrokerageFee]
      ,[SellStrategyID]
      ,[UserID]
      ,[Comment]
      ,[CreateDate]
      ,[StopLossPrice]
	  ,[ExitPrice]
from
(
	select 
		   [TradeID]
		  ,[ASXCode]
		  ,[TradeDateTime]
		  ,[TradeType]
		  ,[Price]
		  ,[Volume]
		  ,[TotalValue]
		  ,[BrokerageFee]
		  ,[SellStrategyID]
		  ,[UserID]
		  ,[Comment]
		  ,[CreateDate]
		  ,[StopLossPrice]
		  ,[ExitPrice]
		  ,row_number() over (partition by UserID, ASXCode order by TradeDateTime desc, CreateDate desc) as RowNumber 
	from Stock.Trade as a
	where TradeType = 1
) as x
where x.RowNumber = 1
