-- Stored procedure: [StockData].[usp_RefeshStockCustomFilter]


CREATE PROCEDURE [StockData].[usp_RefeshStockCustomFilter]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pbitMonitorStockUpdateOnly bit = 0
AS
/******************************************************************************
File: usp_RefeshStockCustomFilter.sql
Stored Procedure Name: usp_RefeshStockCustomFilter
Overview
-----------------
usp_RefeshStockCustomFilter

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
Date:		2020-11-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshStockCustomFilter'
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

		if @pbitMonitorStockUpdateOnly = 0
		begin		

			CREATE TABLE #TempCustomFilterDetail(
				[CustomFilterDetailID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
				[CustomFilterID] [int] NOT NULL,
				[ASXCode] [varchar](10) NOT NULL,
				[DisplayOrder] [int] NOT NULL,
				[CreateDate] [smalldatetime] NULL
			)

			CREATE TABLE #TempCustomFilter(
				[CustomFilterID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
				[CustomFilter] [varchar](500) NOT NULL,
				[DisplayOrder] [int] NOT NULL,
				[CreateDate] [smalldatetime] NULL
			)

			insert into #TempCustomFilter
			(
				[CustomFilter],
				[DisplayOrder],
				CreateDate
			)
			select distinct
				[CustomFilter],
				[DisplayOrder],
				getdate() as CreateDate
			from
			(
				select 'Monitor Stock - Core Stocks' as CustomFilter, 100 as DisplayOrder
				union
				select 'Monitor Stock - All Stocks' as CustomFilter, 120 as DisplayOrder
				union
				select 'Trade Strategy - Broker New Buy Report' as CustomFilter, 210 as Display
				union
				select 'Trade Strategy - Broker Buy Retail Sell' as CustomFilter, 212 as Display
				union
				select 'Trade Strategy - Broker Buy Retail Sell - 5 Days' as CustomFilter, 221 as Display
				union
				select 'Trade Strategy - Break Through Previous Break Through High' as CustomFilter, 214 as Display
				union
				select 'Trade Strategy - Long Bullish Bar' as CustomFilter, 216 as Display
				union
				select 'Trade Strategy - Volume Volatility Contraction' as CustomFilter, 218 as Display
				--union
				--select 'Trade Strategy - Today Close Cross Over VWAP' as CustomFilter, 220 as Display
				union
				select 'Trade Strategy - Breakout Retrace' as CustomFilter, 222 as Display
				union
				select 'Trade Strategy - Director subscribes SPP' as CustomFilter, 224 as Display
				union
				select 'Trade Strategy - Overcome Big Sell' as CustomFilter, 226 as Display
				union
				select 'Trade Strategy - Price BreakThrough Placement Price' as CustomFilter, 228 as Display
				union
				select 'Trade Strategy - Retreat to Weekly MA10' as CustomFilter, 228 as Display
				union
				select 'Trade Strategy - Tree Shake Morning Market' as CustomFilter, 229 as Display
				union
				select 'Trade Strategy - Advanced HBXF' as CustomFilter, 230 as Display
				union
				select 'Trade Strategy - Advanced FRCS' as CustomFilter, 224 as Display
				union
				select 'Trade Strategy - Top 20 Holder Stocks' as CustomFilter, 230 as Display
				union
				select 'Trade Strategy - New High Minor Retrace' as CustomFilter, 226 as Display
				union
				select 'Trade Strategy - Most Recent Tweet' as CustomFilter, 227 as Display
				union
				select 'Trade Strategy - ChiX Analysis' as CustomFilter, 228 as Display
				union
				select 'Trade Strategy - Final Institute Dump' as CustomFilter, 229 as Display
				union
				select 'Buy vs Sell - Buy vs MC' as CustomFilter, 265 as Display
				union
				select 'Buy vs Sell - Match Volume vs Free Float' as CustomFilter, 267 as Display
				union
				select 'Scan Results - Alert Occurrence Current Date' as CustomFilter, 300 as Display
				union
				select 'Scan Results - Alert Occurrence Previous 1 Day' as CustomFilter, 310 as Display
				union
				select 'Scan Results - Alert Occurrence Previous 2 Day' as CustomFilter, 320 as Display
				union
				select 'Scan Results - Alert Occurrence Previous 3 Day' as CustomFilter, 330 as Display
				union
				select 'Others - Director Buy On Market' as CustomFilter, 800 as Display
				union
				select distinct 'Sector - ' + upper(Token) as CustomFilter, 
								800 + TokenOrder as DisplayOrder
				from LookupRef.KeyToken
				where isnull(IsDisabled, 0) = 0
				and TokenType = 'Sector'
			) as a
			order by DisplayOrder		

			if object_id(N'Tempdb.dbo.#TempBrokerNewBuy') is not null
				drop table #TempBrokerNewBuy

			create table #TempBrokerNewBuy
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempBrokerNewBuy
			exec [Report].[usp_Get_Strategy_BrokerNewBuy]
			@pbitASXCodeOnly = 1,
			@pintNumPrevDay = 0

			if object_id(N'Tempdb.dbo.#TempBrokerBuyRetailSell') is not null
				drop table #TempBrokerBuyRetailSell

			create table #TempBrokerBuyRetailSell
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempBrokerBuyRetailSell
			exec [Report].[usp_Get_Strategy_BrokerBuyRetailSell]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1
			
			if object_id(N'Tempdb.dbo.#TempBrokerBuyRetailSell5Days') is not null
				drop table #TempBrokerBuyRetailSell5Days

			create table #TempBrokerBuyRetailSell5Days
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempBrokerBuyRetailSell5Days
			exec [Report].[usp_Get_Strategy_BrokerBuyRetailSell]
			@pintNumPrevDay = 5,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempBreakThroughPreviousHigh') is not null
				drop table #TempBreakThroughPreviousHigh

			create table #TempBreakThroughPreviousHigh
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempBreakThroughPreviousHigh
			exec [Report].[usp_Get_Strategy_BreakThroughPreviousBreakThroughHigh]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			--if object_id(N'Tempdb.dbo.#TempBuyVsSellBuyvsMC') is not null
			--	drop table #TempBuyVsSellBuyvsMC

			--create table #TempBuyVsSellBuyvsMC
			--(
			--	ASXCode varchar(10) not null,
			--	DisplayOrder int not null,
			--	ObservationDate date,
			--	ReportProc varchar(200)
			--)

			--insert into #TempBuyVsSellBuyvsMC
			--exec [Report].[usp_GetTodayTradeBuyvsSell]
			--@pintNumPrevDay = 0,
			--@pvchSortBy = 'BuyvsMC',
			--@pbitASXCodeOnly = 1

			--if object_id(N'Tempdb.dbo.#TempBuyVsSellMatchVolumeVsFreeFloat') is not null
			--	drop table #TempBuyVsSellMatchVolumeVsFreeFloat

			--create table #TempBuyVsSellMatchVolumeVsFreeFloat
			--(
			--	ASXCode varchar(10) not null,
			--	DisplayOrder int not null,
			--	ObservationDate date,
			--	ReportProc varchar(200)
			--)

			--insert into #TempBuyVsSellMatchVolumeVsFreeFloat
			--exec [Report].[usp_GetTodayTradeBuyvsSell]
			--@pintNumPrevDay = 0,
			--@pvchSortBy = 'Match Volume out of Free Float',
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempBreakoutRetrace') is not null
				drop table #TempBreakoutRetrace

			create table #TempBreakoutRetrace
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempBreakoutRetrace
			exec [Report].[usp_Get_Strategy_BreakoutRetrace]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempDirectorSubscribesSPP') is not null
				drop table #TempDirectorSubscribesSPP

			create table #TempDirectorSubscribesSPP
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempDirectorSubscribesSPP
			--exec [Report].[usp_Get_Strategy_DirectorSubscribeSPP]
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempLongBullishBar') is not null
				drop table #TempLongBullishBar

			create table #TempLongBullishBar
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempLongBullishBar
			exec [Report].[usp_Get_Strategy_LongBullishBar]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempOvercomeBigSell') is not null
				drop table #TempOvercomeBigSell

			create table #TempOvercomeBigSell
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempOvercomeBigSell
			--exec [Report].[usp_Get_Strategy_OvercomeBigSell]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempPriceBreakThroughPlacementPrice') is not null
				drop table #TempPriceBreakThroughPlacementPrice

			create table #TempPriceBreakThroughPlacementPrice
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempPriceBreakThroughPlacementPrice
			--exec [Report].[usp_Get_Strategy_PriceBreakThroughPlacementPrice]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1
			
			if object_id(N'Tempdb.dbo.#TempRetreatToWeeklyMA10') is not null
				drop table #TempRetreatToWeeklyMA10

			create table #TempRetreatToWeeklyMA10
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempRetreatToWeeklyMA10
			exec [Report].[usp_Get_Strategy_RetreatToWeeklyMA10]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempTreeShakeMorningMarket') is not null
				drop table #TempTreeShakeMorningMarket

			create table #TempTreeShakeMorningMarket
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempTreeShakeMorningMarket
			exec [Report].[usp_Get_Strategy_TreeShakeMorningMarket]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempVolumeVolatilityContraction') is not null
				drop table #TempVolumeVolatilityContraction

			create table #TempVolumeVolatilityContraction
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempVolumeVolatilityContraction
			--exec [Report].[usp_Get_Strategy_VolumeVolatilityContraction]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempAdvancedHBXF') is not null
				drop table #TempAdvancedHBXF

			create table #TempAdvancedHBXF
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			insert into #TempAdvancedHBXF
			exec [Report].[usp_Get_Strategy_AdvancedHBXF]
			@pintNumPrevDay = 0,
			@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempAdvancedFRCS') is not null
				drop table #TempAdvancedFRCS

			create table #TempAdvancedFRCS
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempAdvancedFRCS
			--exec [Report].[usp_Get_Strategy_AdvancedFRCS]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempMostRecentTweet') is not null
				drop table #TempMostRecentTweet

			create table #TempMostRecentTweet
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempMostRecentTweet
			--exec [Report].[usp_Get_Strategy_MostRecentTweet]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempChixAnalysis') is not null
				drop table #TempChixAnalysis

			create table #TempChixAnalysis
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempChixAnalysis
			--exec [Report].[usp_Get_Strategy_ChiXVolumeSurge]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempFinalInstituteDump') is not null
				drop table #TempFinalInstituteDump

			create table #TempFinalInstituteDump
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempFinalInstituteDump
			--exec [Report].[usp_Get_Strategy_FinalInstituteDump]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempTop20HolderStocks') is not null
				drop table #TempTop20HolderStocks

			create table #TempTop20HolderStocks
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempTop20HolderStocks
			--exec [Report].[usp_Get_Strategy_Top20HolderStocks]
			--@pbitASXCodeOnly = 1

			if object_id(N'Tempdb.dbo.#TempNewHighMinorRetrace') is not null
				drop table #TempNewHighMinorRetrace

			create table #TempNewHighMinorRetrace
			(
				ASXCode varchar(10) not null,
				DisplayOrder int not null,
				ObservationDate date,
				ReportProc varchar(200)
			)

			--insert into #TempNewHighMinorRetrace
			--exec [Report].[usp_Get_Strategy_NewHighMinorRetrace]
			--@pintNumPrevDay = 0,
			--@pbitASXCodeOnly = 1

			insert into #TempCustomFilterDetail
			(
				[CustomFilterID],
				ASXCode,
				DisplayOrder,
				CreateDate
			)
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and isnull(PriorityLevel, 999) <= 999
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - Core Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - All Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBrokerNewBuy
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Broker New Buy Report'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBrokerBuyRetailSell
  				--where ASXCode = 'EXR.AX'
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Broker Buy Retail Sell'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBreakThroughPreviousHigh
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Break Through Previous Break Through High'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBreakoutRetrace
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Breakout Retrace'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempDirectorSubscribesSPP
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Director subscribes SPP'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempLongBullishBar
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Long Bullish Bar'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempOvercomeBigSell
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Overcome Big Sell'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempPriceBreakThroughPlacementPrice
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Price BreakThrough Placement Price'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempRetreatToWeeklyMA10
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Retreat to Weekly MA10'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempTreeShakeMorningMarket
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Tree shake morning market'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempVolumeVolatilityContraction
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Volume Volatility Contraction'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBrokerBuyRetailSell5Days
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Broker Buy Retail Sell - 5 Days'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempAdvancedFRCS
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Advanced FRCS'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempAdvancedHBXF
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Advanced HBXF'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempMostRecentTweet
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Most Recent Tweet'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempChixAnalysis
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - ChiX Analysis'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempFinalInstituteDump
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Final Institute Dump'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempTop20HolderStocks
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - Top 20 Holder Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempNewHighMinorRetrace
			) as b
			on 1 = 1
			where CustomFilter = 'Trade Strategy - New High Minor Retrace'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBuyVsSellBuyvsMC
			) as b
			on 1 = 1
			where CustomFilter = 'Buy vs Sell - Buy vs MC'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					DisplayOrder
				from #TempBuyVsSellMatchVolumeVsFreeFloat
			) as b
			on 1 = 1
			where CustomFilter = 'Buy vs Sell - Match Volume vs Free Float'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from #TempCustomFilter as a
			inner join 
			(
				select
					ASXCode,
					a.Token,
					b.TokenOrder as DisplayOrder
				from LookupRef.StockKeyToken as a
				inner join LookupRef.KeyToken as b
				on a.Token = b.Token
				and b.TokenType = 'SECTOR'
				union 
				select
					cast(b.TokenID as varchar(10)) as ASXCode,
					a.Token,
					b.TokenOrder as DisplayOrder
				from LookupRef.StockKeyToken as a
				inner join LookupRef.KeyToken as b
				on a.Token = b.Token
				and b.TokenType = 'SECTOR'
			) as b
			on a.CustomFilter = 'Sector - ' + b.Token
			where CustomFilter like 'Sector - %'

			truncate table [StockData].[CustomFilterDetail]

			delete a
			from [StockData].[CustomFilter] as a

			dbcc checkident('[StockData].[CustomFilter]', reseed, 1);

			set identity_insert [StockData].[CustomFilterDetail] on
			
			insert into [StockData].[CustomFilterDetail]
			(
			   [CustomFilterDetailID]
			  ,[CustomFilterID]
			  ,[ASXCode]
			  ,[DisplayOrder]
			  ,[CreateDate]
			)
			select
			   [CustomFilterDetailID]
			  ,[CustomFilterID]
			  ,[ASXCode]
			  ,[DisplayOrder]
			  ,[CreateDate]
			from #TempCustomFilterDetail
			
			set identity_insert [StockData].[CustomFilterDetail] off
			
			set identity_insert [StockData].[CustomFilter] on
			
			insert into [StockData].[CustomFilter]
			(
			   [CustomFilterID]
			  ,[CustomFilter]
			  ,[DisplayOrder]
			  ,[CreateDate]
			)
			select
			   [CustomFilterID]
			  ,[CustomFilter]
			  ,[DisplayOrder]
			  ,[CreateDate]
			from #TempCustomFilter

			set identity_insert [StockData].[CustomFilter] off
			
		end
		else
		begin
			
			delete a
			from [StockData].[CustomFilterDetail] as a
			inner join [StockData].[CustomFilter] as b
			on a.CustomFilterID = b.CustomFilterID
			where CustomFilter in ('Monitor Stock - Core Stocks', 'Monitor Stock - All Stocks')

			insert into [StockData].[CustomFilterDetail]
			(
				[CustomFilterID],
				ASXCode,
				DisplayOrder,
				CreateDate
			)
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from [StockData].[CustomFilter] as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
				and isnull(PriorityLevel, 999) <= 999
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - Core Stocks'
			union
			select 
				a.CustomFilterID as [CustomFilterID],
				b.ASXCode,
				b.DisplayOrder,
				getdate() as CreateDate
			from StockData.CustomFilter as a
			inner join 
			(
				select
					ASXCode,
					isnull(PriorityLevel, 999) as DisplayOrder
				from StockData.MonitorStock
				where MonitorTypeID = 'C'
			) as b
			on 1 = 1
			where CustomFilter = 'Monitor Stock - All Stocks'
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
