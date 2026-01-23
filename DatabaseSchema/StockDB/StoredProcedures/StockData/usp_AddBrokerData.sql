-- Stored procedure: [StockData].[usp_AddBrokerData]


--exec [StockData].[usp_AddBrokerData]
--@pvchBrokerCode = 'HarLim',
--@pvchObservationDate= '20181105'

--select top 100 * from StockData.BrokerReport

CREATE PROCEDURE [StockData].[usp_AddBrokerData]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchBrokerCode as varchar(50),
@pvchObservationDate as varchar(50)
AS
/******************************************************************************
File: usp_AddBrokerData.sql
Stored Procedure Name: usp_AddBrokerData
Overview
-----------------
usp_AddOverview

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
Date:		2017-02-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = object_name(@@PROCID)
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = schema_name()
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
		--declare @test as varchar(50) = '20181123'
		select @dtObservationDate = cast(left(@pvchObservationDate, 4) + '-' + substring(@pvchObservationDate, 5, 2) + '-' + substring(@pvchObservationDate, 7, 2) as date)

		if not exists
		(
			select 1
			from LookupRef.BrokerName
			where BrokerCode = @pvchBrokerCode
		)
		begin
			raiserror('Please supply a valid broker code', 16, 0)
		end

		delete a
		from Working.BRRaw as a
		where len(Symbol) > 4

		delete a
		from [StockData].[BrokerReport] as a
		where ObservationDate = @dtObservationDate
		and BrokerCode = @pvchBrokerCode

		insert into [StockData].[BrokerReport]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[BrokerCode]
		  ,[Symbol]
		  ,[BuyValue]
		  ,[SellValue]
		  ,[NetValue]
		  ,[TotalValue]
		  ,[BuyVolume]
		  ,[SellVolume]
		  ,[NetVolume]
		  ,[TotalVolume]
		  ,[NoBuys]
		  ,[NoSells]
		  ,[Trades]
		  ,[BuyPrice]
		  ,[SellPrice]
		  ,[PercRank]
		  ,[CreateDate]
		)
		select
		   Symbol + '.AX' as [ASXCode]
		  ,@dtObservationDate as [ObservationDate]
		  ,@pvchBrokerCode as [BrokerCode]
		  ,[Symbol]
		  ,replace([Buy Value], ',', '') as [BuyValue]
		  ,replace([Sell Value], ',', '') as [SellValue]
		  ,replace([Net Value], ',', '') as [NetValue]
		  ,replace([Total Value], ',', '') as [TotalValue]
		  ,replace([Buy Volume], ',', '') as [BuyVolume]
		  ,replace([Sell Volume], ',', '') as [SellVolume]
		  ,replace([Net Volume], ',', '') as [NetVolume]
		  ,replace([Total Volume], ',', '') as [TotalVolume]
		  ,replace([No  Buys], ',', '') as [NoBuys]
		  ,replace([No  Sells], ',', '') as [NoSells]
		  ,replace([Trades], ',', '') as [Trades]
		  ,replace([Buy Price], ',', '') as [BuyPrice]
		  ,replace([Sell Price], ',', '') as [SellPrice]
		  ,replace([% Rank], ',', '') as [PercRank]
		  ,getdate() as [CreateDate]
		from Working.BRRaw

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
			
		EXECUTE DA_Utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
