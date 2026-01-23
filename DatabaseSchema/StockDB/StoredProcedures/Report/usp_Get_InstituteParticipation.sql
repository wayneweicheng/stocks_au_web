-- Stored procedure: [Report].[usp_Get_InstituteParticipation]



CREATE PROCEDURE [Report].[usp_Get_InstituteParticipation]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pvchStockCode as varchar(10)
AS
/******************************************************************************
File: usp_Get_InstituteParticipation.sql
Stored Procedure Name: usp_Get_InstituteParticipation
Overview
-----------------
usp_Get_InstituteParticipation

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
Date:		2021-07-29
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
******************************B*************************************************/

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_InstituteParticipation'
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
		--declare @pvchStockCode as varchar(10) = 'LKE.AX'
		--declare @pintNumPrevDay as int = 0
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)
		declare @dtObservationDatePrevN as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 2, getdate()) as date)
		declare @dtObservationDatePrevNMinur20 as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay - 50, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempDerivedInstitutePerformance') is not null
			drop table #TempDerivedInstitutePerformance

		select 
			x.*,
			x.Quantity*100.0/y.Quantity as QuantityPerc,
			x.TradeValue*100.0/y.TradeValue as TradeValuePerc,
			c.PriceChangeVsPrevClose
		into #TempDerivedInstitutePerformance
		from
		(
			select 
				a.ASXCode,
				ObservationDate as ObservationDate,
				isnull(DerivedInstitute, 0) as DerivedInstitute,
				a.ActBuySellInd, 
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from StockData.CourseOfSaleSecondary as a
			where 1 = 1
			and ASXCode = @pvchStockCode
			and a.ObservationDate >= @dtObservationDatePrevNMinur20
			and ActBuySellInd is not null
			group by a.ASXCode, ObservationDate, isnull(DerivedInstitute, 0), a.ActBuySellInd
		) as x
		inner join
		(
			select 
				a.ASXCode, 
				ObservationDate as ObservationDate,
				isnull(DerivedInstitute, 0) as DerivedInstitute,
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from StockData.CourseOfSaleSecondary as a
			where 1 = 1
			and ASXCode = @pvchStockCode
			and a.ObservationDate >= @dtObservationDatePrevNMinur20
			and ActBuySellInd is not null
			group by a.ASXCode, ObservationDate, isnull(DerivedInstitute, 0)
		) as y
		on x.DerivedInstitute = y.DerivedInstitute
		and x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		left join Transform.PriceHistory as c
		on x.ASXCode = c.ASXCode
		and c.ObservationDate = x.ObservationDate
		and c.ASXCode = @pvchStockCode
		order by x.ASXCode, x.ObservationDate, isnull(x.DerivedInstitute, 0), x.ActBuySellInd;

		if object_id(N'Tempdb.dbo.#TempBRAggregateLastNDay') is not null
			drop table #TempBRAggregateLastNDay

		select ASXCode, b.DisplayBrokerCode as BrokerCode, ObservationDate, sum(NetValue) as NetValue
		into #TempBRAggregateLastNDay
		from StockData.BrokerReport as a
		inner join LookupRef.v_BrokerName as b
		on a.BrokerCode = b.BrokerCode
		where ObservationDate >= @dtObservationDatePrevNMinur20
		and ObservationDate <= @dtObservationDate
		and a.ASXCode = @pvchStockCode
		group by ASXCode, b.DisplayBrokerCode, ObservationDate

		if object_id(N'Tempdb.dbo.#TempBrokerReportListLastNDay') is not null
			drop table #TempBrokerReportListLastNDay

		select distinct x.ASXCode, x.ObservationDate, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			and x.ObservationDate = a.ObservationDate
			order by NetValue desc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListLastNDay
		from #TempBRAggregateLastNDay as x

		if object_id(N'Tempdb.dbo.#TempBrokerReportListNegLastNDay') is not null
			drop table #TempBrokerReportListNegLastNDay

		select distinct x.ASXCode, x.ObservationDate, stuff((
			select top 4 ',' + [BrokerCode]
			from #TempBRAggregateLastNDay as a
			where x.ASXCode = a.ASXCode
			and x.ObservationDate = a.ObservationDate
			order by NetValue asc
			for xml path('')), 1, 1, ''
		) as [BrokerCode]
		into #TempBrokerReportListNegLastNDay
		from #TempBRAggregateLastNDay as x
		
		if object_id(N'Tempdb.dbo.#TempInstitutePerc') is not null
			drop table #TempInstitutePerc

		select 
			x.ObservationDate,
			x.ASXCode as ASXCode,
			isnull(DerivedInstitute, 0) as DerivedInstitute, 
			x.VWAP as VWAP,
			format(x.Quantity, 'N0') as Quantity, 
			format(x.TradeValue, 'N0') as TradeValue,
			x.Quantity*100.0/y.Quantity as QuantityPerc,
			x.TradeValue*100.0/y.TradeValue as TradeValuePerc,
			c.PriceChangeVsPrevClose
		into #TempInstitutePerc
		from
		(
			select distinct
				a.ASXCode,
				ObservationDate as ObservationDate,
				isnull(DerivedInstitute, 0) as DerivedInstitute, 
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from StockData.CourseOfSaleSecondary as a with(nolock)
			where 1 = 1
			and
			(
				a.ObservationDate >= @dtObservationDatePrevNMinur20
				and
				a.ObservationDate <= @dtObservationDate
			)
			and ASXCode = @pvchStockCode
			group by a.ASXCode, isnull(DerivedInstitute, 0), a.ObservationDate
		) as x
		inner join
		(
			select distinct
				a.ASXCode,
				a.ObservationDate as ObservationDate,
				sum(a.Quantity*a.Price)/sum(a.Quantity) as VWAP,
				sum(a.Quantity) as Quantity, 
				sum(a.Quantity*a.Price) as TradeValue
			from StockData.CourseOfSaleSecondary as a with(nolock)
			where 1 = 1
			and
			(
				a.ObservationDate >= @dtObservationDatePrevNMinur20
				and
				a.ObservationDate <= @dtObservationDate
			)
			and ASXCode = @pvchStockCode
			group by a.ASXCode, a.ObservationDate
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate
		left join Transform.PriceHistory as c with(nolock)
		on x.ASXCode = c.ASXCode
		and x.ObservationDate = c.ObservationDate
		and 
		(
			c.ObservationDate >= @dtObservationDatePrevNMinur20
			and
			c.ObservationDate <= @dtObservationDate
		)
		where x.DerivedInstitute = 1
		order by x.ObservationDate desc, x.DerivedInstitute;

		if object_id(N'Tempdb.dbo.#TempInstitutePercRank') is not null
			drop table #TempInstitutePercRank

		select 
			*, 
			row_number() over (partition by ASXCode order by ObservationDate desc) as RowNumber,
			avg(TradeValuePerc) over (partition by ASXCode order by ObservationDate asc rows 9 preceding) as AvgTradeValuePerc
		into #TempInstitutePercRank
		from #TempInstitutePerc

		select 
			a.ASXCode,
			left(cast(a.ObservationDate as varchar(50)), 10) as ObservationDate,
			a.VWAP,
			a.Quantity,
			a.TradeValue,
			--a.QuantityPerc,
			format(a.TradeValuePerc, 'N1') as [Value%],
			format(a.AvgTradeValuePerc, 'N1') as [AvgValue%],
			cast(cast(a.PriceChangeVsPrevClose as decimal(10, 2)) as varchar(10)) + '%' as VsPrevClose,
			format(b.TradeValuePerc, 'N1') as [InstituteBuy%], 
			format(c.TradeValuePerc, 'N1') as [RetailBuy%],
			b.VWAP as InstituteBuyVWAP, 
			c.VWAP as RetailBuyVWAP,
			format(b1.TradeValuePerc, 'N1') as [InstituteSell%], 
			format(c1.TradeValuePerc, 'N1') as [RetailSell%],
			b1.VWAP as InstituteSellVWAP, 
			c1.VWAP as RetailSellVWAP,
			--'|' as Divider,
			--y.TotalVWAP,
			--y.ChixVWAP,
			--y.ASXVWAP,
			--y.CHIXPerc,
			--y.AvgCHIXPerc,
			--y.TotalValue,
			--y.AnnDescr as Announcement,
			m2.BrokerCode as RecentTopBuyBroker,
			n2.BrokerCode as RecentTopSellBroker,
			ann.AnnDescr as [Announcement],
			ttsu.FriendlyNameList
		from #TempInstitutePercRank as a
		left join #TempDerivedInstitutePerformance as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and b.ActBuySellInd = 'B'
		and b.DerivedInstitute = 1
		left join #TempDerivedInstitutePerformance as b1
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b1.ObservationDate
		and b1.ActBuySellInd = 'S'
		and b1.DerivedInstitute = 1
		left join #TempDerivedInstitutePerformance as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and c.ActBuySellInd = 'B'
		and c.DerivedInstitute = 0
		left join #TempDerivedInstitutePerformance as c1
		on a.ASXCode = c1.ASXCode
		and a.ObservationDate = c1.ObservationDate
		and c1.ActBuySellInd = 'S'
		and c1.DerivedInstitute = 0
		left join #TempBrokerReportListLastNDay as m2
		on a.ASXCode = m2.ASXCode
		and a.ObservationDate = m2.ObservationDate
		left join #TempBrokerReportListNegLastNDay as n2
		on a.ASXCode = n2.ASXCode
		and a.ObservationDate = n2.ObservationDate
		left join Transform.TTSymbolUser as ttsu with(nolock)
		on a.ASXCode = ttsu.ASXCode
		left join [Transform].[v_Announcement] as ann with(nolock)
		on a.ASXCode = ann.ASXCode
		and a.ObservationDate = ann.ObservationDate
		where 1 = 1
		order by a.ObservationDate desc;

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