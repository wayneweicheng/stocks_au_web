-- Stored procedure: [Report].[usp_Get_BrokerReport]




CREATE PROCEDURE [Report].[usp_Get_BrokerReport]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchObservationDate as date
AS
/******************************************************************************
File: usp_Get_BrokerReport.sql
Stored Procedure Name: usp_Get_BrokerReport
Overview
-----------------
usp_Get_BrokerReport

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
Date:		2018-11-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_BrokerReport'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		declare @intBRVolume as bigint
		declare @intTotalVolume as bigint
		declare @intBRNetVolume as bigint
		declare @decBRNetValue as decimal(20, 4)
		--declare @pvchObservationDate as varchar(50) = '2016-10-30' 
		declare @dtObservationDate as date = cast(@pvchObservationDate as date)
		
		if @dtObservationDate = '2050-12-12'
		begin
			select @dtObservationDate = max(ObservationDate)
			from StockData.BrokerReport
			where ASXCode = @pvchASXCode
		end

		if @dtObservationDate = [Common].[DateAddBusinessDay](-1, '2050-12-12')
		begin
			select @dtObservationDate = [Common].[DateAddBusinessDay](-1, max(ObservationDate))
			from StockData.BrokerReport
			where ASXCode = @pvchASXCode
		end

		if @dtObservationDate = [Common].[DateAddBusinessDay](-2, '2050-12-12')
		begin
			select @dtObservationDate = [Common].[DateAddBusinessDay](-2, max(ObservationDate))
			from StockData.BrokerReport
			where ASXCode = @pvchASXCode
		end

		if @dtObservationDate = [Common].[DateAddBusinessDay](-3, '2050-12-12')
		begin
			select @dtObservationDate = [Common].[DateAddBusinessDay](-3, max(ObservationDate))
			from StockData.BrokerReport
			where ASXCode = @pvchASXCode
		end


		select 
			@intBRVolume = sum(TotalVolume),
			@intBRNetVolume = sum(NetVolume),
			@decBRNetValue = sum(NetValue)
		from StockData.BrokerReport
		where ASXCode = @pvchASXCode
		and ObservationDate = @dtObservationDate
		and BrokerCode not in ('Others')

		select 
			@intTotalVolume = isnull(a.Volume, b.Volume)
		from StockData.PriceHistory as a
		left join StockData.PriceSummary as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and LatestForTheDay = 1
		and b.DateTo is null
		where a.ASXCode = @pvchASXCode
		and a.ObservationDate = @dtObservationDate

		select 
			ASXCode,
			ObservationDate,
			BrokerCode,
			format(BuyValue, 'N0') as BuyValue,
			format(SellValue, 'N0') as SellValue,
			format(RawNetValue, 'N0') as NetValue,
			format(TotalValue, 'N0') as TotalValue,
			format(BuyVolume, 'N0') as BuyVolume,
			format(SellVolume, 'N0') as SellVolume,
			format(NetVolume, 'N0') as NetVolume,
			format(TotalVolume, 'N0') as TotalVolume, 
			NoBuys,
			NoSells,
			Trades,
			BuyPrice,
			SellPrice 
		from
		(
			select 
				ASXCode,
				ObservationDate,
				BrokerCode,
				BuyValue,
				SellValue,
				NetValue as RawNetValue,
				TotalValue,
				BuyVolume,
				SellVolume,
				NetVolume,
				TotalVolume, 
				NoBuys,
				NoSells,
				Trades,
				BuyPrice,
				SellPrice 
			from StockData.BrokerReport
			where ASXCode = @pvchASXCode
			and ObservationDate = @dtObservationDate
			and BrokerCode not in ('Others')
			union
			select
				@pvchASXCode as ASXCode,
				@dtObservationDate as ObservationDate,
				'Others' as BrokerCode,
				null as BuyValue,
				null as SellValue,
				-1*@decBRNetValue as RawNetValue,
				null as TotalValue,
				null as BuyVolume,
				null as SellVolume,
				-1*@intBRNetVolume as NetVolume,
				2*@intTotalVolume - @intBRVolume as TotalVolume, 
				null as NoBuys,
				null as NoSells,
				null as Trades,
				null as BuyPrice,
				null as SellPrice 
		) as x
		order by RawNetValue desc
				
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
