-- Stored procedure: [Report].[usp_GetBrokerBuySellPerc]



CREATE PROCEDURE [Report].[usp_GetBrokerBuySellPerc]
@pbitDebug AS BIT = 0,
@pintNumPrevDay as int = 0, 
@pdtObservationDateEnd as varchar(20), 
@pvchBrokerCode as varchar(10), 
@pvchSortBy as varchar(100) = 'Buy Perc Desc',
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetBrokerBuySellPerc.sql
Stored Procedure Name: usp_GetBrokerBuySellPerc
Overview
-----------------
usp_GetBrokerBuySellPerc

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
Date:		2020-06-21
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetBrokerBuySellPerc'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		set dateformat ymd
		--Normal varible declarations

		--Code goes here 
		--begin transaction
		declare @dtDate as date 

		if @pdtObservationDateEnd = '2050-12-12'
		begin
			select @pdtObservationDateEnd = max(ObservationDate)
			from StockData.BrokerReport

			select @dtDate = Common.DateAddBusinessDay(0, cast(getdate() as date))
		end

		declare @pdtObservationDateStart as date = Common.DateAddBusinessDay(-1 * @pintNumPrevDay, cast(@pdtObservationDateEnd as date))

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select * 
		into #TempPriceSummary
		from StockData.v_PriceSummary
		where ObservationDate = @dtDate
		and DateTo is null
		and LatestForTheDay = 1

		if object_id(N'Tempdb.dbo.#TempSalePerc') is not null
			drop table #TempSalePerc

		select a.ASXCode, a.BrokerCode, a.NetValue, a.NetVolume, cast(a.NetVolume*100.0/b.TotalVolume as decimal(10,2)) as SalePerc
		into #TempSalePerc
		from
		(
			select ASXCode, BrokerCode, sum(NetValue) as NetValue, sum(NetVolume) as NetVolume
			from StockData.BrokerReport 
			where ObservationDate between @pdtObservationDateStart and @pdtObservationDateEnd
			group by ASXCode, BrokerCode

		) as a
		inner join
		(
			select ASXCode, sum(NetVolume) as TotalVolume
			from StockData.BrokerReport 
			where ObservationDate between @pdtObservationDateStart and @pdtObservationDateEnd
			--and ASXCode = 'CAT.AX'
			and NetVolume > 0
			group by ASXCode
		) as b
		on a.ASXCode = b.ASXCode
		order by SalePerc desc

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate >= @pdtObservationDateStart
		and ObservationDate <= @pdtObservationDateEnd
		group by ASXCode, b.DisplayBrokerCode

		if object_id(N'Tempdb.dbo.#TempBrokerReportListLastNDay') is not null
			drop table #TempBrokerReportListLastNDay

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListLastNDay
		from #TempBRAggregateLastNDay as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNegLastNDay') is not null
			drop table #TempBrokerReportListNegLastNDay

		select distinct x.ASXCode, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNegLastNDay
		from #TempBRAggregateLastNDay as x

		if @pvchSortBy = 'Buy Perc Desc'
		begin
			select 
				cast(@pdtObservationDateStart as varchar(20)) as DateStart, 
				@pdtObservationDateEnd as DateEnd, 
				--a.*,
				a.ASXCode,
				format(a.NetValue, 'N0') as NetValue,
				format(a.NetVolume, 'N0') as NetVolume,
				cast(a.NetValue*1.0/a.NetVolume as decimal(20, 4)) as BrokerBuyPrice,
				d.[Close] as CurrentClose,
				case when cast(a.NetValue*1.0/a.NetVolume as decimal(20, 4)) > 0 and d.[Close] > 0 then cast(cast((d.[Close] - cast(a.NetValue*1.0/a.NetVolume as decimal(20, 4)))*100.0/cast(a.NetValue*1.0/a.NetVolume as decimal(20, 4)) as decimal(10, 2)) as varchar(50)) + '%' end as PriceChange,
				cast(cast(a.SalePerc as decimal(10, 2)) as varchar(20)) + '%' as SalePerc,
				format(cast(b.MedianTradeValue as int), 'N0') as MedianTradeValue,				
				format(cast(b.MedianTradeValueDaily as int), 'N0') as MedianTradeValueDaily,
				ttsu.FriendlyNameList,
				cast(c.CleansedMarketCap as decimal(20, 2)) as CleansedMarketCap, 
				cast(b.MedianPriceChangePerc as decimal(10, 2)) as MedianPriceChangePerc,
				m2.BrokerCode as RecentTopBuyBroker,
				n2.BrokerCode as RecentTopSellBroker
			from #TempSalePerc as a
			inner join StockData.MedianTradeValue as b
			on a.ASXCode = b.ASXCode
			inner join StockData.CompanyInfo as c
			on a.ASXCode = c.ASXCode
			left join #TempPriceSummary as d
			on a.ASXCode = d.ASXCode
			left join #TempBrokerReportListLastNDay as m2
			on a.ASXCode = m2.ASXCode
			left join #TempBrokerReportListNegLastNDay as n2
			on a.ASXCode = n2.ASXCode
			left join Transform.TTSymbolUser as ttsu
			on a.ASXCode = ttsu.ASXCode
			where 1 = 1
			--and ASXCode = 'SYD.AX'
			and a.BrokerCode = @pvchBrokerCode
			and NetValue > 50000
			and cast(c.CleansedMarketCap as int) > 0
			and cast(c.CleansedMarketCap as int) < 2000
			and cast(b.MedianPriceChangePerc as decimal(10, 2)) > 1.0
			order by a.NetValue/cast(c.CleansedMarketCap as int) desc
		end
		
		if @pvchSortBy = 'Sell Perc Desc'
		begin
			select cast(@pdtObservationDateStart as varchar(20)) as DateStart, @pdtObservationDateEnd as DateEnd, a.*, cast(b.MedianTradeValue as int) as MedianTradeValue, cast(b.CleansedMarketCap as int) as CleansedMarketCap, cast(b.MedianPriceChangePerc as decimal(10, 2)) as MedianPriceChangePerc
			from #TempSalePerc as a
			inner join StockData.MedianTradeValue as b
			on a.ASXCode = b.ASXCode
			where 1 = 1
			--and ASXCode = 'SYD.AX'
			and BrokerCode = @pvchBrokerCode
			and NetValue < -50000
			order by SalePerc asc
		end

		--select *
		--from #TempSalePerc
		--where ASXCode = 'HLA.AX'
		--order by SalePerc

		--select *
		--from
		--(
		--	select ASXCode, sum(SalePerc) as NetBuySalePerc, sum(NetVolume) as NetBuyVolume 
		--	from #TempSalePerc
		--	where BrokerCode in ('ArgSec', 'Macqua', 'Belpot', 'Pershn', 'Eursec', 'UBSAus', 'CreSui', 'FinExe', 'BaiHol', 'MorgFn', 'BaiHol', 'OrdMin', 'EvaPar')
		--	and NetVolume > 0
		--	group by ASXCode
		--) as a
		--inner join 
		--(
		--	select ASXCode, sum(NetVolume) as TotalVolume, sum(NetValue) as TotalValue
		--	from StockData.BrokerReport 
		--	where ObservationDate between @pdtObservationDateStart and @pdtObservationDateEnd
		--	--and ASXCode = 'CAT.AX'
		--	and NetVolume > 0
		--	group by ASXCode
		--) as b
		--on a.ASXCode = b.ASXCode
		--inner join
		--(
		--	select ASXCode, BrokerCode as NetSaleBroker, NetVolume, NetValue, SalePerc as MinSalePerc, row_number() over (partition by ASXCode order by SalePerc asc) as RowNumber
		--	from #TempSalePerc
		--) as c
		--on a.ASXCode = c.ASXCode
		--where 1 = 1
		--and a.NetBuyVolume*100.0/b.TotalVolume > 50
		--and c.MinSalePerc < -40
		--and c.RowNumber = 1
		--and b.TotalValue > 500000;

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
