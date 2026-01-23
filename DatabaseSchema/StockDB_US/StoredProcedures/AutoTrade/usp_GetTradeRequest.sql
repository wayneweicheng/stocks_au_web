-- Stored procedure: [AutoTrade].[usp_GetTradeRequest]


CREATE PROCEDURE [AutoTrade].[usp_GetTradeRequest]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pintTradeRequestId as int
AS
/******************************************************************************
File: usp_GetTradeRequest.sql
Stored Procedure Name: usp_GetTradeRequest
Overview
-----------------
usp_GetTradeRequest

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
Date:		2015-11-10
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2021-01-02
Author:		WAYNE CHENG
Description: Add in parameter @pintTradeRequestId
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTradeRequest'
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
		--begin transaction
		if object_id(N'Tempdb.dbo.#TempTradeRequest') is not null
			drop table #TempTradeRequest

		select top 1
		   TradeRequestID
		  ,[ASXCode]
		  ,substring(ASXCode, 1, charindex('.', ASXCode, 0) - 1) as StockCode
		  ,BuySellFlag
		  ,[Price]
		  ,isnull([StopLossPrice], -1) as [StopLossPrice]
		  ,isnull([StopProfitPrice], -1) as [StopProfitPrice]
		  ,[MinVolume]
		  ,[MaxVolume]
		  ,[RequestValidTimeFrameInMin]
		  ,[RequestValidUntil]
		  ,[CreateDate]
		  ,[LastTryDate]
		  ,[OrderPlaceDate]
		  ,[OrderPlaceVolume]
		  ,OrderReceiptID
		  ,[OrderFillDate]
		  ,[OrderFillVolume]
		  ,[RequestStatus]
		  ,[RequestStatusMessage]
		  ,[PreReqTradeRequestID]
		  ,TradeRank
		  ,TradeAccountName
		into #TempTradeRequest
		from AutoTrade.TradeRequest as a
		where RequestStatus = 'R'
		and RequestValidUntil > getdate()
		and ASXCode = @pvchASXCode
		and TradeRequestID =  @pintTradeRequestId 
		and isnull(ErrorCount, 0) < 5
		and not exists(
			select 1
			from AutoTrade.RequestProcessHistory
			where AccountNumber = a.AccountNumber
			and TradeRequestID = a.TradeRequestID
		)
		and not exists(
			select 1
			from AutoTrade.RequestProcessHistory
			where TradeRequestID = a.TradeRequestID
			and datediff(second, CreateDate, getdate()) < 300
		)
		order by TradeRank, CreateDate desc

		insert into AutoTrade.RequestProcessHistory
		(
			TradeRequestID,
			ProcessTypeID,
			AccountNumber,
			CreateDate
		)		
		select
			TradeRequestID as TradeRequestID,
			1 as ProcessTypeID,
			null as AccountNumber,
			getdate() as CreateDate
		from #TempTradeRequest

		select 
		   TradeRequestID
		  ,[ASXCode]
		  ,StockCode
		  ,BuySellFlag
		  ,[Price]
		  ,[StopLossPrice]
		  ,[StopProfitPrice]
		  ,[MinVolume]
		  ,[MaxVolume]
		  ,[RequestValidTimeFrameInMin]
		  ,[RequestValidUntil]
		  ,[CreateDate]
		  ,[LastTryDate]
		  ,[OrderPlaceDate]
		  ,[OrderPlaceVolume]
		  ,OrderReceiptID
		  ,[OrderFillDate]
		  ,[OrderFillVolume]
		  ,[RequestStatus]
		  ,[RequestStatusMessage]
		  ,[PreReqTradeRequestID]
		  ,TradeRank
		  ,TradeAccountName
		from #TempTradeRequest

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
