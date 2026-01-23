-- Stored procedure: [StockData].[usp_AddPriceHistoryTimeFrameByElement]



CREATE PROCEDURE [StockData].[usp_AddPriceHistoryTimeFrameByElement]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTimeFrame as varchar(20),
@pvchStockCode as varchar(10),
@pdecOpen as decimal(20, 4),
@pdecHigh as decimal(20, 4),
@pdecLow as decimal(20, 4),
@pdecClose as decimal(20, 4),
@pintVolume as bigint,
@pdecAverage as decimal(20, 4),
@pintBarCount as int,
@pdtObservationDate as smalldatetime
AS
/******************************************************************************
File: usp_AddIntradayPriceHistoryByElement.sql
Stored Procedure Name: usp_AddIntradayPriceHistoryByElement
Overview
-----------------
usp_AddIntradayPriceHistoryByElement

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
Date:		2022-06-26
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddIntradayPriceHistoryByElement'
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
		set dateformat dmy

		delete a
		from [StockData].[PriceHistoryTimeFrame] as a
		where ASXCode = @pvchStockCode
		and TimeFrame = @pvchTimeFrame
		and TimeIntervalStart = @pdtObservationDate
		and cast(getdate() as date) = cast(@pdtObservationDate as date)

		insert into [StockData].[PriceHistoryTimeFrame]
		(
		   [ASXCode]
		  ,[TimeFrame]
		  ,[TimeIntervalStart]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Close]
		  ,[Volume]
		  ,[FirstSale]
		  ,[LastSale]
		  ,[SaleValue]
		  ,[NumOfSale]
		  ,[AverageValuePerTransaction]
		  ,[VWAP]
		  ,[ObservationDate]
		  ,CreateDate
		)
		select
		   [ASXCode]
		  ,[TimeFrame]
		  ,[TimeIntervalStart]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Close]
		  ,[Volume]
		  ,null as [FirstSale]
		  ,null as [LastSale]
		  ,SaleValue as [SaleValue]
		  ,Trades as [NumOfSale]
		  ,null as [AverageValuePerTransaction]
		  ,[VWAP]
		  ,ObservationDate as [ObservationDate]
		  ,getdate() as CreateDate
		from
		(
			select
				@pvchStockCode as [ASXCode],
				@pvchTimeFrame as TimeFrame,
				@pdtObservationDate as [TimeIntervalStart],
				@pdecClose as [Close],
				@pdecOpen as [Open],
				@pdecLow as [Low],
				@pdecHigh as [High],
				@pintVolume as [Volume],
				@pdecAverage as [VWAP],
				@pintVolume*@pdecAverage as SaleValue,
				@pintBarCount [Trades],
				cast(@pdtObservationDate as date) as ObservationDate,
				getdate() as CreateDate,	
				getdate() as ModifyDate	
		) as a
		where not exists
		(
			select 1
			from StockData.[PriceHistoryTimeFrame]
			where TimeIntervalStart = a.[TimeIntervalStart]
			and TimeFrame = a.TimeFrame
			and ASXCode = @pvchStockCode
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
