-- Stored procedure: [StockData].[usp_GetMonitorStock]


CREATE PROCEDURE [StockData].[usp_GetMonitorStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchMonitorStockTypeID as varchar(10),
@pintPriorityLevelMin as int = 20,
@pintPriorityLevelMax as int = 999
AS
/******************************************************************************
File: usp_GetMonitorStock.sql
Stored Procedure Name: usp_GetMonitorStock
Overview
-----------------
usp_GetMonitorStock

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
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMonitorStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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

		declare @pvchASXCode varchar(10)
		declare @pvchStockCode varchar(7)

		if @pvchMonitorStockTypeID = 'G'
		begin
			if exists
			(
				select 1
				from StockData.TotalGex
				where ObservationDate = Common.DateAddBusinessDay(-1, getdate())
				and ASXCode = 'SPY.US'
				and timeframe = 'daily'
			)
			and exists
			(
				select 1
				from StockData.TotalGex
				where ObservationDate = Common.DateAddBusinessDay(-1, getdate())
				and ASXCode = 'QQQ.US'
				and timeframe = 'daily'
			)
			begin
				return
			end

			select *
			from
			(
				select
				   [ASXCode],
				   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
				   null as LastUpdateDate
				from
				(
					select 'BABA.US' as ASXCode
					union
					select 'VXX.US' as ASXCode
					union
					select 'UVXY.US' as ASXCode
				) as i
				union
				select 
				   a.[ASXCode],
				   substring(a.ASXCode, 0, len(a.ASXCode) - (charindex('.', reverse(a.ASXCode), 0) - 1)) as StockCode,
					LastUpdateDate
				from StockData.MonitorStock as a
				--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
				where a.MonitorTypeID = 'Q'
				--and a.ASXCode in ('SPY.US', 'QQQ.US', 'DIA.US', 'IWM.US', 'GDX.US', 'LIT.US', 'ALB.US', 'SQM.US', 'LAC.US')
				--and a.ASXCode in ('MDB.US')
				and charindex('.', a.ASXCode, 0) > 0
				and
				(
					--datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) > 1*60
					--and
					isnull(a.UpdateStatus, 0) = 0
				)
				and 
				(
					--exists
					--(
					--	select 1
					--	from StockData.ComponentStock
					--	where ASXCode = a.ASXCode
					--)
					--or
					--exists
					--(
					--	select 1
					--	from Stock.ETF
					--	where ASXCode = a.ASXCode
					--)
					--or
					exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValueDaily > 1000000
						and ASXCode = a.ASXCode
					)
					or a.ASXCode in ('ALB.US', 'SQM.US', 'LAC.US', 'SGML')
				)
				--and not exists
				--(
				--	select 1
				--	from StockData.MoneyFlowInfo
				--	where ASXCode = a.ASXCode
				--	and ObservationDate = '2022-06-17'
				--)
			) as x
			where 1 = 1
			--and x.ASXCode in ('AAPL.US', 'MSFT.US', 'AMZN.US', 'GOOGL.US', 'TSLA.US', 'TSM.US', 'QQQ.US', 'SPY.US', 'IWM.US', 'DIA.US')
			order by datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()
		end

		if @pvchMonitorStockTypeID = 'Q'
		begin
			if exists
			(
				select 1
				from [StockData].[MoneyFlowInfo]
				where ObservationDate = Common.DateAddBusinessDay(-1, getdate())
				and ASXCode = 'SPY.US'
				and MoneyFlowType = 'daily'
			)
			and exists
			(
				select 1
				from [StockData].[MoneyFlowInfo]
				where ObservationDate = Common.DateAddBusinessDay(-1, getdate())
				and ASXCode = 'QQQ.US'
				and MoneyFlowType = 'daily'
			)
			begin
				return
			end

			if object_id(N'Tempdb.dbo.#TempObDate') is not null
				drop table #TempObDate

			select top 3 ObservationDate 
			into #TempObDate
			from
			(
				select ObservationDate 
				from StockData.QU100Parsed
				group by ObservationDate 
			) as a
			order by ObservationDate desc;

			select
				[ASXCode],
				StockCode,
				null as LastUpdateDate
			from
			(
				select
					[ASXCode],
					StockCode,
					min(RunOrder) as RunOrder
				from
				(
					select
						'QQQ.US' as ASXCode,
						'QQQ' as StockCode,
						20 as RunOrder
					union
					select
						'SPY.US' as ASXCode,
						'SPY' as StockCode,
						10 as RunOrder
					union
					select
						'DIA.US' as ASXCode,
						'DIA' as StockCode,
						30 as RunOrder
					union
					select
						'IWM.US' as ASXCode,
						'IWM' as StockCode,
						40 as RunOrder
					union
					select
						a.ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						800 as RunOrder
					from Stock.ETF as a
					union
					select 
						ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						850 as RunOrder
					from [Transform].[MarketCLVTrendDetails] as a
					where ObservationDate in (select ObservationDate from #TempObDate)
					and MarketCap = 'h. 300B+'
					union
					select 
						distinct 
						ASXCode, 
						Ticker as StockCode, 
						900 as RunOrder
					from StockData.QU100Parsed
					where ObservationDate in (select ObservationDate from #TempObDate)
					and timeframe = 'daily'
				) as i
				group by ASXCode, StockCode
			) as x
			order by x.RunOrder

			return

			select *
			from
			(
				select
				   [ASXCode],
				   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
				   null as LastUpdateDate
				from
				(
					select 'BABA.US' as ASXCode
					union
					select 'VXX.US' as ASXCode
					union
					select 'UVXY.US' as ASXCode
				) as i
				union
				select 
				   a.[ASXCode],
				   substring(a.ASXCode, 0, len(a.ASXCode) - (charindex('.', reverse(a.ASXCode), 0) - 1)) as StockCode,
					LastUpdateDate
				from StockData.MonitorStock as a
				--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
				where a.MonitorTypeID = 'Q'
				--and a.ASXCode in ('SPY.US', 'QQQ.US', 'DIA.US', 'IWM.US', 'GDX.US', 'LIT.US', 'ALB.US', 'SQM.US', 'LAC.US')
				--and a.ASXCode in ('MDB.US')
				and charindex('.', a.ASXCode, 0) > 0
				and
				(
					datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) > 10*60
					and
					isnull(a.UpdateStatus, 0) = 0
				)
				and 
				(
					exists
					(
						select 1
						from StockData.ComponentStock
						where ASXCode = a.ASXCode
					)
					or
					exists
					(
						select 1
						from Stock.ETF
						where ASXCode = a.ASXCode
					)
					or
					exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValueDaily > 10000
						and ASXCode = a.ASXCode
					)
				)
				--and not exists
				--(
				--	select 1
				--	from StockData.MoneyFlowInfo
				--	where ASXCode = a.ASXCode
				--	and ObservationDate = '2022-06-17'
				--)
			) as x
			--where x.ASXCode in ('AAPL.US', 'MSFT.US', 'AMZN.US', 'GOOGL.US', 'TSLA.US', 'TSM.US', 'QQQ.US', 'SPY.US', 'IWM.US', 'DIA.US')
			order by datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()
			
		end	

		if @pvchMonitorStockTypeID = 'Q2'
		begin
			--if exists
			--(
			--	select 1
			--	from [StockData].[MoneyFlowInfo]
			--	where ObservationDate = Common.DateAddBusinessDay(-1, getdate())
			--	and ASXCode = 'SPY.US'
			--	and MoneyFlowType = 'daily'
			--)
			--and exists
			--(
			--	select 1
			--	from [StockData].[MoneyFlowInfo]
			--	where ObservationDate = Common.DateAddBusinessDay(-1, getdate())
			--	and ASXCode = 'QQQ.US'
			--	and MoneyFlowType = 'daily'
			--)
			--begin
			--	return
			--end

			select
				[ASXCode],
				StockCode,
				null as LastUpdateDate
			from
			(
				select
					[ASXCode],
					StockCode,
					min(RunOrder) as RunOrder
				from
				(
					select
						'QQQ.US' as ASXCode,
						'QQQ' as StockCode,
						20 as RunOrder
					union
					select
						'SPY.US' as ASXCode,
						'SPY' as StockCode,
						10 as RunOrder
					union
					select
						'DIA.US' as ASXCode,
						'DIA' as StockCode,
						30 as RunOrder
					union
					select
						'IWM.US' as ASXCode,
						'IWM' as StockCode,
						40 as RunOrder
					union
					select
						a.ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						800 as RunOrder
					from Stock.ETF as a
					union
					select 
						ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						850 as RunOrder
					from [Transform].[MarketCLVTrendDetails] as a
					where MarketCap = 'h. 300B+'
					union
					select 
						distinct 
						ASXCode, 
						substring(ASXCode, 1, charindex('.', ASXCode, 0) - 1) as StockCode, 
						900 as RunOrder
					from dbo.[Component Stocks - SPX500]
					union
					select 
						distinct 
						ASXCode, 
						Ticker as StockCode, 
						900 as RunOrder
					from StockData.QU100Parsed
					where ObservationDate in (select max(ObservationDate) from StockData.QU100Parsed)
					and timeframe = 'daily'
				) as i
				group by ASXCode, StockCode
			) as x
			order by x.RunOrder
		end	

		if @pvchMonitorStockTypeID in ('I')
		begin
			--select
			--	'IBUS500' as ASXCode,
			--	'IBUS500' as StockCode
			--union
			--select
			--	'IBUS30' as ASXCode,
			--	'IBUS30' as StockCode
			--union
			--select
			--	'IBUS100' as ASXCode,
			--	'IBUS100' as StockCode
			select 
				ASXCode,
				LEFT(ASXCode, CHARINDEX('.', ASXCode) - 1) as StockCode,
				50 as RunOrder
			from
			(
				select case when ASXCode = '_SPX.US' then 'SPX.US' else ASXCode end as ASXCode
				from LookupRef.StocksToCheck
			) as x
			where 1 = 1 
			--and x.ASXCode in ('QQQ.US', 'SPY.US', 'AMD.US', 'AVGO.US', 'GDX.US', 'IWM.US', 'META.US', 'MU.US', 'SLV.US', 'GLD.US', 'TSLA.US', 'TQQQ.US', 'SQQQ.US', 'AMZN.US', 'KWEB.US', 'META.US', 'OXY.US', 'DIA.US', 'SOXL.US')
			order by RunOrder

		end

		if @pvchMonitorStockTypeID in ('H')
		begin
			--select
			--	a.ASXCode,
			--	substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
			--	800 as RunOrder
			--from Stock.ETF as a

			--select
			--	'QQQ.US' as ASXCode,
			--	'QQQ' as StockCode,
			--	100 as RunOrder

			if datepart(hour, CONVERT(DATETIME,GETDATE() AT TIME ZONE 'AUS Eastern Standard Time' AT TIME ZONE 'Eastern Standard Time')) <= 16
			begin
				select
					ASXCode,
					StockCode,
					RunOrder
				from
				(
					--select 
					--	a.[ASXCode] as ASXCode,
					--	substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					--	case when MarketCap = 'h. 300B+' then 700 when MarketCap = 'g. 10B+' then 750 else 990 end as RunOrder
					--from Transform.MarketCLVTrendDetails as a
					--where MarketCap in ('h. 300B+', 'g. 10B+')
					--union
					select
						a.[ASXCode] as ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						100 as RunOrder
					from LookupRef.StocksToCheck as a
				) as x
				order by x.RunOrder
			end
			else
			begin
				select 
					ASXCode,
					StockCode,
					RunOrder
				from
				(
					select
						'QQQ.US' as ASXCode,
						'QQQ' as StockCode,
						10 as RunOrder
					union
					select
						'SPY.US' as ASXCode,
						'SPY' as StockCode,
						20 as RunOrder
					union
					select
						'DIA.US' as ASXCode,
						'DIA' as StockCode,
						30 as RunOrder
					union
					select
						'IWM.US' as ASXCode,
						'IWM' as StockCode,
						40 as RunOrder
					union
					select
						a.ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						800 as RunOrder
					from Stock.ETF as a
					union
					select 
						a.[ASXCode] as ASXCode,
						substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
						case when isnull(b.CleansedMarketCap, 1) > 100000 then 700 else 990 end as RunOrder
					from StockData.MonitorStock as a
					left join StockData.CompanyInfo as b
					on a.ASXCode = b.ASXCode
					--left join #TempPriceHistory as b
					--on a.ASXCode = b.ASXCode
					--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
					where a.MonitorTypeID = 'H'
					--and exists
					--(
					--	select 1
					--	from StockData.CompanyInfo
					--	where 1 = 1
					--	and CleansedMarketCap > 300000
					--	and ASXCode = a.ASXCode
					--)
					and exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValueDaily > 10000
						and ASXCode = a.ASXCode
					)
					and not exists
					(
						select 1
						from StockData.PriceHistory
						where ASXCode = a.ASXCode
						and ObservationDate >= dateadd(day, -1, getdate())
					)
					union
					select 
					   [ASXCode],
					   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					   800 as RunOrder
					FROM StockData.QU100Parsed
					where ObservationDate >  dateadd(day, -200, getdate())
					and TimeFrame = 'daily'
				) as x
				where 1 = 1 
				order by x.RunOrder
			end
		end

		if @pvchMonitorStockTypeID = 'O'
		begin
			
			select 
				ASXCode,
				StockCode,
				RunOrder
			from
			(
				select
					'QQQ.US' as ASXCode,
					'QQQ' as StockCode,
					10 as RunOrder
				union
				select
					'SPY.US' as ASXCode,
					'SPY' as StockCode,
					20 as RunOrder
				union
				select
					'DIA.US' as ASXCode,
					'DIA' as StockCode,
					30 as RunOrder
				union
				select
					'IWM.US' as ASXCode,
					'IWM' as StockCode,
					40 as RunOrder
				union
				select
					'RBLX.US' as ASXCode,
					'RBLX' as StockCode,
					900 as RunOrder
				union
				select
					'GME.US' as ASXCode,
					'GME' as StockCode,
					900 as RunOrder
				union
				select
					'SQM.US' as ASXCode,
					'SQM' as StockCode,
					900 as RunOrder
				union
				select
					'LAC.US' as ASXCode,
					'LAC' as StockCode,
					900 as RunOrder
				union
				select
					'SGML.US' as ASXCode,
					'SGML' as StockCode,
					900 as RunOrder
				union
				select 
					a.[ASXCode] as ASXCode,
					substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					150 as RunOrder
				from Stock.ETF as a
				union
				select 
					a.[ASXCode] as ASXCode,
					substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					990 as RunOrder
				from StockData.MonitorStock as a
				--left join #TempPriceHistory as b
				--on a.ASXCode = b.ASXCode
				--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
				where a.MonitorTypeID = 'H'
				and exists
				(
					select 1
					from StockData.CompanyInfo
					where 1 = 1
					and CleansedMarketCap > 30000
					and ASXCode = a.ASXCode
				)
				and exists
				(
					select 1
					from StockData.MedianTradeValue
					where MedianTradeValueDaily > 10000
					and ASXCode = a.ASXCode
				)
			) as x
			where 1 = 1 
			and StockCode in 
			(
				'SPY', 'QQQ', 'DIA', 'IWM', 'TQQQ', 'SQQQ', 'SPXU', 'SPXS',
				'GDX', 'GLD', 'SLV', 'KWEB', 'ARKK', 'HYG',
				'UVXY', 'LIT', 'JJC', 'JJN', 'JJT', 'JJU',
				'OIH', 'XOP', 'URA',
				'XLK', 'XLE', 'XLF', 
				'TSLA', 'AAPL', 'COIN', 'GME',
				'ALB', 'SQM', 'LAC', 'SGML',
				'URA', 'UEC'
			)
			--and StockCode in ('SPY', 'QQQ', 'DIA', 'IWM', 'TQQQ', 'SQQQ')
			--and ASXCode = 'VLO.US'
			--and RunOrder >= 150
			order by x.RunOrder		

		end	

		if @pvchMonitorStockTypeID in ('DQV2')
		begin
			
			--select 
			--	[ASXCode],
			--	substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
			--	null as LastUpdateDate
			--from
			--(
			--	select ASXCode
			--	from Analysis.MostTradedStock
			--) as i
			
			--return
			
			--if datepart(hour, getdate()) in (23)
			if datepart(hour, getdate()) in (21, 22, 23, 0, 1, 2)
			begin
				if object_id(N'Tempdb.dbo.#TempASXCodeObDate') is not null
					drop table #TempASXCodeObDate

				select a.ASXCode, a.ObservationDate
				into #TempASXCodeObDate
				from StockData.v_OptionTrade as a
				inner join
				(
					select max(ObservationDate) as ObservationDate
					from StockData.v_OptionTrade
				) as b
				on a.ObservationDate = b.ObservationDate
				group by a.ASXCode, a.ObservationDate

				if object_id(N'Tempdb.dbo.#TempOptionDelayQuote') is not null
					drop table #TempOptionDelayQuote

				select 
					identity(int, 1, 1) as UniqueKey,
					x.*, y.[Close]*y.Volume as TradeValue, ogc.GEXDeltaAdjusted as GEXDelta,
					case when ot.ObservationDate is not null then 1 else 0 end as InOptionTrade
				into #TempOptionDelayQuote
				from
				(
					select 
					   [ASXCode],
					   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					   null as LastUpdateDate
					from
					(
						select ASXCode
						from Analysis.MostTradedStock
						union
						select ASXCode
						from LookupRef.StocksToCheck
					) as i
					--union
					--select 
					--   a.[ASXCode],
					--   substring(a.ASXCode, 0, len(a.ASXCode) - (charindex('.', reverse(a.ASXCode), 0) - 1)) as StockCode,
					--	null as LastUpdateDate
					--from StockData.MonitorStock as a
					----where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
					--where a.MonitorTypeID = 'Q'
					----and a.ASXCode in ('SPY.US', 'QQQ.US', 'DIA.US', 'IWM.US', 'GDX.US', 'LIT.US', 'ALB.US', 'SQM.US', 'LAC.US')
					----and a.ASXCode in ('MDB.US')
					--and charindex('.', a.ASXCode, 0) > 0
					--and
					--(
					--	--datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) > 10*60
					--	--and
					--	isnull(a.UpdateStatus, 0) = 0
					--)
					--and 
					--(
					--	--exists
					--	--(
					--	--	select 1
					--	--	from StockData.ComponentStock
					--	--	where ASXCode = a.ASXCode
					--	--)
					--	--or
					--	exists
					--	(
					--		select 1
					--		from Stock.ETF
					--		where ASXCode = a.ASXCode
					--	)
					--	or
					--	exists
					--	(
					--		select 1
					--		from StockData.MedianTradeValue
					--		where MedianTradeValueDaily > 1000000
					--		and ASXCode = a.ASXCode
					--	)
					--	or
					--	exists
					--	(
					--		select 1
					--		from StockData.CompanyInfo
					--		where CleansedMarketCap >= 300000
					--		and ASXCode = a.ASXCode
					--	)
					--	or a.ASXCode in ('ALB.US', 'SQM.US', 'LAC.US', 'SGML')
					--)
					--union
					--select 
					--   [ASXCode],
					--   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					--   null as LastUpdateDate
					--from Stock.ETF
					--where ASXCode like 'XL%.US'
					--union
					--select 
					--   [ASXCode],
					--   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					--   null as LastUpdateDate
					--from dbo.[Component Stocks - SPX500]
					--union
					--select 
					--   [ASXCode],
					--   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					--   null as LastUpdateDate
					--FROM StockData.QU100Parsed
					--where ObservationDate >  dateadd(day, -200, getdate())
					--and TimeFrame = 'daily'
					--union
					--select 
					--	ASXCode,
					--	substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					--    null as LastUpdateDate
					--from StockData.v_OptionTrade
					--group by ASXCode
				) as x
				left join StockDB_US.StockData.PriceHistoryCurrent as y
				on case when x.ASXCode = '_SPX.US' then 'SPXW.US' else x.ASXCode end = y.ASXCode
				left join Transform.OptionGEXChange as ogc
				on (x.ASXCode = ogc.ASXCode or (x.ASXCode = '_SPX.US' and ogc.ASXCode = 'SPXW.US'))
				and 
				(
					(ogc.ObservationDate = Common.DateAddBusinessDay(-2, getdate()) and datepart(hour, getdate()) in (0, 1, 2))
					or
					(ogc.ObservationDate = Common.DateAddBusinessDay(-1, getdate()) and datepart(hour, getdate()) in (20, 21, 22, 23))
				)
				left join
				(
					select ASXCode, ObservationDate
					from #TempASXCodeObDate
				) as ot
				on x.ASXCode = ot.ASXCode
				and y.ObservationDate = ot.ObservationDate
				where 1 = 1
				--and x.ASXCode in ('_SPX.US')
				/***Regardless whether stock options have been updated for a given date, we always want to kick off a full refresh starting between 7-8pm. ***/
				--and not exists
				--(
				--	select 1
				--	from [StockData].[OptionDelayedQuote_V2]
				--	where ASXCode = x.ASXCode
				--	and ObservationDate = (select max(ObservationDate) from [StockData].[OptionDelayedQuote_V2])
				--)
				and isnull(ogc.GEXDeltaAdjusted, 0) = 0
				order by 
					case when ot.ASXCode is not null then 1 else 0 end desc, 
					y.[Close]*y.Volume desc, 
					datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, 
					newid()		

				if datepart(hour, getdate()) in (20, 21, 22, 23)
				begin
					select top 100
						UniqueKey,
						case when ASXCode in ('SPXW.US', 'SPX.US') then '_SPX.US' else ASXCode end as ASXCode,
						case when ASXCode in ('SPXW.US', 'SPX.US') then '_SPX' else StockCode end as StockCode,
						LastUpdateDate,
						TradeValue,
						GEXDelta,
						InOptionTrade
					from #TempOptionDelayQuote
					--where ASXCode = 'SPXW.US'
					order by case when ASXCode in ('SPXW.US', 'SPX.US') then 1 else 0 end desc,
							 UniqueKey asc;
				end

				if datepart(hour, getdate()) in (0, 1, 2)
				begin
					select
						UniqueKey,
						case when ASXCode in ('SPXW.US', 'SPX.US') then '_SPX.US' else ASXCode end as ASXCode,
						case when ASXCode in ('SPXW.US', 'SPX.US') then '_SPX' else StockCode end as StockCode,
						LastUpdateDate,
						TradeValue,
						GEXDelta,
						InOptionTrade
					from #TempOptionDelayQuote
					--where ASXCode not in ('SPXW.US', 'SPX.US')
					order by UniqueKey asc;
				end
			end
			else
			begin
				if object_id(N'Tempdb.dbo.#TempYesterday') is not null
					drop table #TempYesterday

				if object_id(N'Tempdb.dbo.#TempToday') is not null
					drop table #TempToday

				select top 1 OptionSymbol, OpenInterest, ObservationDate, Volume
				into #TempToday
				from StockData.v_OptionDelayedQuote_V2
				where ASXCode = 'SPXW.US'
				and ObservationDate = (
					select max(ObservationDate) as ObservationDate 
					from StockData.v_OptionDelayedQuote_V2
					where ASXCode = 'SPXW.US'
				)
				order by Volume desc

				select top 1 a.OptionSymbol, a.OpenInterest, a.ObservationDate, a.Volume
				into #TempYesterday
				from StockData.v_OptionDelayedQuote_V2 as a
				inner join #TempToday as b
				on a.OptionSymbol = b.OptionSymbol
				and a.ObservationDate < b.ObservationDate
				where ASXCode = 'SPXW.US'
				order by a.ObservationDate desc

				if exists
				(
					select * 
					from #TempToday as a
					inner join #TempYesterday as b
					on 1 = 1
					and a.OpenInterest != b.OpenInterest
					and a.ObservationDate = Common.DateAddBusinessDay_Plus(-1, getdate())
				)
				begin
					if not exists
					(
						select * from Transform.CapitalTypeRatioFromOI as a
						where ASXCode = 'SPXW.US'
						and ObservationDate = Common.DateAddBusinessDay_Plus(-1, getdate())
					)
					begin
						-- Refresh GEX by capital type first
						exec [DataMaintenance].[usp_MaintainOptionGexChangeCapitalTypeByStock]
						@pvchASXCode = 'SPXW.US'

						-- Check if conditions meet and send notification 
						exec StockDB.[Notification].[usp_Notify_GEXInsightAlert]
						@pvchASXCode = 'SPXW.US'

						exec [DataMaintenance].[usp_RefreshTransformCapitalTypeRatioFromOI]
					end

					select
						[ASXCode],
						substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
						null as LastUpdateDate
					from
					(
						select ASXCode
						from LookupRef.StocksToCheck
					) as a

					--if object_id(N'Tempdb.dbo.#TempMostOptionTradedStocks') is not null
					--	drop table #TempMostOptionTradedStocks

					--select top 100 ASXCode
					--into #TempMostOptionTradedStocks
					--from StockData.OptionTrade
					--where ObservationDateLocal >= dateadd(day, -90, getdate())
					--group by ASXCode
					--order by count(*) desc

					--select *
					--from
					--(
					--	select
					--	   [ASXCode],
					--	   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					--	   null as LastUpdateDate
					--	from
					--	(
					--		SELECT ASXCode
					--		FROM 
					--		(
					--			VALUES 
					--			-- From Previous List (Unique)
					--			('_SPX.US'), ('DIA.US'), ('GOOG.US'), ('PLTR.US'),

					--			-- From Image (Merged & Deduplicated)
					--			('_VIX.US'), 
					--			('AMAT.US'), ('AMD.US'), ('AMZN.US'), ('AVGO.US'), 
					--			('BAC.US'), 
					--			('DIS.US'), 
					--			('FCX.US'), 
					--			('GDX.US'), ('GLD.US'), 
					--			('IBIT.US'), ('IWM.US'), 
					--			('KWEB.US'), 
					--			('MCD.US'), ('META.US'), ('MU.US'), 
					--			('NVDA.US'), 
					--			('ORCL.US'), ('OXY.US'), 
					--			('QQQ.US'), 
					--			('SLV.US'), ('SNOW.US'), ('SPXW.US'), ('SPY.US'), ('SQQQ.US'), 
					--			('TLT.US'), ('TQQQ.US'), ('TSLA.US'), 
					--			('XBI.US'), ('XLE.US')
					--		) AS MyList(ASXCode)
					--		union
					--		select ASXCode
					--		from LookupRef.StocksToCheck
					--	) as i
					--	union
					--	select 
					--	   a.[ASXCode],
					--	   substring(a.ASXCode, 0, len(a.ASXCode) - (charindex('.', reverse(a.ASXCode), 0) - 1)) as StockCode,
					--		LastUpdateDate
					--	from StockData.MonitorStock as a
					--	--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
					--	where a.MonitorTypeID = 'Q'
					--	--and a.ASXCode in ('SPY.US', 'QQQ.US', 'DIA.US', 'IWM.US', 'GDX.US', 'LIT.US', 'ALB.US', 'SQM.US', 'LAC.US')
					--	--and a.ASXCode in ('MDB.US')
					--	and charindex('.', a.ASXCode, 0) > 0
					--	and
					--	(
					--		--datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) > 10*60
					--		--and
					--		isnull(a.UpdateStatus, 0) = 0
					--	)
					--	and 
					--	(
					--		--exists
					--		--(
					--		--	select 1
					--		--	from StockData.ComponentStock
					--		--	where ASXCode = a.ASXCode
					--		--)
					--		--or
					--		exists
					--		(
					--			select 1
					--			from Stock.ETF
					--			where ASXCode = a.ASXCode
					--		)
					--		or
					--		exists
					--		(
					--			select 1
					--			from StockData.MedianTradeValue
					--			where MedianTradeValueDaily > 1000000
					--			and ASXCode = a.ASXCode
					--		)
					--		or
					--		exists
					--		(
					--			select 1
					--			from StockData.CompanyInfo
					--			where CleansedMarketCap >= 300000
					--			and ASXCode = a.ASXCode
					--		)
					--		or a.ASXCode in (
					--			'_SPX.US', 'SPY.US', 'QQQ.US', 'IWM.US', 'DIA.US', '_VIX.US', 'NVDA.US', 'TSLA.US', 'GLD.US', 'IBIT.US', 'GDX.US', 'TLT.US', 'KWEB.US', 
					--			'GOOG.US', 'PLTR.US', 'AMD.US', 'META.US', 'AMZN.US', 'AVGO.US'
					--		)
					--	)
					--	--and not exists
					--	--(
					--	--	select 1
					--	--	from StockData.MoneyFlowInfo
					--	--	where ASXCode = a.ASXCode
					--	--	and ObservationDate = '2022-06-17'
					--	--)
					--) as x
					--where 1 = 1
					--and 
					--(
					--	ASXCode in (
					--		'_SPX.US', 'SPY.US', 'QQQ.US', 'IWM.US', 'DIA.US', '_VIX.US', 'NVDA.US', 'TSLA.US', 'GLD.US', 'IBIT.US', 'GDX.US', 'TLT.US', 'KWEB.US', 
					--		'GOOG.US', 'PLTR.US', 'AMD.US', 'META.US', 'AMZN.US', 'AVGO.US'
					--	)
					--	or
					--	ASXCode in
					--	(
					--		select ASXCode
					--		from #TempMostOptionTradedStocks
					--	)
					--)
					----and ASXCode in ('_SPX.US')
					--order by case when ASXCode in ('_SPX.US') then 1
					--			  when ASXCode in ('QQQ.US') then 2
					--			  when ASXCode in ('SPY.US') then 3
					--			  when ASXCode in ('IWM.US') then 4
					--			  when ASXCode in ('DJI.US') then 5
					--		 else 999 end asc, 
					--		 datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()
				end
				else
				begin
					select *
						from
						(
							select
							   [ASXCode],
							   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
							   null as LastUpdateDate
							from
							(
								select '_SPX.US' as ASXCode
								union
								select 'BABA.US' as ASXCode
								union
								select '_VIX.US' as ASXCode
								union
								select ASXCode
								from LookupRef.StocksToCheck
							) as i
							union
							select 
							   a.[ASXCode],
							   substring(a.ASXCode, 0, len(a.ASXCode) - (charindex('.', reverse(a.ASXCode), 0) - 1)) as StockCode,
								LastUpdateDate
							from StockData.MonitorStock as a
							--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
							where a.MonitorTypeID = 'Q'
							--and a.ASXCode in ('SPY.US', 'QQQ.US', 'DIA.US', 'IWM.US', 'GDX.US', 'LIT.US', 'ALB.US', 'SQM.US', 'LAC.US')
							--and a.ASXCode in ('MDB.US')
							and charindex('.', a.ASXCode, 0) > 0
							and
							(
								--datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) > 10*60
								--and
								isnull(a.UpdateStatus, 0) = 0
							)
							and 
							(
								--exists
								--(
								--	select 1
								--	from StockData.ComponentStock
								--	where ASXCode = a.ASXCode
								--)
								--or
								exists
								(
									select 1
									from Stock.ETF
									where ASXCode = a.ASXCode
								)
								or
								exists
								(
									select 1
									from StockData.MedianTradeValue
									where MedianTradeValueDaily > 1000000
									and ASXCode = a.ASXCode
								)
								or
								exists
								(
									select 1
									from StockData.CompanyInfo
									where CleansedMarketCap >= 300000
									and ASXCode = a.ASXCode
								)
								or a.ASXCode in (
								'_SPX.US', 'SPY.US', 'QQQ.US', 'IWM.US', 'DIA.US', 'TQQQ.US', 'SQQQ.US', '_VIX.US', 'NVDA.US', 'TSLA.US', 'ALB.US', 'SQM.US', 'GLD.US', 'IBIT.US', 'BITO.US', 'COIN.US', 'MSTR.US', 'XBI.US', 'GDX.US', 'TLT.US', 'BABA.US', 'KWEB.US', 
								'FXI.US', 'PDD.US', 'JD.US', 'BIDU.US', 'TCOM.US', 'TME.US', 'SQ.US', 'LTHM.US', 'LAC.US', 'LIT.US', 'NEM.US', 'GOLD.US', 'GDXJ.US', 'XOM.US', 'BP.US', 'CVX.US', 'OXY.US'								
								)
							)
							--and not exists
							--(
							--	select 1
							--	from StockData.MoneyFlowInfo
							--	where ASXCode = a.ASXCode
							--	and ObservationDate = '2022-06-17'
							--)
						) as x
						where 1 = 1
						and ASXCode in ('_SPX.US')
						--and ASXCode in ('_VIX.US')
						order by datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()
				end
				
				
			end

		end

		if @pvchMonitorStockTypeID in ('DQ')
		begin
		
			if object_id(N'Tempdb.dbo.#TempOptionDelayQuote2') is not null
				drop table #TempOptionDelayQuote2

			select x.*, y.[Close]*y.Volume as TradeValue
			into #TempOptionDelayQuote2
			from
			(
				select 
					[ASXCode],
					substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					null as LastUpdateDate
				from
				(
					select '_SPX.US' as ASXCode
					--union
					--select 'BABA.US' as ASXCode
					union
					select '_VIX.US' as ASXCode
					union
					select 'GOLD.US' as ASXCode
					union
					select 'AAPL.US' as ASXCode
					union
					select 'TSLA.US' as ASXCode
					union
					select 'MSFT.US' as ASXCode
					union
					select 'NVDA.US' as ASXCode
					union
					select 'GDX.US' as ASXCode
					union
					select 'GLD.US' as ASXCode
					union
					select 'TLT.US' as ASXCode
					union
					select ASXCode
					from LookupRef.StocksToCheck
				) as i
				union
				select 
					a.[ASXCode],
					substring(a.ASXCode, 0, len(a.ASXCode) - (charindex('.', reverse(a.ASXCode), 0) - 1)) as StockCode,
					null as LastUpdateDate
				from StockData.MonitorStock as a
				--where (isnull(UpdateStatus, 0) != 1 or datediff(second, isnull(a.LastUpdateDate, '2010-01-12'), getdate()) > 300)
				where a.MonitorTypeID = 'Q'
				--and a.ASXCode in ('SPY.US', 'QQQ.US', 'DIA.US', 'IWM.US', 'GDX.US', 'LIT.US', 'ALB.US', 'SQM.US', 'LAC.US')
				--and a.ASXCode in ('MDB.US')
				and charindex('.', a.ASXCode, 0) > 0
				and
				(
					--datediff(minute, isnull(LastUpdateDate, '2010-01-12'), getdate()) > 10*60
					--and
					isnull(a.UpdateStatus, 0) = 0
				)
				and 
				(
					--exists
					--(
					--	select 1
					--	from StockData.ComponentStock
					--	where ASXCode = a.ASXCode
					--)
					--or
					exists
					(
						select 1
						from Stock.ETF
						where ASXCode = a.ASXCode
					)
					or
					exists
					(
						select 1
						from StockData.MedianTradeValue
						where MedianTradeValueDaily > 1000000
						and ASXCode = a.ASXCode
					)
					or
					exists
					(
						select 1
						from StockData.CompanyInfo
						where CleansedMarketCap >= 300000
						and ASXCode = a.ASXCode
					)
					or a.ASXCode in ('ALB.US', 'SQM.US', 'LAC.US', 'SGML')
				)
				union
				select 
					[ASXCode],
					substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					null as LastUpdateDate
				from Stock.ETF
				where ASXCode like 'XL%.US'
				union
				select 
					[ASXCode],
					substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					null as LastUpdateDate
				from dbo.[Component Stocks - SPX500]
				union
				select 
					[ASXCode],
					substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					null as LastUpdateDate
				FROM StockData.QU100Parsed
				where ObservationDate >  dateadd(day, -200, getdate())
				and TimeFrame = 'daily'
				union
				select 
					ASXCode,
					substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
					null as LastUpdateDate
				from StockData.v_OptionTrade
				group by ASXCode
			) as x
			left join StockDB_US.StockData.PriceHistoryCurrent as y
			on case when x.ASXCode = '_SPX.US' then 'SPXW.US' else x.ASXCode end = y.ASXCode
			where 1 = 1
			order by y.[Close]*y.Volume desc, datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()			

			declare @dtObservationDate as date
			select @dtObservationDate = Common.DateAddBusinessDay(-1, cast(getdate() as date))
			declare @dtObservationDatePrev2 as date
			select @dtObservationDatePrev2 = Common.DateAddBusinessDay(-3, cast(getdate() as date))
							
			select * 
			from #TempOptionDelayQuote2 as a
			where 1 = 1 		
			and not exists
			(
				select 1
				from StockData.[v_OptionDelayedQuote_WithPrev]
				where ASXCode = a.ASXCode
				and ObservationDate = @dtObservationDate
				and Volume != Prev1Volume
			)
			and 
			(
				ASXCode = '_SPX.US'
				or
				exists
				(
					select 1
					from StockData.[v_OptionDelayedQuote]
					where ASXCode = a.ASXCode
					and ObservationDate >= @dtObservationDatePrev2
				)
			)
			order by TradeValue desc;

		end


		if @pvchMonitorStockTypeID = 'GD'
		begin
			select *
			from
			(
				select
				   [ASXCode],
				   substring(ASXCode, 0, len(ASXCode) - (charindex('.', reverse(ASXCode), 0) - 1)) as StockCode,
				   null as LastUpdateDate
				from
				(
					--select
					--	'_SPX.US' as ASXCode,
					--	'_SPX' as StockCode,
					--	5 as RunOrder
					--union
					select
						'QQQ.US' as ASXCode,
						'QQQ' as StockCode,
						10 as RunOrder
					union
					select
						'SPY.US' as ASXCode,
						'SPY' as StockCode,
						20 as RunOrder
					--union
					--select
					--	'DIA.US' as ASXCode,
					--	'DIA' as StockCode,
					--	30 as RunOrder
					union
					select
						'IWM.US' as ASXCode,
						'IWM' as StockCode,
						40 as RunOrder
					--union
					--select
					--	'TLT.US' as ASXCode,
					--	'TLT' as StockCode,
					--	900 as RunOrder
					--union
					--select
					--	'GDX.US' as ASXCode,
					--	'GDX' as StockCode,
					--	900 as RunOrder
					--union
					--select
					--	'ARKK.US' as ASXCode,
					--	'ARKK' as StockCode,
					--	900 as RunOrder
					--union
					--select
					--	'_VIX.US' as ASXCode,
					--	'_VIX' as StockCode,
					--	900 as RunOrder
					--union
					--select
					--	'NVDA.US' as ASXCode,
					--	'NVDA' as StockCode,
					--	900 as RunOrder
					--union
					--select 
					--	a.[ASXCode] as ASXCode,
					--	substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as StockCode,
					--	case when MarketCap = 'h. 300B+' then 700 when MarketCap = 'g. 10B+' then 750 else 990 end as RunOrder
					--from Transform.MarketCLVTrendDetails as a
					--where MarketCap in ('h. 300B+')
					--union
					--select top 100 a.ASXCode, b.Volume*b.[Close] as TradeValue
					--from MAWork.dbo.MissedGEXStock as a
					--inner join StockData.PriceHistoryCurrent as b
					--on a.ASXCode = b.ASXCode
					--order by b.Volume*b.[Close] desc
				) as i
			) as x
			where 1 = 1
			--and x.ASXCode in ('AAPL.US', 'MSFT.US', 'AMZN.US', 'GOOGL.US', 'TSLA.US', 'TSM.US', 'QQQ.US', 'SPY.US', 'IWM.US', 'DIA.US')
			order by datediff(minute, isnull(x.LastUpdateDate, '2010-01-12'), getdate()) desc, newid()
		end

		if @pvchMonitorStockTypeID in ('ETFCOM')
		begin
			select
				m.ASXCode,
				SUBSTRING(m.ASXCode, 1, CHARINDEX('.', m.ASXCode, 0) - 1) as StockCode,
				100 as RunOrder
			from [StockData].[MonitorStock] as m
			where m.MonitorTypeID = 'ETFCOM'
			and m.ASXCode like '%.US'
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

	--	IF @@TRANCOUNT > 0
	--	BEGIN
	--		ROLLBACK TRANSACTION
	--	END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
