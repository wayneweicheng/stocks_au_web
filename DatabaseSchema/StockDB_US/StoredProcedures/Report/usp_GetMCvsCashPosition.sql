-- Stored procedure: [Report].[usp_GetMCvsCashPosition]


--EXEC [Report].[usp_GetMCvsCashPosition]



CREATE PROCEDURE [Report].[usp_GetMCvsCashPosition]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode varchar(20) = null,
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_GetMCvsCashPosition.sql
Stored Procedure Name: usp_GetMCvsCashPosition
Overview
-----------------
usp_GetLineWipe

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
Date:		2017-04-29
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMCvsCashPosition'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchStockCode as varchar(10) = null
		--declare @pintNumPrevDay as int = 0

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

		--if object_id(N'Tempdb.dbo.#TempDirectorCurrent') is not null
		--	drop table #TempDirectorCurrent

		--select a.ASXCode, stuff((
		--	select ',' + [Name]
		--	from StockData.DirectorCurrent
		--	where ASXCode = a.ASXCode
		--	order by Surname desc
		--	for xml path('')), 1, 1, ''
		--) as DirName
		--into #TempDirectorCurrent
		--from StockData.DirectorCurrent as a
		--group by a.ASXCode

		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select a.*
		into #TempPriceSummary
		from StockData.v_PriceSummary as a
		where ObservationDate = Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate())
		and DateTo is null

		select 
			a.ASXCode,
			coalesce(cast(k.SharesIssued*h.[Close] as decimal(8, 2)), l.CleansedMarketCap) as MC,
			k.FloatingShares,
			k.FloatingSharesPerc,
			cast(a.CashPosition as decimal(8, 2)) CashPosition,
			cast(m.MedianTradeValue as int) as MedianTradeValueWeekly,
			cast(m.MedianTradeValueDaily as int) as MedianTradeValueDaily,
			m.MedianPriceChangePerc,
			cast(n.RelativePriceStrength as decimal(10, 2)) as RelativePriceStrength,
			cast(h.[Value]/1000.0 as decimal(10, 2)) as [Value in K],
			cast((h.[Close] - e.[Close])*100.0/e.[close] as decimal(10, 2)) as ChangePerc,
			cast(h.[Value]/(cast(a.MC as decimal(8, 2))*10000) as decimal(5, 2)) as ValueOverMC,
			l.ScanDayTradeInfoUrl as FurtherDetails,
			--l.BusinessDetails,
			l.EPS,
			l.IndustryGroup,
			l.IndustrySubGroup,
			g.MediumTermRetailParticipationRate,
			g.ShortTermRetailParticipationRate,
			l.LastValidateDate,
			i.Poster
		--into MAWork.dbo.StockInsight
		from #TempCashVsMC as a
		left join #TempStockNature as d
		on a.ASXCode = d.ASXCode
		left join [StockData].[PriceHistoryCurrent] as e
		on a.ASXCode = e.ASXCode
		left join HC.HeadPostSummary as f
		on a.ASXCode = f.ASXCode
		left join #TempPriceSummary as h
		on a.ASXCode = h.ASXCode
		left join Transform.PosterList as i
		on a.ASXCode = i.ASXCode
		left join StockData.PriceHistoryCurrent as j
		on a.ASXCode = j.ASXCode
		left join StockData.v_CompanyFloatingShare as k
		on a.ASXCode = k.ASXCode
		left join StockData.CompanyInfo as l
		on a.ASXCode = l.ASXCode
		left join StockData.MedianTradeValue as m
		on a.ASXCode = m.ASXCode
		left join StockData.v_RelativePriceStrength as n
		on a.ASXCode = n.ASXCode
		left join StockData.RetailParticipation as g
		on a.ASXCode = g.ASXCode
		where (@pvchStockCode is null or a.ASXCode = @pvchStockCode)
		order by cast(h.[Value]/(cast(a.MC as decimal(8, 2))*10000) as decimal(5, 2)) desc

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
