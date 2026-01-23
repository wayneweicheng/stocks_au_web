-- Stored procedure: [StockData].[usp_MoneyFlowReport_Sector]






CREATE PROCEDURE [StockData].[usp_MoneyFlowReport_Sector]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTokenID varchar(20),
@pbitIsMobile as bit = 0
AS
/******************************************************************************
File: usp_MoneyFlowReport_Sector.sql
Stored Procedure Name: usp_MoneyFlowReport_Sector
Overview
-----------------

Input ParametersW
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
Date:		2021-09-29
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MoneyFlowReport_Sector'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;
		--declare @pvchTokenID as int = 48
		--declare @pbitIsMobile as int = 0

		declare @numDaysToShow as int = 0
		if @pbitIsMobile = 1
			select @numDaysToShow = 60
		else
			select @numDaysToShow = 120

		if object_id(N'Tempdb.dbo.#TempTokenPerformance') is not null
			drop table #TempTokenPerformance

		select *
		into #TempTokenPerformance
		from
		(
			select a.*, row_number() over (order by ObservationDate desc) as DateRank
			from Report.SectorPerformance as a
			inner join LookupRef.KeyToken as b
			on a.Token = b.Token
			and b.TokenID = cast(@pvchTokenID as int)
			and MAAvgHoldKey = 'SMA0'
		) as a
		where DateRank < @numDaysToShow

		select distinct
			--@pvchTokenID as ASXCode,
			left(cast(a.ObservationDate as varchar(50)), 10) as MarketDate,
			0 as MoneyFlowAmount,
			TradeValue/2000000 as MoneyFlowAmountIn,
			TradeValue/2000000 as MoneyFlowAmountOut,
			0 as CumulativeMoneyFlowAmount,
			cast(isnull(b.NetValue/1000.0, 0) as int) as StrongBrokerNet,
			cast(isnull(c.NetValue/1000.0, 0) as int) as WeakBrokerNet,
			cast(isnull(d.NetValue/1000.0, 0) as int) as OtherRetailNet,
			cast(isnull(e.NetValue/1000.0, 0) as int) as FlipperBrokerNet,
			cast(isnull(f.NetValue/1000.0, 0) as int) as ComSecNet,
			0 as PriceChangePerc,
			0 as InPerc,
			0 as OutPerc,
			0 as InNumTrades,
			0 as OutNumTrades,			
			0 as InAvgSize,
			0 as OutAvgSize,
			0 as [Open],
			0 as [High],
			0 as [Low],
			0 as [Close],
			HoldValue as [VWAP],
			0 as [Volume],
			0 as [Value],
			0 as NetVolume,
			DateRank as RowNumber
		from #TempTokenPerformance as a
		left join Transform.BrokerRetailNetSector as b
		on a.Token = b.Token
		and a.ObservationDate = b.ObservationDate
		and b.BrokerRetailNet = 'StrongBroker'
		left join Transform.BrokerRetailNetSector as c
		on a.Token = c.Token
		and a.ObservationDate = c.ObservationDate
		and c.BrokerRetailNet = 'WeakBroker'
		left join Transform.BrokerRetailNetSector as d
		on a.Token = d.Token
		and a.ObservationDate = d.ObservationDate
		and d.BrokerRetailNet = 'OtherRetail'
		left join Transform.BrokerRetailNetSector as e
		on a.Token = e.Token
		and a.ObservationDate = e.ObservationDate
		and e.BrokerRetailNet = 'FlipperBroker'
		left join Transform.BrokerRetailNetSector as f
		on a.Token = f.Token
		and a.ObservationDate = f.ObservationDate
		and f.BrokerRetailNet = 'ComSec'
		left join Transform.BrokerRetailNetSector as g
		on a.Token = g.Token
		and a.ObservationDate = g.ObservationDate
		order by DateRank desc

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
