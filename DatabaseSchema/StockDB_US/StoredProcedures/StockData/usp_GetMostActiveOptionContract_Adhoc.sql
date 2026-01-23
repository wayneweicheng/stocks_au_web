-- Stored procedure: [StockData].[usp_GetMostActiveOptionContract_Adhoc]



CREATE PROCEDURE [StockData].[usp_GetMostActiveOptionContract_Adhoc]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintProcessID as int = 0,
@pvchObservationDate as varchar(20)
AS
/******************************************************************************
File: usp_GetMostActiveOptionContract_Adhoc.sql
Stored Procedure Name: usp_GetMostActiveOptionContract_Adhoc
Overview
-----------------
usp_GetMostActiveOptionContract_Adhoc

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
exec [StockData].[usp_GetMostActiveOptionContract]
@pintProcessID = 1

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetMostActiveOptionContract_Adhoc'
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
		--declare @pvchObservationDate as date = '2023-12-08'
		--declare @pintProcessID as int = 2

		if object_id(N'Tempdb.dbo.#TempContract') is not null
			drop table #TempContract

		select 
			identity(int, 1, 1) as UniqueKey,
			checksum(OptionSymbol) as HashKey,
			0 as IsLastContract,
			LEFT(ASXCode, CHARINDEX('.', ASXCode) - 1)  as Underlying,
			OptionSymbol, 
			null as NumTrade,
			ExpiryDate,
			0 as ExpiryDateRank,
			Expiry as Expiry,
			Strike,
			PorC,
			Volume*isnull(LastTradePrice, Bid) as TradeValue,
			ObservationDate as ObservationDate,
			'Intraday' as Mode
		into #TempContract
		from StockData.v_OptionDelayedQuote_Norm as a
		where 1 = 1 
		--and ASXCode in ('UBER.US')
		--and OptionSymbol = 'UBER231215C00059000'
		and ObservationDate = @pvchObservationDate --'2023-12-07'
		and ZScoreVolume > 2
		--and case when OpenInterest > 0 then Volume/OpenInterest end > 0.5
		and Volume*Bid*100 > 100000
		and abs(Delta) < 0.8 
		and ASXCode not in ('SPXW.US', 'SPX.US', 'SPY.US', 'QQQ.US', 'GOOGL.US', 'NFLX.US')
		and not exists
		(
			select 1
			from Transform.MarketCLVTrendDetails
			where MarketCap in ('h. 300B+')
			and ASXCode = a.ASXCode
		)
		order by 
			a.ZScoreVolume desc,
			TradeValue desc

		select *
		from #TempContract
		where abs(HashKey)%3 = @pintProcessID
		order by UniqueKey

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
