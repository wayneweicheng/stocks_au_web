-- Stored procedure: [DataMaintenance].[usp_RefreshBuyCloseSellOpen]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshBuyCloseSellOpen]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshBuyCloseSellOpen.sql
Stored Procedure Name: usp_RefreshBuyCloseSellOpen
Overview
-----------------
usp_RefreshBuyCloseSellOpen

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
Date:		2019-09-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshBuyCloseSellOpen'
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
		if object_id(N'Tempdb.dbo.#TempLast90Day') is not null
			drop table #TempLast90Day

		select case when PrevClose > 0 then ([Open] - PrevClose)*100.0/PrevClose else null end as OpenVsPrevClose, *
		into #TempLast90Day
		from [Transform].[v_PriceHistory]
		where ObservationDate > Common.DateAddBusinessDay(-90, getdate())
		and [Close] <  10;

		if object_id(N'StockData.BuyCloseSellOpen') is not null
			drop table StockData.BuyCloseSellOpen

		select 
			a.ASXCode, 
			cast(NumIncreasePrice*100.0/b.NumTotal as int) as IncreasePerc, 
			NumIncreasePrice, 
			b.NumTotal as NonFlatOpenTotal, 
			c.NumTotal, 
			AvgOpenVsPrevClose, 
			format(d.AvgCloseValue, 'N0') as AvgCloseValue,
			d.AvgCloseValue as AvgCloseValueDec,
			getdate() as RefreshDate
		into StockData.BuyCloseSellOpen
		from
		(
			select ASXCode, sum(case when OpenVsPrevClose > 0 then 1 else 0 end) as NumIncreasePrice, avg(case when OpenVsPrevClose = -100 then 0 else OpenVsPrevClose end) as AvgOpenVsPrevClose
			from #TempLast90Day
			where [Close] > 0.02
			group by ASXCode
		) as a
		inner join 
		(
			select ASXCode, sum(case when OpenVsPrevClose != 0 then 1 else 0 end) as NumTotal
			from #TempLast90Day
			where [Close] > 0.02
			group by ASXCode
			having sum(case when OpenVsPrevClose != 0 then 1 else 0 end) > 0
		) as b
		on a.ASXCode = b.ASXCode
		inner join 
		(
			select ASXCode, count(*) as NumTotal
			from #TempLast90Day
			group by ASXCode
			having sum(case when OpenVsPrevClose != 0 then 1 else 0 end) > 0
		) as c
		on a.ASXCode = c.ASXCode
		left join
		(
			select ASXCode, avg(ValueDelta) as AvgCloseValue
			from StockData.PriceSummary
			where DateTo is null
			and LatestForTheDay = 1
			and ValueDelta > 0
			and ObservationDate > Common.DateAddBusinessDay(-20, getdate())
			group by ASXCode
		) as d
		on a.ASXCode = d.ASXCode
		--where a.ASXCode = 'LKE.AX'
		where 1 = 1 
		--and a.ASXCode = 'MQR.AX'
		and b.NumTotal > 6
		and d.AvgCloseValue > 30000
		--and a.ASXCode = 'LKE.AX'
		and AvgOpenVsPrevClose > 0.50
		and NumIncreasePrice*100.0/b.NumTotal > 50
		order by NumIncreasePrice*100.0/b.NumTotal desc;

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
