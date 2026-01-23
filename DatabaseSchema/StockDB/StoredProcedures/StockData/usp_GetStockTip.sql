-- Stored procedure: [StockData].[usp_GetStockTip]



CREATE PROCEDURE [StockData].[usp_GetStockTip]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10) = null,
@pvchTipType varchar(10) = null,
@pintLastNumOfDays int,
@pvchExportType as varchar(10) = 'Png'
AS
/******************************************************************************
File: usp_GetStockTip.sql
Stored Procedure Name: usp_GetStockTip
Overview
-----------------
usp_GetStockTip

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
Date:		2022-11-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetStockTip'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchObservationDate as varchar(20) = '20220617'
		
		--Code goes here 
		set dateformat ymd
		declare @dtObservationDate as date 
		if cast(Common.DateAddBusinessDay(0, getdate()) as date) > getdate()
		begin
			select @dtObservationDate = cast(Common.DateAddBusinessDay(-1, getdate()) as date)
		end
		else
		begin
			select @dtObservationDate = cast(Common.DateAddBusinessDay(0, getdate()) as date)
		end
		
		select *
		from
		(
			select 
				a.TipUser,
				a.ASXCode,
				TipType,
				a.PriceAsAtTip as TipPrice,
				coalesce(b.[Close], c.[Close]) as [Close],
				cast(cast(case when a.PriceAsAtTip > 0 then (coalesce(b.[Close], c.[Close]) - a.PriceAsAtTip)*100.0/a.PriceAsAtTip else null end as decimal(10, 2)) as varchar(50)) + '%' as PriceChange,
				a.TipDateTime,
				case when @pvchExportType = 'png' then case when len(AdditionalNotes) > 100 then left(AdditionalNotes, 97) + '...' else AdditionalNotes end 
					 else AdditionalNotes
				end as AdditionalNotes,
				m2.BrokerCode as Recent10dBuyBroker,
				n2.BrokerCode as Recent10dSellBroker
			from StockData.StockTip as a
			left join [Transform].[BrokerReportList] as m2
			on a.ASXCode = m2.ASXCode
			and m2.LookBackNoDays = 10
			and m2.ObservationDate = cast(@dtObservationDate as date)
			and m2.NetBuySell = 'B'
			left join [Transform].[BrokerReportList] as n2
			on a.ASXCode = n2.ASXCode
			and n2.LookBackNoDays = 10
			and n2.ObservationDate = cast(@dtObservationDate as date)
			and n2.NetBuySell = 'S'
			left join StockData.v_PriceSummary_Latest_Today as b
			on a.ASXCode = b.ASXCode
			left join StockData.PriceHistory as c
			on a.ASXCode = c.ASXCode
			where (@pvchASXCode is null or a.ASXCode = @pvchASXCode)
			and (@pvchTipType is null or TipType = @pvchTipType)
			and datediff(day, a.TipDateTime, getdate()) < @pintLastNumOfDays
			and right(a.ASXCode, 3) = '.AX'
			union
			select 
				a.TipUser,
				a.ASXCode,
				TipType,
				a.PriceAsAtTip,
				b.[Close] as CurrentClose,
				cast(cast(case when a.PriceAsAtTip > 0 then (b.[Close] - a.PriceAsAtTip)*100.0/a.PriceAsAtTip else null end as decimal(10, 2)) as varchar(50)) + '%' as PriceChangePerc,
				a.TipDateTime,
				case when @pvchExportType = 'png' then case when len(AdditionalNotes) > 100 then left(AdditionalNotes, 97) + '...' else AdditionalNotes end 
					 else AdditionalNotes
				end as AdditionalNotes,
				null as Recent10dBuyBroker,
				null as Recent10dSellBroker
			from StockData.StockTip as a
			left join StockDB_US.StockData.PriceHistoryCurrent as b
			on a.ASXCode = b.ASXCode
			where (@pvchASXCode is null or a.ASXCode = @pvchASXCode)
			and (@pvchTipType is null or TipType = @pvchTipType)
			and datediff(day, a.TipDateTime, getdate()) < @pintLastNumOfDays
			and right(a.ASXCode, 3) = '.US'
		) as a
		order by a.TipDateTime desc;

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
