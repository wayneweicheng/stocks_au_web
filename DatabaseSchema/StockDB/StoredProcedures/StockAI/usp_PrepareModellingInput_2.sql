-- Stored procedure: [StockAI].[usp_PrepareModellingInput_2]


CREATE PROCEDURE [StockAI].[usp_PrepareModellingInput_2]
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
		select 
			a.ObservationDate, 
			a.Dix, 
			--a.Prev1Dix, 
			--case when a.SwingIndicator = 'swing up' then 1 when a.SwingIndicator = 'swing down' then 0 else -1 end as SqueezeMetrixSwingIndicator,
			b.CLV300B,
			b.PrevCLV300B,
			--b.CLV10B,
			--b.PrevCLV10B,
			--b.CLV1B,
			--b.PrevCLV1B,
			c.[Close] as OilClose,
			d.[Close] as EURUSD,
			e.[Close] as VIXClose,
			f.[Close] as GoldClose,
			g.[Close] as BOND10YClose,
			case when y.Next2DaysChange > 0 then 1 else 0 end as FutureChange
			--y.Next2DaysChange,
			--y.Next5DaysChange
		from
		(
			select format(GEX, 'N0') as FormattedGEX, * from StockData.v_DarkPoolIndex
			where IndexCode = 'SPX'
		) as a
		inner join
		(
			select 
				a.ObservationDate,
				a.CLV as CLV300B,
				a.PrevCLV as PrevCLV300B,
				b.CLV as CLV10B,
				b.PrevCLV as PrevCLV10B,
				c.CLV as CLV1B,
				c.PrevCLV as PrevCLV1B
			from
			(
				select ObservationDate, CLV, lag(CLV) over (partition by MarketCap order by ObservationDate asc) as PrevCLV
				from StockDB_US.Transform.MarketCLVTrend
				where MarketCap in (
				'h. 300B+'
				)
			) as a
			inner join
			(
				select ObservationDate, CLV, lag(CLV) over (partition by MarketCap order by ObservationDate asc) as PrevCLV
				from StockDB_US.Transform.MarketCLVTrend
				where MarketCap in (
				'g. 10B+'
				)
			) as b
			on a.ObservationDate = b.ObservationDate
			inner join
			(
				select ObservationDate, CLV, lag(CLV) over (partition by MarketCap order by ObservationDate asc) as PrevCLV
				from StockDB_US.Transform.MarketCLVTrend
				where MarketCap in (
				'f. 1B+'
				)
			) as c
			on a.ObservationDate = c.ObservationDate
			where a.PrevCLV is not null
		) as b
		on a.ObservationDate = b.ObservationDate
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory
			where ASXCode in ('OIL')
		) as c
		on a.ObservationDate = c.ObservationDate
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory
			where ASXCode in ('EUR/USD')
		) as d
		on a.ObservationDate = d.ObservationDate
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory
			where ASXCode in ('VIX')
		) as e
		on a.ObservationDate = e.ObservationDate
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory
			where ASXCode in ('GOLD')
		) as f
		on a.ObservationDate = f.ObservationDate
		left join
		(
			select *
			from StockDB.StockData.v_PriceHistory
			where ASXCode in ('10YBOND')
		) as g
		on a.ObservationDate = g.ObservationDate
		left join
		(
			select *
			from StockData.v_PriceHistory
			where ASXCode = 'SPX'
		) as y
		on a.ObservationDate = y.ObservationDate
		where y.TomorrowChange is not null
		and B.CLV300B is not null
		
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