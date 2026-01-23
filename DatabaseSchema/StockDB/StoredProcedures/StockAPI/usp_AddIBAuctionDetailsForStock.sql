-- Stored procedure: [StockAPI].[usp_AddIBAuctionDetailsForStock]


CREATE PROCEDURE [StockAPI].[usp_AddIBAuctionDetailsForStock]
@pvchASXCode as varchar(10), 
@pdtCurrentTime as datetime, 
@pdecBid as decimal(20, 4), 
@pintBidVolume as int, 
@pdecAsk as decimal(20, 4), 
@pintAskVolume as int, 
@pdecLast as decimal(20, 4), 
@pintLastVolume as int, 
@pdecOpen as decimal(20, 4), 
@pdecHigh as decimal(20, 4), 
@pdecLow as decimal(20, 4), 
@pdecClose as decimal(20, 4), 
@pintVolume as int, 
@pdecAuctionPrice as decimal(20, 4), 
@pintAuctionVolume as int, 
@pintAuctionImbalance as int,
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AddIBAuctionDetailsForStock.sql
Stored Procedure Name: usp_AddIBAuctionDetailsForStock
Overview
-----------------
usp_AddIBAuctionDetailsForStock

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddIBAuctionDetailsForStock'
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
		insert into [StockData].[StockAuctionDetail]
		(
		   [ASXCode]
		  ,[CurrentTime]
		  ,[ObservationDate]
		  ,[Bid]
		  ,[BidVolume]
		  ,[Ask]
		  ,[AskVolume]
		  ,[Last]
		  ,[LastVolume]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Close]
		  ,[Volume]
		  ,[AuctionPrice]
		  ,[AuctionVolume]
		  ,[AuctionImbalance]
		  ,CreateDate
		)
		select
			@pvchASXCode, 
			@pdtCurrentTime,
			cast(@pdtCurrentTime as date) as [ObservationDate],
			@pdecBid, 
			@pintBidVolume, 
			@pdecAsk, 
			@pintAskVolume, 
			@pdecLast, 
			@pintLastVolume, 
			@pdecOpen, 
			@pdecHigh, 
			@pdecLow, 
			@pdecClose, 
			@pintVolume, 
			@pdecAuctionPrice, 
			@pintAuctionVolume, 
			@pintAuctionImbalance,
			getdate() as [CreateDate]

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
