-- Stored procedure: [StockData].[usp_GetActiveOptionContract]


CREATE PROCEDURE [StockData].[usp_GetActiveOptionContract]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumPrevDay as int = 1
AS
/******************************************************************************
File: usp_GetActiveOptionContract.sql
Stored Procedure Name: usp_GetActiveOptionContract
Overview
-----------------
usp_GetActiveOptionContract

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
Date:		2016-05-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetActiveOptionContract'
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
		declare @dtMaxDate as date
		select @dtMaxDate = max(ObservationDate) from StockData.v_OptionDelayedQuote
		declare @dtMax2Date as date
		select @dtMax2Date = isnull(max(ObservationDate), '2023-01-01') from StockData.v_OptionDelayedQuote where ObservationDate < @dtMaxDate

		select
			checksum(OptionSymbol) as HashKey,
			0 as IsLastContract,
			left(ASXCode, 3) as Underlying,
			OptionSymbol, 
			1 as NumTrade,
			ExpiryDate,
			1 as ExpiryDateRank,
			Expiry,
			Strike,
			PorC,
			sum(Volume*LastTradePrice*100) as TradeValue,
			@dtMaxDate as ObservationDate,
			'Intraday' as Mode
		from StockData.v_OptionDelayedQuote
		where 1 = 1
		--and ASXCode in ('AKE.AX', 'PLS.AX', 'RRL.AX')
		--and OptionSymbol = 'PLSXA7'
		and ObservationDate >= @dtMax2Date
		and Volume > 0
		group by ASXCode,
			OptionSymbol,
			ExpiryDate,
			Expiry,
			PorC,
			Strike
		order by case when ASXCode in ('PLS.AX', 'AKE.AX') then 10
							  when ASXCode in ('NCM.AX', 'RRL.AX', 'EVN.AX', 'NST.AX') then 20
							  when ASXCode in ('BHP.AX', 'RIO.AX', 'FMG.AX', 'IGO.AX', 'OZL.AX') then 30
							  else 99
				 end, sum(Volume*LastTradePrice) desc


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
