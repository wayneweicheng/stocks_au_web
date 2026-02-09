-- Stored procedure: [Report].[usp_Get_BrokerReportStartFrom]




CREATE PROCEDURE [Report].[usp_Get_BrokerReportStartFrom]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10) =  null,
@pvchObservationStartDate as date,
@pvchObservationEndDate as date
AS
/******************************************************************************
File: usp_Get_BrokerReportStartFrom.sql
Stored Procedure Name: usp_Get_BrokerReportStartFrom
Overview
-----------------
usp_Get_BrokerReportStartFrom

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Get_BrokerReportFromStart'
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
		declare @dtObservationStartDate as date = cast(@pvchObservationStartDate as date)
		declare @dtObservationEndDate as date = cast(@pvchObservationEndDate as date)

		if @dtObservationStartDate = [Common].[DateAddBusinessDay](-5, '2050-12-12')
		begin
			select 
				@dtObservationStartDate = [Common].[DateAddBusinessDay](-5, max(ObservationDate)),
				@dtObservationEndDate = max(ObservationDate)
			from StockData.v_BrokerReport
			where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		end
		
		if @dtObservationStartDate = [Common].[DateAddBusinessDay](-10, '2050-12-12')
		begin
			select 
				@dtObservationStartDate = [Common].[DateAddBusinessDay](-10, max(ObservationDate)),
				@dtObservationEndDate = max(ObservationDate)
			from StockData.v_BrokerReport
			where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		end

		if @dtObservationStartDate = [Common].[DateAddBusinessDay](-20, '2050-12-12')
		begin
			select 
				@dtObservationStartDate = [Common].[DateAddBusinessDay](-20, max(ObservationDate)),
				@dtObservationEndDate = max(ObservationDate)
			from StockData.v_BrokerReport
			where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		end

		if @dtObservationStartDate = [Common].[DateAddBusinessDay](-60, '2050-12-12')
		begin
			select 
				@dtObservationStartDate = [Common].[DateAddBusinessDay](-60, max(ObservationDate)),
				@dtObservationEndDate = max(ObservationDate)
			from StockData.v_BrokerReport
			where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		end

		if @dtObservationStartDate = [Common].[DateAddBusinessDay](-120, '2050-12-12')
		begin
			select 
				@dtObservationStartDate = [Common].[DateAddBusinessDay](-120, max(ObservationDate)),
				@dtObservationEndDate = max(ObservationDate)
			from StockData.v_BrokerReport
			where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		end

		if @dtObservationStartDate = [Common].[DateAddBusinessDay](-240, '2050-12-12')
		begin
			select 
				@dtObservationStartDate = [Common].[DateAddBusinessDay](-240, max(ObservationDate)),
				@dtObservationEndDate = max(ObservationDate)
			from StockData.v_BrokerReport
			where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		end

		select 
			ASXCode,
			sum(TotalVolume) as BRVolume,
			sum(NetVolume) as NetVolume ,
			sum(NetValue) as NetValue
		into #TempBRVolume
		from StockData.v_BrokerReport
		where (ASXCode = @pvchASXCode or @pvchASXCode is null)
		and ObservationDate >= @dtObservationStartDate
		and BrokerCode not in ('Others')
		group by ASXCode

		select 
			a.ASXCode,
			isnull(sum(a.Volume), sum(b.Volume)) as TotalVolume
		into #TempTotalVolume
		from StockData.PriceHistory as a
		left join StockData.PriceSummary as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and LatestForTheDay = 1
		and b.DateTo is null
		where a.ASXCode = @pvchASXCode
		and a.ObservationDate >= @dtObservationStartDate
		and a.ObservationDate <= @dtObservationEndDate
		group by a.ASXCode

		set dateformat ymd

		select 
			ASXCode,
			cast(cast(x.ObservationDate as date) as varchar(50)) as ObservationDate,
			isnull(z.BrokerName, 'Unknown') as BrokerCode,
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
				a.ASXCode,
				@dtObservationStartDate as ObservationDate,
				BrokerCode,
				sum(BuyValue) as BuyValue,
				sum(SellValue) as SellValue,
				sum(a.NetValue) as RawNetValue,
				sum(TotalValue) as TotalValue,
				sum(BuyVolume) as BuyVolume,
				sum(SellVolume) as SellVolume,
				sum(a.NetVolume) as NetVolume,
				sum(a.TotalVolume) as TotalVolume, 
				sum(NoBuys) as NoBuys,
				sum(NoSells) as NoSells,
				sum(Trades) as Trades,
				case when sum(BuyVolume) > 0 then cast(sum(BuyValue)*1.0/sum(BuyVolume) as decimal(20, 4)) else null end as BuyPrice,
				case when sum(SellVolume) > 0 then cast(sum(SellValue)*1.0/sum(SellVolume) as decimal(20, 4)) else null end as SellPrice 
			from StockData.v_BrokerReport as a
			where (a.ASXCode = @pvchASXCode or @pvchASXCode is null)
			and ObservationDate >= @dtObservationStartDate
			and ObservationDate <= @dtObservationEndDate
			and BrokerCode not in ('Others')
			group by a.ASXCode, BrokerCode
			union
			select
				b.ASXCode as ASXCode,
				@dtObservationStartDate as ObservationDate,
				'Others' as BrokerCode,
				null as BuyValue,
				null as SellValue,
				-1*b.NetValue as RawNetValue,
				null as TotalValue,
				null as BuyVolume,
				null as SellVolume,
				-1*b.NetVolume as NetVolume,
				2*c.TotalVolume - b.BRVolume as TotalVolume, 
				null as NoBuys,
				null as NoSells,
				null as Trades,
				null as BuyPrice,
				null as SellPrice 
			from #TempBRVolume as b
			left join #TempTotalVolume as c
			on b.ASXCode = c.ASXCode
		) as x
		left join LookupRef.BrokerName as z
		on x.BrokerCode = z.BrokerCode
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
