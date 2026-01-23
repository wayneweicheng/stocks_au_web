-- Stored procedure: [AutoTrade].[usp_AddNotification]

CREATE PROCEDURE [AutoTrade].[usp_AddNotification]
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
Date:		2018-02-25
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
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'AutoTrade'
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
		declare @intTradeRequestID as int 

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
		right join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		--STRATEGY 1
		select top 1
			@intTradeRequestID = a.TradeRequestID,
			@pvchEmailSubject = a.ASXCode + '-S1',
			@pvchEmailBody = a.ASXCode + '>>'  + 'Poster: ' + cast(b.Poster as varchar(50)) + '
' + 'Price: ' + cast(a.Price as varchar(50)) + '
' + 'MC: ' + isnull(cast(cast(c.MC as decimal(8, 2)) as varchar(50)), '') + '
' + 'Cash: ' + isnull(cast(cast(c.CashPosition as decimal(8, 2)) as varchar(50)), '')
		from AutoTrade.TradeRequest as a
		inner join hc.QualityPoster as b
		on a.TradeStrategyMessage = b.Poster
		and a.TradeStrategyID = 1
		--and a.TradeRank < 10
		and a.TradeStrategyMessage in
		(
			'seagull',
			'specgoldbug',
			'mineralised',
			'Sector',
			'8horse',
			'Yoda',
			'eshmun',
			'TwinTurboCelica',
			'Goldbull22',
			'Quanta'
		)
		left join #TempCashVsMC as c
		on a.ASXCode = c.ASXCode
		where isnull(a.IsNotificationSent, 0) = 0
		and datediff(hour, a.CreateDate, getdate()) < 72
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

		select @pvchEmailRecipient = 'wayneweicheng@gmail.com'

		if @pvchEmailSubject is not null
		begin
			EXECUTE [Utility].[usp_AddEmail] 
				 @pvchEmailRecipient = @pvchEmailRecipient
				,@pvchEmailSubject = @pvchEmailSubject
				,@pvchEmailBody = @pvchEmailBody
				,@pintEventTypeID = 1
		end

		update a
		set IsNotificationSent = 1
		from AutoTrade.TradeRequest as a
		where TradeRequestID = @intTradeRequestID

		select @pvchEmailSubject = null

		--STRATEGY 2
		select top 1
			@intTradeRequestID = a.TradeRequestID,
			@pvchEmailSubject = a.ASXCode + '-S2',
			@pvchEmailBody = left(TradeStrategyMessage, 110)
		from AutoTrade.TradeRequest as a
		inner join hc.QualityPoster as b
		on a.TradeStrategyMessage = b.Poster
		and a.TradeStrategyID = 2
		left join #TempCashVsMC as c
		on a.ASXCode = c.ASXCode
		where a.IsNotificationSent = 0
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

		select @pvchEmailRecipient = 'wayneweicheng@gmail.com'

		if @pvchEmailSubject is not null
		begin
			EXECUTE [Utility].[usp_AddEmail] 
				 @pvchEmailRecipient = @pvchEmailRecipient
				,@pvchEmailSubject = @pvchEmailSubject
				,@pvchEmailBody = @pvchEmailBody
				,@pintEventTypeID = 1
		end


		update a
		set IsNotificationSent = 1
		from AutoTrade.TradeRequest as a
		where TradeRequestID = @intTradeRequestID

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
