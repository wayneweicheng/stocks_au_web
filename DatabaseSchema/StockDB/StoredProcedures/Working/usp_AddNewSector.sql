-- Stored procedure: [Working].[usp_AddNewSector]


CREATE PROCEDURE [Working].[usp_AddNewSector]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10)
AS
/******************************************************************************
File: usp_AddNewSector.sql
Stored Procedure Name: usp_AddNewSector
Overview
-----------------
usp_AddNewSector

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
Date:		2020-04-27
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddNewSector'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Working'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 		
		INSERT INTO [LookupRef].[KeyToken]
				   ([Token]
				   ,[TokenType]
				   ,[CutoffThreshold]
				   ,[CreateDate]
				   ,[IsDisabled]
				   ,[TokenOrder])
		select
					'DYDROGEN ENERGY' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]
		union
		select
					'BATTERY TECHNOLOGY' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]
		union
		select
					'RETAIL' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]
		union
		select
					'FLIGHT AND TRAVEL' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]
		union
		select
					'FLIGHT AND TRAVEL' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]
		union
		select
					'NEXT INVESTOR HOLDINGS' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]
		union
		select
					'LIUBING NIUCHUNYAN HOLDINGS' as [Token]
				   ,'SECTOR' as[TokenType]
				   ,null as [CutoffThreshold]
				   ,getdate() as [CreateDate]
				   ,0 as [IsDisabled]
				   ,900 [TokenOrder]


		--UPDATE NAME OF EXISTING SECTOR
		ALTER TABLE [LookupRef].[StockKeyToken] DROP CONSTRAINT [fk_lookuprefstockkeytoken_token]

		ALTER TABLE [LookupRef].[KeyTokenSearchTerm] DROP CONSTRAINT [fk_lookuprefkeytokensearchterm_token]

		ALTER TABLE [StockData].[StockKeyToken] DROP CONSTRAINT [fk_stockdata_stockkeytoken]

		update a
		set Token = 'BAUXITE AND ALUMINUM'
		from [LookupRef].[KeyToken] as a
		where Token = 'BAUXITE'

		update a
		set Token = 'BAUXITE AND ALUMINUM'
		from [LookupRef].[StockKeyToken] as a
		where Token = 'BAUXITE'

		update a
		set Token = 'BAUXITE AND ALUMINUM'
		from [LookupRef].[KeyTokenSearchTerm] as a
		where Token = 'BAUXITE'

		update a
		set Token = 'BAUXITE AND ALUMINUM'
		from [StockData].[StockKeyToken] as a
		where Token = 'BAUXITE'
		
		ALTER TABLE [LookupRef].[StockKeyToken]  WITH NOCHECK ADD  CONSTRAINT [fk_lookuprefstockkeytoken_token] FOREIGN KEY([Token])
		REFERENCES [LookupRef].[KeyToken] ([Token])

		ALTER TABLE [LookupRef].[StockKeyToken] CHECK CONSTRAINT [fk_lookuprefstockkeytoken_token]

		ALTER TABLE [LookupRef].[KeyTokenSearchTerm] WITH NOCHECK ADD  CONSTRAINT [fk_lookuprefkeytokensearchterm_token] FOREIGN KEY([Token])
		REFERENCES [LookupRef].[KeyToken] ([Token])

		ALTER TABLE [LookupRef].[KeyTokenSearchTerm] CHECK CONSTRAINT [fk_lookuprefkeytokensearchterm_token]

		ALTER TABLE [StockData].[StockKeyToken]  WITH NOCHECK ADD  CONSTRAINT [fk_stockdata_stockkeytoken] FOREIGN KEY([Token])
		REFERENCES [LookupRef].[KeyToken] ([Token])

		ALTER TABLE [StockData].[StockKeyToken] CHECK CONSTRAINT [fk_stockdata_stockkeytoken]

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