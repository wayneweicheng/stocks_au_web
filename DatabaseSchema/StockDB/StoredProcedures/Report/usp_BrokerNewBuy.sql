-- Stored procedure: [Report].[usp_BrokerNewBuy]


CREATE PROCEDURE [Report].[usp_BrokerNewBuy]
@pbitDebug AS BIT = 0,
@pvchBrokerCode as varchar(20) = null,
@pintLookupNumDay as int = 5,
@pbitASXCodeOnly as bit = 0,
@pintNumPrevDay as int = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_SelectPriceReverse.sql
Stored Procedure Name: usp_SelectPriceReverse
Overview
-----------------
usp_SelectPriceReverse

Input Parameters
----------------
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
Date:		2018-08-22
Author:		WAYNE CHENG
Description: Initial Version
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CloseVsBrokerBuy'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Working'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pintLookupNumDay as int = 5
		--declare @pintNumPrevDay as int = 4
		--Code goes here 		
		
		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate)
		from StockData.BrokerReport
		where ObservationDate not in
		(
			select ObservationDate
			from StockData.BrokerReport
			where dateadd(day, -10, getdate()) < ObservationDate 
			group by ObservationDate
			having count(*) < 12000
		)

		select @dtMaxDate = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, @dtMaxDate) as date)

		declare @dtStartFrom as date = cast(Common.DateAddBusinessDay(-1 * @pintLookupNumDay, @dtMaxDate) as date)

		if object_id(N'Tempdb.dbo.#TempBRAggregate') is not null
			drop table #TempBRAggregate

		select ObservationDate, ASXCode, BrokerCode, sum(NetValue) as NetValue, avg(BuyPrice) as BuyPrice
		into #TempBRAggregate
		from StockData.BrokerReport
		where ObservationDate >= @dtStartFrom
		and ObservationDate <= @dtMaxDate
		group by ObservationDate, ASXCode, BrokerCode
		
		if object_id(N'Tempdb.dbo.#TempBRAggregateRank') is not null
			drop table #TempBRAggregateRank

		select *, row_number() over (partition by ASXCode, ObservationDate order by NetValue desc) as BuyRank
		into #TempBRAggregateRank
		from #TempBRAggregate

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
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempBRAggregateMax') is not null
			drop table #TempBRAggregateMax

		select *
		into #TempBRAggregateMax
		from #TempBRAggregate as x
		where ObservationDate = (select max(ObservationDate) from #TempBRAggregate)

		if object_id(N'Tempdb.dbo.#TempBrokerReportList') is not null
			drop table #TempBrokerReportList

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateMax as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportList
		from #TempBRAggregateMax as x
		
		if object_id(N'Tempdb.dbo.#TempBrokerReportListNeg') is not null
			drop table #TempBrokerReportListNeg

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateMax as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNeg
		from #TempBRAggregateMax as x

		declare @vchBrokerCode as varchar(20) = @pvchBrokerCode

		if @pbitASXCodeOnly = 0
		begin
			select 
				a.ObservationDate,
				a.BrokerCode,
				a.ASXCode,
				format(a.NetValue, 'N0') as NetValue,
				a.BuyPrice,
				a.BuyRank,
				ttsu.FriendlyNameList,
				b.MC, 
				b.CashPosition, 
				m.BrokerCode as ObservationDateTopBuyBroker,
				n.BrokerCode as ObservationDateTopSellBroker,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker,
				format(h.MedianTradeValue, 'N0') as MedianTradeValueWeekly,
				h.MedianPriceChangePerc
			from #TempBRAggregateRank as a
			left join 
			(
				select ASXCode, MedianTradeValue, MedianPriceChangePerc
				from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join [Transform].[BrokerReportList] as m
			on a.ASXCode = m.ASXCode
			and m.LookBackNoDays = 0
			and m.ObservationDate = cast(getdate() as date)
			and m.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n
			on a.ASXCode = n.ASXCode
			and n.LookBackNoDays = 0
			and n.ObservationDate = cast(getdate() as date)
			and n.NetBuySell = 'S'
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(getdate() as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(getdate() as date)
			and n2.NetBuySell = 'S'
			left join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where a.ASXCode is not null
			and a.NetValue > 30000
			and a.ObservationDate = (select max(ObservationDate) from #TempBRAggregateRank)
			and 
			(
				a.BrokerCode = @vchBrokerCode 
				or
				(@vchBrokerCode is null and a.BrokerCode in ('BelPot', 'ArgSec', 'AscSec', 'FinExe', 'FinClrSrv', 'Macqua', 'MorgFn', 'OrdMin', 'EurHar', 'ShaSto', 'EurSec', 'UBSAus'))
			)
			and BuyRank <= 2
			and not exists
			(
				select 1
				from #TempBRAggregateRank
				where ASXCode = a.ASXCode
				and BrokerCode = a.BrokerCode
				and ObservationDate < (select max(ObservationDate) from #TempBRAggregateRank)
				and BuyRank <= 5
			)
			and h.MedianPriceChangePerc > 2
			order by 
				case when a.BrokerCode = 'Macqua' then 10
					 when a.BrokerCode = 'BelPot' then 20
					 when a.BrokerCode = 'UBSAus' then 30
					 when a.BrokerCode = 'FinClrSrv' then 40
					 when a.BrokerCode = 'EurHar' then 50
					 else 999
				end asc,
				a.BrokerCode,
				h.MedianPriceChangePerc desc,
				BuyRank, 
				NetValue desc
		end
		else
		begin
			if object_id(N'Tempdb.dbo.#TempOutputBrokerNewBuy') is not null
				drop table #TempOutputBrokerNewBuy

			select 
				identity(int, 1, 1) as DisplayOrder,
				a.ObservationDate,
				a.BrokerCode,
				a.ASXCode,
				format(a.NetValue, 'N0') as NetValue,
				a.BuyPrice,
				a.BuyRank,
				b.MC, 
				b.CashPosition, 
				i.BrokerCode as TopBuyBroker,
				j.BrokerCode as TopSellBroker,
				format(h.MedianTradeValue, 'N0') as MedianTradeValueWeekly,
				h.MedianPriceChangePerc
			into #TempOutputBrokerNewBuy
			from #TempBRAggregateRank as a
			left join 
			(
				select ASXCode, MedianTradeValue, MedianPriceChangePerc
				from StockData.MedianTradeValue
			) as h
			on a.ASXCode = h.ASXCode
			left join #TempBrokerReportList as i
			on a.ASXCode = i.ASXCode
			left join #TempBrokerReportListNeg as j
			on a.ASXCode = j.ASXCode
			left join #TempCashVsMC as b
			on a.ASXCode = b.ASXCode
			where a.ASXCode is not null
			and a.NetValue > 30000
			and ObservationDate = (select max(ObservationDate) from #TempBRAggregateRank)
			and 
			(
				a.BrokerCode = @vchBrokerCode 
				or
				(@vchBrokerCode is null and a.BrokerCode in ('BelPot', 'ArgSec', 'AscSec', 'FinExe', 'FinClrSrv', 'Macqua', 'MorgFn', 'OrdMin', 'EurHar', 'ShaSto', 'EurSec', 'UBSAus'))
			)
			and BuyRank <= 2
			and not exists
			(
				select 1
				from #TempBRAggregateRank
				where ASXCode = a.ASXCode
				and BrokerCode = a.BrokerCode
				and ObservationDate < (select max(ObservationDate) from #TempBRAggregateRank)
				and BuyRank <= 5
			)
			and h.MedianPriceChangePerc > 2
			order by 
				case when a.BrokerCode = 'Macqua' then 10
					 when a.BrokerCode = 'BelPot' then 20
					 when a.BrokerCode = 'UBSAus' then 30
					 when a.BrokerCode = 'FinClrSrv' then 40
					 when a.BrokerCode = 'EurHar' then 50
					 else 999
				end asc,
				a.BrokerCode,
				h.MedianPriceChangePerc desc,
				BuyRank, 
				NetValue desc

			select
				distinct
				ASXCode,
				DisplayOrder,
				ObservationDate,
				OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) as ReportProc
			from #TempOutputBrokerNewBuy

		end

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