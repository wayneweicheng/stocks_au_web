-- Stored procedure: [Order].[usp_AddOrder]


CREATE PROCEDURE [Order].[usp_AddOrder]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode varchar(10),
@pintUserID int,
@pvchTradeAccountName varchar(100),
@pintOrderTypeID int,
@pvchOrderPriceType varchar(100),
@pdecOrderPrice decimal(20, 4) = null,
@pintVolumeGT bigint = null,
@pintOrderVolume bigint = null,
@pdecOrderValue decimal(20, 4) = null,
@pintOrderPriceBufferNumberOfTick int = null,
@pvchValidUntil varchar(100),
@pvchMessage as varchar(200) output
AS
/******************************************************************************
File: usp_AddTradingAlert.sql
Stored Procedure Name: usp_AddTradingAlert
Overview
-----------------
usp_AddTradingAlert

Input Parameters
----------------2
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
Date:		2018-08-22
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2020-01-03
Author:		WAYNE CHENG
Description: Add in addtional parameters OrderPriceType and OrderPriceBufferNumberOfTick
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOrder'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Order'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		select @pvchMessage = ''

		insert into [Order].[Order]
		(
		   [ASXCode]
		  ,[UserID]
		  ,TradeAccountName
		  ,[OrderTypeID]
		  ,[OrderPriceType]
		  ,[OrderPrice]
		  ,[VolumeGt]
		  ,[OrderVolume]
		  ,[OrderValue]
		  ,[OrderPriceBufferNumberOfTick]
		  ,[ValidUntil]
		  ,[CreateDate]
		  ,[OrderTriggerDate]
		)
		select
		   @pvchASXCode as [ASXCode]
		  ,@pintUserID as [UserID]
		  ,@pvchTradeAccountName as TradeAccountName
		  ,@pintOrderTypeID as [OrderTypeID]
		  ,@pvchOrderPriceType as [OrderPriceType]
		  ,@pdecOrderPrice as [OrderPrice]
		  ,case when @pintVolumeGt >= 0 then @pintVolumeGt else null end as [VolumeGt]
		  ,case when @pintOrderVolume >= 0 then @pintOrderVolume else null end as [OrderVolume]
		  ,case when @pdecOrderValue >= 0 then @pdecOrderValue else null end as [OrderValue]
		  ,case when @pintOrderPriceBufferNumberOfTick >= 0 then @pintOrderPriceBufferNumberOfTick else null end as OrderPriceBufferNumberOfTick
		  ,@pvchValidUntil as [ValidUntil]
		  ,getdate() as [CreateDate]
		  ,null as [OrderTriggerDate]
		  
		  select @pvchMessage = 'Order on ' + @pvchASXCode + ' successfully added.'


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
