-- Stored procedure: [StockAPI].[usp_AddIBTickerDetailsForStock]


CREATE PROCEDURE [StockAPI].[usp_AddIBTickerDetailsForStock]
@pvchASXCode as varchar(10), 
@pdtCurrentTime as datetime, 
@pvchTickerJson varchar(max),
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddIBTickerDetailsForStock.sql
Stored Procedure Name: usp_AddIBTickerDetailsForStock
Overview
-----------------
usp_AddIBTickerDetailsForStock

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
Date:		2021-06-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddIBTickerDetailsForStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockAPI'
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
		insert into [StockData].[StockTickerDetail]
		(
		   [ASXCode]
		  ,[CurrentTime]
		  ,ObservationDate
		  ,TickerJson
		  ,CreateDate
		)
		select
			@pvchASXCode, 
			@pdtCurrentTime,
			cast(@pdtCurrentTime as date) as [ObservationDate],
			@pvchTickerJson,
			getdate() as [CreateDate]
		
		declare @intRowNumber as int
		set @intRowNumber = @@IDENTITY

		insert into [StockData].[StockTickerDetailsParsed]
		(
		   [ASXCode]
		  ,[CurrentTime]
		  ,[ObservationDate]
		  ,[CreateDate]
		  ,[exchange]
		  ,[bid]
		  ,[bidSize]
		  ,[ask]
		  ,[askSize]
		  ,[last]
		  ,[lastSize]
		  ,[prevBid]
		  ,[prevBidSize]
		  ,[prevAsk]
		  ,[prevAskSize]
		  ,[prevLast]
		  ,[prevLastSize]
		  ,[volume]
		  ,[open]
		  ,[high]
		  ,[low]
		  ,[close]
		  ,[vwap]
		  ,[markPrice]
		  ,[halted]
		  ,[rtVolume]
		  ,[rtTradeVolume]
		  ,[auctionVolume]
		  ,[auctionPrice]
		  ,[auctionImbalance]
		)
		select
			a.ASXCode,
			a.CurrentTime,
			a.ObservationDate,
			a.CreateDate,
			json_value(TickerJson, '$.contract.exchange') as exchange,
			json_value(TickerJson, '$.bid') as bid,
			floor(json_value(TickerJson, '$.bidSize')) as bidSize,
			json_value(TickerJson, '$.ask') as ask,
			floor(json_value(TickerJson, '$.askSize')) as askSize,
			json_value(TickerJson, '$.last') as last,
			floor(json_value(TickerJson, '$.lastSize')) as lastSize,
			json_value(TickerJson, '$.prevBid') as prevBid,
			floor(json_value(TickerJson, '$.prevBidSize')) as prevBidSize,
			json_value(TickerJson, '$.prevAsk') as prevAsk,
			floor(json_value(TickerJson, '$.prevAskSize')) as prevAskSize,
			json_value(TickerJson, '$.prevLast') as prevLast,
			floor(json_value(TickerJson, '$.prevLastSize')) as prevLastSize,
			floor(json_value(TickerJson, '$.volume')) as volume,
			json_value(TickerJson, '$.open') as [open],
			json_value(TickerJson, '$.high') as [high],
			json_value(TickerJson, '$.low') as [low],
			json_value(TickerJson, '$.close') as [close],
			json_value(TickerJson, '$.vwap') as [vwap],
			json_value(TickerJson, '$.markPrice') as [markPrice],
			json_value(TickerJson, '$.halted') as [halted],
			floor(json_value(TickerJson, '$.rtVolume')) as [rtVolume],
			floor(json_value(TickerJson, '$.rtTradeVolume')) as [rtTradeVolume],
			floor(json_value(TickerJson, '$.auctionVolume')) as [auctionVolume],
			json_value(TickerJson, '$.auctionPrice') as [auctionPrice],
			floor(json_value(TickerJson, '$.auctionImbalance')) as [auctionImbalance]
		from [StockData].[StockTickerDetail] as a
		where 1 = 1
		and isjson(TickerJson)=1
		and StockTickerDetailID = @intRowNumber;


		insert into [StockData].[StockBidAsk]
		(
			 [ASXCode]
			,[ObservationTime]
			,[PriceBid]
			,[SizeBid]
			,[PriceAsk]
			,[SizeAsk]
			,[ObservationDate]
			,[CreateDateTime]
			,[UpdateDateTime]
		)
		select
			 [ASXCode]
			,CurrentTime as [ObservationTime]
			,bid as [PriceBid]
			,bidSize as [SizeBid]
			,ask as [PriceAsk]
			,askSize as [SizeAsk]
			,[ObservationDate]
			,CreateDate as [CreateDateTime]
			,CreateDate as [UpdateDateTime]
		from (
			select
				a.ASXCode,
				a.CurrentTime,
				a.ObservationDate,
				a.CreateDate,
				json_value(TickerJson, '$.contract.exchange') as exchange,
				json_value(TickerJson, '$.bid') as bid,
				floor(json_value(TickerJson, '$.bidSize')) as bidSize,
				json_value(TickerJson, '$.ask') as ask,
				floor(json_value(TickerJson, '$.askSize')) as askSize,
				json_value(TickerJson, '$.last') as last,
				floor(json_value(TickerJson, '$.lastSize')) as lastSize,
				json_value(TickerJson, '$.prevBid') as prevBid,
				floor(json_value(TickerJson, '$.prevBidSize')) as prevBidSize,
				json_value(TickerJson, '$.prevAsk') as prevAsk,
				floor(json_value(TickerJson, '$.prevAskSize')) as prevAskSize,
				json_value(TickerJson, '$.prevLast') as prevLast,
				floor(json_value(TickerJson, '$.prevLastSize')) as prevLastSize,
				floor(json_value(TickerJson, '$.volume')) as volume,
				json_value(TickerJson, '$.open') as [open],
				json_value(TickerJson, '$.high') as [high],
				json_value(TickerJson, '$.low') as [low],
				json_value(TickerJson, '$.close') as [close],
				json_value(TickerJson, '$.vwap') as [vwap],
				json_value(TickerJson, '$.markPrice') as [markPrice],
				json_value(TickerJson, '$.halted') as [halted],
				floor(json_value(TickerJson, '$.rtVolume')) as [rtVolume],
				floor(json_value(TickerJson, '$.rtTradeVolume')) as [rtTradeVolume],
				floor(json_value(TickerJson, '$.auctionVolume')) as [auctionVolume],
				json_value(TickerJson, '$.auctionPrice') as [auctionPrice],
				floor(json_value(TickerJson, '$.auctionImbalance')) as [auctionImbalance]
			from [StockData].[StockTickerDetail] as a
			where 1 = 1
			and isjson(TickerJson)=1
			and StockTickerDetailID = @intRowNumber		
		) as a
		where not exists
		(
			select 1
			from [StockData].[StockBidAsk]
			where ASXCode = a.ASXCode
			and ObservationTime != CurrentTime
			and isnull(PriceBid, -1) = isnull(a.Bid, -1)
			and isnull(PriceAsk, -1) = isnull(a.Ask, -1)
			and isnull(SizeBid, -1) = isnull(a.bidSize, -1)
			and isnull(SizeAsk, -1) = isnull(a.askSize, -1)
			and ObservationDate = cast(@pdtCurrentTime as date)
		)


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

	--	IF @@TRANCOUNT > 0
	--	BEGIN
	--		ROLLBACK TRANSACTION
	--	END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
