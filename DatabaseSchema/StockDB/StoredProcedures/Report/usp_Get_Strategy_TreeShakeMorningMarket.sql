-- Stored procedure: [Report].[usp_Get_Strategy_TreeShakeMorningMarket]


CREATE PROCEDURE [Report].[usp_Get_Strategy_TreeShakeMorningMarket]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay AS INT = 0,
@pbitASXCodeOnly as bit = 0
AS
/******************************************************************************
File: usp_Get_Strategy_TreeShakeMorningMarket.sql
Stored Procedure Name: usp_Get_Strategy_TreeShakeMorningMarket
Overview
-----------------
usp_Get_Strategy_TreeShakeMorningMarket

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
Date:		2020-01-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_Strategy_TreeShakeMorningMarket'
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
		--declare @pintNumPrevDay as int = 27
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempStockTickSaleVsBidAsk') is not null
			drop table #TempStockTickSaleVsBidAsk
		select 
			ASXCode, 
			ObservationDate,
			DerivedInstitute, 
			DerivedBuySellInd, 
			count(*) as NumTrades, 
			sum(Quantity) as Quantity,
			sum(SaleValue) as SaleValue,
			format(sum(Quantity), 'N0') as FormatQuantity, 
			format(sum(SaleValue), 'N0') as FormatSaleValue, 
			cast(sum(SaleValue)*1.0/sum(Quantity) as decimal(10,3)) as VWAP
		into #TempStockTickSaleVsBidAsk
		from Transform.StockTickSaleVsBidAsk
		where ASXCode is not null
		and ObservationDate = @dtObservationDate
		group by ASXCode, ObservationDate, DerivedBuySellInd, DerivedInstitute
		having sum(Quantity) > 0
		order by ASXCode, ObservationDate, DerivedInstitute, DerivedBuySellInd

		select top 1000 
			'Institute accumulate' as ReportType,
			phfg.[close],
			inb.ASXCode,
			inb.ObservationDate,
			inb.FormatSaleValue as inb_FormatSaleValue,
			ins.FormatSaleValue as ins_FormatSaleValue,
			reb.FormatSaleValue as reb_FormatSaleValue,
			res.FormatSaleValue as res_FormatSaleValue,
			inb.VWAP as inb_VWAP,
			ins.VWAP as ins_VWAP,
			reb.VWAP as reb_VWAP,
			res.VWAP as res_VWAP,
			case when phfg.[High] - phfg.[Low] = 0 then null else cast((phfg.[Close] - phfg.[Low])*100.0/(phfg.[High] - phfg.[Low]) as int) end as TodayBarStrength,
			phfg.[NextOpen] as NextOpen,
			case when phfg.[Close] > 0 then cast((phfg.[NextOpen] - phfg.[Close])*100.0/phfg.[Close] as decimal(10, 2)) end as OpenGapPerc,
			phfg.[NextLow] as NextLow,
			phfg.[NextHigh] as NextHigh,
			phfg.[NextClose] as NextClose,
			phfg.TodayChange, phfg.TomorrowChange, phfg.Next2DaysChange, phfg.Next5DaysChange,
			case when w.MovingAverage20d > w.PrevMovingAverage20d then 'Up' 
					when w.MovingAverage20d < w.PrevMovingAverage20d then 'Down' 
					else null
			end SMA20Trend,
			case when w.MovingAverage60d > w.PrevMovingAverage60d then 'Up' 
					when w.MovingAverage60d < w.PrevMovingAverage60d then 'Down' 
					else null
			end SMA60Trend
		from #TempStockTickSaleVsBidAsk as inb
		inner join #TempStockTickSaleVsBidAsk as reb
		on inb.ASXCode = reb.ASXCode
		inner join #TempStockTickSaleVsBidAsk as ins
		on ins.ASXCode = inb.ASXCode
		inner join #TempStockTickSaleVsBidAsk as res
		on ins.ASXCode = res.ASXCode
		left join [Transform].[PriceHistoryFutureGainLoss] as phfg
		on ins.ASXCode = phfg.ASXCode
		and ins.ObservationDate = phfg.ObservationDate
		left join StockData.StockStatsHistoryPlusTrend as w
		on inb.ASXCode = w.ASXCode
		and inb.ObservationDate = w.ObservationDate
		where 1 = 1
		--and ins.ASXCode = 'MSB.AX'
		and inb.DerivedInstitute = 1
		and inb.DerivedBuySellInd = 'B'
		and reb.DerivedInstitute = 0
		and reb.DerivedBuySellInd = 'B'
		and ins.DerivedInstitute = 1
		and ins.DerivedBuySellInd = 'S'
		and res.DerivedInstitute = 0
		and res.DerivedBuySellInd = 'S'
		and inb.SaleValue > 100000
		and inb.SaleValue > 0.75*reb.SaleValue
		and reb.SaleValue > 50000
		and isnull(phfg.[Close]*1.03, inb.VWAP) >= inb.VWAP
		--and inb.SaleValue > ins.SaleValue
		--and inb.VWAP < reb.VWAP
		--and phfg.TodayChange > 0
		--and inb.VWAP > ins.VWAP
		--and Next2DaysChange > 4
		order by inb.SaleValue desc

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
