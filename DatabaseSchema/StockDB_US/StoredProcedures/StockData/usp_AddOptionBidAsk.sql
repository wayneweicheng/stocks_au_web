-- Stored procedure: [StockData].[usp_AddOptionBidAsk]



create PROCEDURE [StockData].[usp_AddOptionBidAsk]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchUnderlying varchar(10),
@pvchOptionSymbol varchar(100),
@pdtObservationTime datetime,
@pdecPriceBid decimal(20, 4),
@pintSizeBid bigint,
@pdecPriceAsk decimal(20, 4),
@pintSizeAsk bigint
AS
/******************************************************************************
File: usp_AddOptionBidAsk.sql
Stored Procedure Name: usp_AddOptionBidAsk
Overview
-----------------
usp_AddOptionBidAsk

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOptionBidAsk'
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

		if object_id(N'Tempdb.dbo.#TempOptionBidAsk') is not null
			drop table #TempOptionBidAsk

		create table #TempOptionBidAsk
		(
			OptionTradeID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			Underlying varchar(10) not null,
			OptionSymbol varchar(100) not null,
			ObservationTime datetime,
			PriceBid decimal(20, 4),
			SizeBid bigint,
			PriceAsk decimal(20, 4),
			SizeAsk bigint
		)

		insert into #TempOptionBidAsk
		(
			ASXCode,
			Underlying,
			OptionSymbol,
			ObservationTime,
			PriceBid,
			SizeBid,
			PriceAsk,
			SizeAsk
		)
		select
		   @pvchUnderlying + '.US' as [ASXCode]
		  ,@pvchUnderlying as [Underlying]
		  ,@pvchOptionSymbol as [OptionSymbol]
		  ,@pdtObservationTime as ObservationTime
		  ,@pdecPriceBid as PriceBid
		  ,@pintSizeBid as SizeBid
		  ,@pdecPriceAsk as PriceAsk
		  ,@pintSizeAsk as SizeAsk

		insert into StockData.OptionBidAsk
		(
		   ASXCode
		  ,Underlying
		  ,OptionSymbol
		  ,ObservationTime
		  ,PriceBid
		  ,SizeBid
		  ,PriceAsk
		  ,SizeAsk
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		)
		select
		   ASXCode
		  ,Underlying
		  ,OptionSymbol
		  ,ObservationTime
		  ,PriceBid
		  ,SizeBid
		  ,PriceAsk
		  ,SizeAsk
		  ,getdate() as [CreateDateTime]
		  ,getdate() as [UpdateDateTime]
		from #TempOptionBidAsk as a
		where not exists
		(
			select 1
			from StockData.OptionBidAsk
			where ASXCode = a.ASXCode
			and Underlying = a.Underlying
			and OptionSymbol = a.OptionSymbol
			and isnull(ObservationTime, '2050-12-12') = isnull(a.ObservationTime, '2050-12-12')
			and isnull(PriceBid, -1) = isnull(a.PriceBid, -1)
			and isnull(SizeBid, -1) = isnull(a.SizeBid, -1)
			and isnull(PriceAsk, -1) = isnull(a.PriceAsk, -1)
			and isnull(SizeAsk, -1) = isnull(a.SizeAsk, -1)
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
