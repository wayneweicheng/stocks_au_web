-- Stored procedure: [StockData].[usp_AddOptionContract]




CREATE PROCEDURE [StockData].[usp_AddOptionContract]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchUnderlying varchar(10),
@pvchOptionSymbol varchar(100),
@pvchCurrency varchar(50),
@pdecStrike decimal(20, 4),
@pvchRight varchar(10),
@pvchMultiplier varchar(10),
@pvchExpiry varchar(20),
@pdecBid decimal(20, 4),
@pintBidSize bigint,
@pdecAsk decimal(20, 4),
@pintAskSize bigint,
@pdecClose decimal(20, 4),
@pdecDelta decimal(20, 4),
@pdecGamma decimal(20, 4),
@pdecVega decimal(20, 4),
@pdecTheta decimal(20, 4),
@pdecImpliedVol decimal(20, 4)
AS
/******************************************************************************
File: usp_AddOptionContract.sql
Stored Procedure Name: usp_AddOptionContract
Overview
-----------------
usp_AddOptionContract

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
Date:		2022-07-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOptionContract'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
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
		set dateformat ymd

		if object_id(N'Tempdb.dbo.#TempOptionContract') is not null
			drop table #TempOptionContract

		create table #TempOptionContract
		(
			OptionContractID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			Underlying varchar(10) not null,
			OptionSymbol varchar(100) not null,
			Currency varchar(50) not null,
			Strike decimal(20, 4) null,
			PorC varchar(10),
			Multiplier int,
			Expiry varchar(20),
			ExpiryDate date,
			Bid decimal(20, 4),
			BidSize bigint,
			Ask decimal(20, 4),
			AskSize bigint,
			[Close] decimal(20, 4),
			Delta decimal(20, 4),
			Gamma decimal(20, 4),
			Vega decimal(20, 4),
			Theta decimal(20, 4),
			ImpliedVol decimal(20, 4)
		)

		insert into #TempOptionContract
		(
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[Currency]
		  ,[Strike]
		  ,[PorC]
		  ,[Multiplier]
		  ,[Expiry]
		  ,[ExpiryDate]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[Close]
		  ,[Delta]
		  ,[Gamma]
		  ,[Vega]
		  ,[Theta]
		  ,[ImpliedVol]
		)
		select
		   @pvchUnderlying + '.AX' as [ASXCode]
		  ,@pvchUnderlying as [Underlying]
		  ,@pvchOptionSymbol as [OptionSymbol]
		  ,@pvchCurrency as [Currency]
		  ,@pdecStrike as [Strike]
		  ,@pvchRight as [PorC]
		  ,cast(@pvchMultiplier as int) as [Multiplier]
		  ,@pvchExpiry as [Expiry]
		  ,cast(left(@pvchExpiry, 4) + '-' + substring(@pvchExpiry, 5, 2) + '-' + substring(@pvchExpiry, 7, 2) as date) as [ExpiryDate]
		  ,@pdecBid as [Bid]
		  ,@pintBidSize as [BidSize]
		  ,@pdecAsk as [Ask]
		  ,@pintAskSize as [AskSize]
		  ,@pdecClose as [Close]
		  ,@pdecDelta as [Delta]
		  ,@pdecGamma as [Gamma]
		  ,@pdecVega as [Vega]
		  ,@pdecTheta as [Theta]
		  ,@pdecImpliedVol as [ImpliedVol]

		insert into StockData.OptionContractHistory
		(
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[Currency]
		  ,[Strike]
		  ,[PorC]
		  ,[Multiplier]
		  ,[Expiry]
		  ,[ExpiryDate]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[Close]
		  ,[Delta]
		  ,[Gamma]
		  ,[Vega]
		  ,[Theta]
		  ,[ImpliedVol]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		)
		select
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[Currency]
		  ,[Strike]
		  ,[PorC]
		  ,[Multiplier]
		  ,[Expiry]
		  ,[ExpiryDate]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[Close]
		  ,[Delta]
		  ,[Gamma]
		  ,[Vega]
		  ,[Theta]
		  ,[ImpliedVol]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		from StockData.OptionContract as a
		where exists
		(
			select 1
			from #TempOptionContract
			where ASXCode = a.ASXCode
			and OptionSymbol = a.OptionSymbol
		)

		delete a
		from StockData.OptionContract as a
		where exists
		(
			select 1
			from #TempOptionContract
			where ASXCode = a.ASXCode
			and OptionSymbol = a.OptionSymbol
		)
		and OptionSymbol != 'N/A'

		delete a
		from StockData.OptionContract as a
		where exists
		(
			select 1
			from #TempOptionContract
			where ASXCode = a.ASXCode
			and Expiry = a.Expiry
			and Strike = a.Strike
			and PorC = a.PorC
		)
		and OptionSymbol = 'N/A'
		insert into StockData.OptionContract
		(
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[Currency]
		  ,[Strike]
		  ,[PorC]
		  ,[Multiplier]
		  ,[Expiry]
		  ,[ExpiryDate]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[Close]
		  ,[Delta]
		  ,[Gamma]
		  ,[Vega]
		  ,[Theta]
		  ,[ImpliedVol]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		)
		select
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[Currency]
		  ,[Strike]
		  ,[PorC]
		  ,[Multiplier]
		  ,[Expiry]
		  ,[ExpiryDate]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[Close]
		  ,[Delta]
		  ,[Gamma]
		  ,[Vega]
		  ,[Theta]
		  ,[ImpliedVol]
		  ,getdate() as [CreateDateTime]
		  ,getdate() as [UpdateDateTime]
		from #TempOptionContract
		
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
