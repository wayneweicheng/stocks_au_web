-- Stored procedure: [StockData].[usp_GetActiveOptionContract_Adhoc]


CREATE PROCEDURE [StockData].[usp_GetActiveOptionContract_Adhoc]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintProcessID as int = 0,
@pvchObservationDate varchar(20)
AS
/******************************************************************************
File: usp_GetActiveOptionContract_Adhoc.sql
Stored Procedure Name: usp_GetActiveOptionContract_Adhoc
Overview
-----------------
usp_GetActiveOptionContract_Adhoc

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
exec [StockData].[usp_GetActiveOptionContract_Adhoc]
@pvchObservationDate = '2026-02-05',
@pintProcessID = 1
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetActiveOptionContract_Adhoc'
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
		declare @dtObservationDate as date
		if @pvchObservationDate is null
		begin
			select @dtObservationDate = Common.DateAddBusinessDay(-1*1, getdate()) 
		end
		else
		begin
			select @dtObservationDate = cast(@pvchObservationDate as date)
		end

		--select @dtObservationDate = '2026-02-05'

		declare @dtPrevDate as date
		select @dtPrevDate = Common.DateAddBusinessDay(-1*1, @dtObservationDate) 

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
			@dtObservationDate as ObservationDate,
			'Intraday' as Mode
		into #TempContract
		from StockData.v_OptionDelayedQuote_Norm as a
		where 1 = 1 
		--and ASXCode in ('UBER.US')
		--and OptionSymbol = 'UBER231215C00059000'
		and ObservationDate >= @dtPrevDate
		and ZScoreVolume > 2
		--and NormVolume > 0.95
		--and case when OpenInterest > 0 then Volume/OpenInterest end > 0.5
		and Volume*Bid*100 > 100000
		and abs(Delta) < 0.8 
		and ASXCode not in ('GOOGL.US', 'NFLX.US')
		and ExpiryDate > @dtObservationDate
		--and ASXCode in ('spy.US')
		--and not exists
		--(
		--	select 1
		--	from Transform.MarketCLVTrendDetails
		--	where MarketCap in ('h. 300B+')
		--	and ASXCode = a.ASXCode
		--)
		order by 
			a.ExpiryDate,
			a.ZScoreVolume desc,
			TradeValue desc
		option (recompile)

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
