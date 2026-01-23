-- Stored procedure: [Report].[usp_Get_Strategy_TopBrokerBuyPrice]



CREATE PROCEDURE [Report].[usp_Get_Strategy_TopBrokerBuyPrice]
@pbitDebug AS BIT = 0,
@pintNumPrevDay as int, 
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_Get_Strategy_TopBrokerBuyPrice.sql
Stored Procedure Name: usp_Get_Strategy_TopBrokerBuyPrice
Overview
-----------------
usp_Get_Strategy_BrokerBuy

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2020-02-22
Author:		WAYNE CHENG
Description: usp_Get_Strategy_BreakoutRetrace
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_TopBrokerBuyPrice'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--begin transaction
		--declare @pintNumPrevDay as int = 3
		
		select @pintNumPrevDay = @pintNumPrevDay -	 1

		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition
		) as x
		where RowNumber = 1

		delete a
		from #TempCashPosition as a
		where datediff(day, AnnDateTime, getdate()) > 105

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempStockNature') is not null
			drop table #TempStockNature

		select a.ASXCode, stuff((
			select ',' + Token
			from StockData.StockNature
			where ASXCode = a.ASXCode
			order by AnnCount desc
			for xml path('')), 1, 1, ''
		) as Nature
		into #TempStockNature
		from StockData.StockNature as a
		group by a.ASXCode

		select 
			'Top Broker Buy Price' as ReportType,			
			format(j.MedianTradeValue, 'N0') as MedianTradeValueWeekly,
			a.ASXCode,
			ObservationStartDate as ObservationStartDate,
			ObservationEndDate as ObservationEndDate,
			b.[Close],
			a.AvgBuyPrice as BrokerBuyPrice,
			a.BrokerCode as BuyBroker,
			a.RowNumber as BuyBrokerRank,
			format(a.NetValue, 'N0') as BuyBrokerNetValue,
			a.MC,
			j.MedianPriceChangePerc,
			b.VWAP, 
			cast((b.[Close] - a.AvgBuyPrice/100.0)*100.0/(a.AvgBuyPrice/100.0) as decimal(10, 2)) as [CloseVsBrokerBuy %]
		from StockData.TopBrokerRecentBuy as a
		inner join 
		(
			select ASXCode, count(distinct BrokerCode) as NumBroker
			from StockData.TopBrokerRecentBuy 
			where NumPrevDay = @pintNumPrevDay
			group by ASXCode
		) as x
		on a.ASXCode = x.ASXCode
		left join StockData.v_PriceSummary as b
		on a.ASXCode = b.ASXCode
		and b.LatestForTheDay = 1
		and b.DateTo is null
		and b.ObservationDate = (select max(ObservationDate) from StockData.v_PriceSummary)
		left join 
		(
			select ASXCode, MedianTradeValue, MedianPriceChangePerc 
			from StockData.MedianTradeValue
		) as j
		on a.ASXCode = j.ASXCode
		left join StockData.StockStatsHistoryPlusCurrent as l
		on a.ASXCode = l.ASXCode
		where 1 = 1	
		--and
		--(case when TrendMovingAverage60d = '' then 'Up' else TrendMovingAverage60d end = 'Up')
		--and 
		--(case when TrendMovingAverage200d = '' then 'Up' else TrendMovingAverage200d end = 'Up')
		and a.AvgBuyPrice/100.0 > 0
		and NumPrevDay = @pintNumPrevDay		
		and (MedianTradeValue > 2000 or BrokerCode = 'ArgSec')
		and b.[Close] > 0
		and j.MedianPriceChangePerc > 2.0
		order by 
			case when a.BrokerCode = 'Macqua' then 10
				 when a.BrokerCode = 'BelPot' then 20
				 when a.BrokerCode = 'ShaSto' then 30
				 when a.BrokerCode = 'PerShn' then 40
				 when a.BrokerCode = 'HarLim' then 50
				 else 999
			end asc,
			a.BrokerCode,
			j.MedianPriceChangePerc desc;

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occured in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN

		--IF @@TRANCOUNT > 0
		--BEGIN
		--	ROLLBACK TRANSACTION
		--END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
