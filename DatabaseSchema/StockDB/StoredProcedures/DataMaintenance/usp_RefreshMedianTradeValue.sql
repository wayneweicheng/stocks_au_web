-- Stored procedure: [DataMaintenance].[usp_RefreshMedianTradeValue]



CREATE PROCEDURE [DataMaintenance].[usp_RefreshMedianTradeValue]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 0
AS
/******************************************************************************
File: usp_RefreshMedianTradeValue.sql
Stored Procedure Name: usp_RefreshMedianTradeValue
Overview
-----------------
usp_RefreshMedianTradeValue

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
Date:		2022-01-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshMedianTradeValue'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		declare @dtObservationDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

		if object_id(N'Tempdb.dbo.#TempMedianTradeValue') is not null
			drop table #TempMedianTradeValue

		select distinct
			ASXCode, 
			PERCENTILE_CONT(0.5) 
				WITHIN GROUP (ORDER BY ([Close]*Volume)/1000.0) OVER ( 
				PARTITION BY ASXCODE) AS MedianTradeValue
		into #TempMedianTradeValue
		from StockData.PriceHistoryWeekly 
		--where Common.DateAddBusinessDay(-1 * 60, @dtObservationDate) < WeekOpenDate
		where dateadd(day, -1 * 60, @dtObservationDate) < WeekOpenDate
		and NumTradeDay >= 4
		and ASXCode not in ('NASDAQ', 'DJIA', 'SPX')
		order by MedianTradeValue desc

		if object_id(N'Tempdb.dbo.#TempMedianTradeValueDaily') is not null
			drop table #TempMedianTradeValueDaily

		select distinct
			ASXCode, 
			PERCENTILE_CONT(0.5) 
				WITHIN GROUP (ORDER BY ([Close]*Volume)/1000.0) OVER ( 
				PARTITION BY ASXCODE) AS MedianTradeValue
		into #TempMedianTradeValueDaily
		from StockData.PriceHistory
		--where Common.DateAddBusinessDay(-1 * 20, @dtObservationDate) < ObservationDate
		where dateadd(day, -1 * 20, @dtObservationDate) < ObservationDate		
		and ASXCode not in ('NASDAQ', 'DJIA', 'SPX')
		and Volume > 0
		order by MedianTradeValue desc

		if object_id(N'Tempdb.dbo.#TempPriceChangePerc') is not null
			drop table #TempPriceChangePerc

		select distinct
			ASXCode, 
			PERCENTILE_CONT(0.5) 
				WITHIN GROUP (ORDER BY PriceChange) OVER ( 
				PARTITION BY ASXCODE) AS PriceChangePerc
		into #TempPriceChangePerc
		from 
		(
			select *, cast(abs(([close]-[open])*100.0/[close]) as decimal(10, 2)) as PriceChange
			from StockData.PriceHistory
			where 1 = 1
			and Volume > 0
			and [Close] > 0
		) as a
		--where Common.DateAddBusinessDay(-1 * 60, @dtObservationDate) < ObservationDate
		where dateadd(day, -1 * 60, @dtObservationDate) < ObservationDate
		and Volume > 0
		and [Close] > 0
		order by PriceChangePerc desc

		truncate table StockData.MedianTradeValue

		insert into StockData.MedianTradeValue
		(
			ASXCode,
			MedianTradeValue,
			CleansedMarketCap
		)
		select 
			a.*, 
			b.CleansedMarketCap
		from #TempMedianTradeValue as a
		left join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		order by MedianTradeValue desc

		update a
		set a.MedianTradeValueDaily = b.MedianTradeValue
		from StockData.MedianTradeValue as a
		inner join #TempMedianTradeValueDaily as b
		on a.ASXCode = b.ASXCode

		update a
		set a.MedianPriceChangePerc = b.PriceChangePerc
		from StockData.MedianTradeValue as a
		inner join #TempPriceChangePerc as b
		on a.ASXCode = b.ASXCode

		delete a
		from StockData.MedianTradeValueHistory as a
		where ObservationDate = @dtObservationDate

		insert into StockData.MedianTradeValueHistory
		(
			ObservationDate,
			[ASXCode],
			[MedianTradeValue],
			[CleansedMarketCap],
			[MedianTradeValueDaily],
			[MedianPriceChangePerc],
			CreateDate
		)
		select
			@dtObservationDate as ObservationDate,
			[ASXCode],
			[MedianTradeValue],
			[CleansedMarketCap],
			[MedianTradeValueDaily],
			[MedianPriceChangePerc],
			getdate() as CreateDate
		from StockData.MedianTradeValue


	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
