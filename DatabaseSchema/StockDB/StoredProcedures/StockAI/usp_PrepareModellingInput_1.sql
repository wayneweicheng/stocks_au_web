-- Stored procedure: [StockAI].[usp_PrepareModellingInput_1]


CREATE PROCEDURE [StockAI].[usp_PrepareModellingInput_SPX]
@pbitDebug AS BIT = 0,
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
		--declare @pvchBrokerCode as varchar(20) = 'pershn'
		--Code goes here 	
		if object_id(N'Tempdb.dbo.#TempCBOEPutCallRatio') is not null
			drop table #TempCBOEPutCallRatio

		;with putcallratio as
		(
			select *
			from StockData.CBOEPutCallRatio
			where datediff(day, cboe_date, getdate()) <  365
		)

		select
			y.cboe_date,
			cast(norm_etp_put_call_ratio as decimal(10, 2)) as norm_etp_put_call_ratio,
			cast(norm_equity_put_call_ratio as decimal(10, 2)) as norm_equity_put_call_ratio,
			cast(case when y.index_put_call_ratio_SMA20 is not null then (y.index_put_call_ratio - y.index_put_call_ratio_SMA20)*100.0/y.index_put_call_ratio_SMA20 end as decimal(10, 2)) as index_put_call_ratio_VarianceToSMA20,
			cast(case when y.etp_put_call_ratio_SMA20 is not null then (y.etp_put_call_ratio - y.etp_put_call_ratio_SMA20)*100.0/y.etp_put_call_ratio_SMA20 end as decimal(10, 2)) as etp_put_call_ratio_VarianceToSMA20,
			cast(case when y.equity_put_call_ratio_SMA20 is not null then (y.equity_put_call_ratio - y.equity_put_call_ratio_SMA20)*100.0/y.equity_put_call_ratio_SMA20 end as decimal(10, 2)) as equity_put_call_ratio_VarianceToSMA20, 
			etp_put_call_ratio,
			equity_put_call_ratio
		into #TempCBOEPutCallRatio
		from
		(
			select 
				*,
				cast(avg(index_put_call_ratio) over (order by cboe_date asc rows 20 preceding) as decimal(10, 2)) as index_put_call_ratio_SMA20,
				cast(avg(etp_put_call_ratio) over (order by cboe_date asc rows 20 preceding) as decimal(10, 2)) as etp_put_call_ratio_SMA20,
				cast(avg(equity_put_call_ratio) over (order by cboe_date asc rows 20 preceding) as decimal(10, 2)) as equity_put_call_ratio_SMA20,
				(etp_put_call_ratio - (select min(etp_put_call_ratio) from putcallratio))/((select max(etp_put_call_ratio) from putcallratio) - (select min(etp_put_call_ratio) from putcallratio)) as norm_etp_put_call_ratio,
				(equity_put_call_ratio - (select min(equity_put_call_ratio) from putcallratio))/((select max(equity_put_call_ratio) from putcallratio) - (select min(equity_put_call_ratio) from putcallratio)) as norm_equity_put_call_ratio
			from putcallratio as a
			where 1 = 1
		) as y
		order by 1 desc;

		select 
			a.ObservationDate, a.GEX as SPXGEX, a.Prev1GEX as Prev1SPXGEX, 
			a.Dix, a.Prev1Dix, case when a.SwingIndicator = 'swing up' then 1 when a.SwingIndicator = 'swing down' then 0 else -1 end as SqueezeMetrixSwingIndicator,
			b.InflowValueInM, b.NormInflowValueInM,
			c.norm_equity_put_call_ratio, c.norm_etp_put_call_ratio,
			d.CLV as SPXCLV, d.PrevCLV as Prev1SPXCLV,
			e.CLV as NASDAQCLV, e.PrevCLV as Prev1NASDAQCLV,
			f.GEX as GEX_SPY,
			g.GEX as GEX_QQQ,
			h.GEX as GEX_IWM,
			i.GEX as GEX_DIA,
			case when y.TomorrowChange > 0 then 1 else 0 end as FutureChange
			--y.Next2DaysChange,
			--y.Next5DaysChange
		from
		(
			select format(GEX, 'N0') as FormattedGEX, * from StockData.v_DarkPoolIndex
			where IndexCode = 'SPX'
		) as a
		inner join
		(
			select * from StockData.v_InverseEquityETF_Norm
			where EquityCode = 'SH'
		) as b
		on a.ObservationDate = b.NAVDate
		left join
		(
			select * from #TempCBOEPutCallRatio
		) as c
		on a.ObservationDate = c.cboe_date
		left join
		(
			select * from StockDB_US.Transform.v_MarketPotentialReverseByCLV_SPX
		) as d
		on a.ObservationDate = d.ObservationDate
		left join
		(
			select * from StockDB_US.Transform.v_MarketPotentialReverseByCLV_NASDAQ
		) as e
		on a.ObservationDate = e.ObservationDate
		left join
		(
			select *
			from StockDB_US.StockData.v_CalculatedGEX
			where ASXCode in ('SPY.US')
		) as f
		on a.ObservationDate = f.ObservationDate
		left join
		(
			select *
			from StockDB_US.StockData.v_CalculatedGEX
			where ASXCode in ('QQQ.US')
		) as g
		on a.ObservationDate = g.ObservationDate
		left join
		(
			select *
			from StockDB_US.StockData.v_CalculatedGEX
			where ASXCode in ('IWM.US')
		) as h
		on a.ObservationDate = h.ObservationDate
		left join
		(
			select *
			from StockDB_US.StockData.v_CalculatedGEX
			where ASXCode in ('DIA.US')
		) as i
		on a.ObservationDate = i.ObservationDate
		left join
		(
			select *
			from StockData.v_PriceHistory
			where ASXCode = 'SPX'
		) as y
		on a.ObservationDate = y.ObservationDate
		where y.TomorrowChange is not null
		and f.GEX is not null
		
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