-- Stored procedure: [StockData].[usp_AddBrokerDataAPI]


--exec [StockData].[usp_AddBrokerData]
--@pvchBrokerCode = 'HarLim',
--@pvchObservationDate= '20181105'

--select top 100 * from StockData.BrokerReport

CREATE PROCEDURE [StockData].[usp_AddBrokerDataAPI]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchBrokerName as varchar(100),
@pvchASXCode as varchar(10),
@pdecBuyValue as decimal(20, 4),
@pdecSellValue as decimal(20, 4),
@pdecNetValue as decimal(20, 4),
@pdecTotalValue as decimal(20, 4),
@pdecBuyVolume as decimal(20, 4),
@pdecSellVolume as decimal(20, 4),
@pdecNetVolume as decimal(20, 4),
@pintBuyTradeCount as int,
@pintSellTradeCount as int,
@pintTotalTradeCount as int,
@pdecBuyPrice as decimal(20, 4),
@pdecSellPrice as decimal(20, 4),
@pvchObservationDate as varchar(50)
AS
/******************************************************************************
File: usp_AddBrokerDataAPI.sql
Stored Procedure Name: usp_AddBrokerDataAPI
Overview
-----------------
usp_AddBrokerDataAPI

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
Date:		2019-06-16
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
		select @dtObservationDate = cast(@pvchObservationDate as date)

		if not exists
		(
			select 1
			from LookupRef.BrokerName
			where APIBrokerName = @pvchBrokerName
		)
		begin
			--raiserror('Please supply a valid broker name', 16, 0)
			print('Please supply a valid broker name')
		end
		else
		begin
			delete a
			from [StockData].[BrokerReport] as a
			inner join LookupRef.BrokerName as b
			on a.BrokerCode = b.BrokerCode
			where ObservationDate = @dtObservationDate
			and b.APIBrokerName = @pvchBrokerName
			and a.ASXCode = @pvchASXCode + '.AX'

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
			   @pvchASXCode + '.AX' as [ASXCode]
			  ,@dtObservationDate as [ObservationDate]
			  ,(select BrokerCode from LookupRef.BrokerName where APIBrokerName = @pvchBrokerName) as [BrokerCode]
			  ,@pvchASXCode as [Symbol]
			  ,@pdecBuyValue as [BuyValue]
			  ,@pdecSellValue as [SellValue]
			  ,@pdecNetValue as [NetValue]
			  ,@pdecTotalValue as [TotalValue]
			  ,floor(@pdecBuyVolume) as [BuyVolume]
			  ,floor(@pdecSellVolume) as [SellVolume]
			  ,floor(@pdecNetVolume) as [NetVolume]
			  ,floor(@pdecBuyVolume) + floor(@pdecSellVolume) as [TotalVolume]
			  ,@pintBuyTradeCount as [NoBuys]
			  ,@pintSellTradeCount as [NoSells]
			  ,@pintTotalTradeCount as [Trades]
			  ,@pdecBuyPrice as [BuyPrice]
			  ,@pdecSellPrice as [SellPrice]
			  ,null as [PercRank]
			  ,getdate() as [CreateDate]

		end
		
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
