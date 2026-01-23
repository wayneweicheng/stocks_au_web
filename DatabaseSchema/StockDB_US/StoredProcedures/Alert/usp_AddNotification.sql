-- Stored procedure: [Alert].[usp_AddNotification]


CREATE PROCEDURE [Alert].[usp_AddNotification]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddNotification.sql
Stored Procedure Name: usp_AddNotification
Overview
-----------------
usp_AddNotification

Input Parameters
----------------2
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddNotification'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Alert'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--declare @intNumPrevDay as int = 125
		declare @pvchEmailRecipient as varchar(200)
		declare @pvchEmailSubject as varchar(200)
		declare @pvchEmailBody as varchar(500)
		declare @intTradingAlertID as int
		
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

		--ALERT TYPE ID 1, 2, 3, 4
		select top 1
			@intTradingAlertID = a.TradingAlertID,
			@pvchEmailSubject = a.ASXCode + '-' + cast(b.TradingAlertTypeID as varchar(10)),
			@pvchEmailBody = a.ASXCode + '>>'  + 'Alert: ' + cast(b.TradingAlertType as varchar(50)) + '
' + 'Alert Price: ' + cast(isnull(a.AlertPrice, 999) as varchar(50)) + '
' + 'Actual Price: ' + cast(isnull(a.ActualPrice, 999) as varchar(50)) + '
' + 'MC: ' + isnull(cast(cast(c.MC as decimal(8, 2)) as varchar(50)), '') + '
' + 'Cash: ' + isnull(cast(cast(c.CashPosition as decimal(8, 2)) as varchar(50)), '')
		from Alert.v_TradingAlert as a
		inner join LookupRef.TradingAlertType as b
		on a.TradingAlertTypeID = b.TradingAlertTypeID
		left join #TempCashVsMC as c
		on a.ASXCode = c.ASXCode
		where a.NotificationSentDate is null
		and a.AlertTriggerDate is not null
		and a.TradingAlertTypeID in (1, 2, 3, 4)
		order by a.CreateDate desc

		select @pvchEmailRecipient = '61430710008@sms.messagebird.com'

		if @pvchEmailSubject is not null
		begin
			EXECUTE [Utility].[usp_AddEmail] 
				 @pvchEmailRecipient = @pvchEmailRecipient
				,@pvchEmailSubject = @pvchEmailSubject
				,@pvchEmailBody = @pvchEmailBody
				,@pintEventTypeID = 1
		end

		update a
		set NotificationSentDate = getdate()
		from Alert.TradingAlert as a
		where TradingAlertID = @intTradingAlertID

		select @pvchEmailSubject = null
		select @pvchEmailBody = null

		--ALERT TYPE ID 5
		select top 1
			@intTradingAlertID = a.TradingAlertID,
			@pvchEmailSubject = a.ASXCode + '-' + cast(b.TradingAlertTypeID as varchar(10)),
			@pvchEmailBody = a.ASXCode + '>>'  + 'Alert: ' + cast(b.TradingAlertType as varchar(50)) + '
' + 'Alert Volume: ' + cast(a.AlertPrice as varchar(50)) + '
' + 'Actual Volume: ' + cast(a.ActualPrice as varchar(50)) + '
' + 'MC: ' + isnull(cast(cast(c.MC as decimal(8, 2)) as varchar(50)), '') + '
' + 'Cash: ' + isnull(cast(cast(c.CashPosition as decimal(8, 2)) as varchar(50)), '')
		from Alert.TradingAlert as a
		inner join LookupRef.TradingAlertType as b
		on a.TradingAlertTypeID = b.TradingAlertTypeID
		left join #TempCashVsMC as c
		on a.ASXCode = c.ASXCode
		where a.NotificationSentDate is null
		and a.AlertTriggerDate is not null
		and a.TradingAlertTypeID in (5)
		order by a.CreateDate desc

		select @pvchEmailRecipient = '61430710008@sms.messagebird.com'

		if @pvchEmailSubject is not null
		begin
			EXECUTE [Utility].[usp_AddEmail] 
				 @pvchEmailRecipient = @pvchEmailRecipient
				,@pvchEmailSubject = @pvchEmailSubject
				,@pvchEmailBody = @pvchEmailBody
				,@pintEventTypeID = 1
		end

		update a
		set NotificationSentDate = getdate()
		from Alert.TradingAlert as a
		where TradingAlertID = @intTradingAlertID

		select @pvchEmailSubject = null
		select @pvchEmailBody = null

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
