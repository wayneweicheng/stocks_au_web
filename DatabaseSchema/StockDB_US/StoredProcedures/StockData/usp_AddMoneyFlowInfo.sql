-- Stored procedure: [StockData].[usp_AddMoneyFlowInfo]



CREATE PROCEDURE [StockData].[usp_AddMoneyFlowInfo]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchMoneyFlowInfo as varchar(max)
AS
/******************************************************************************
File: usp_AddMoneyFlowInfo.sql
Stored Procedure Name: usp_AddMoneyFlowInfo
Overview
-----------------
usp_AddMoneyFlowInfo

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
Date:		2022-07-10
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddMoneyFlowInfo'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchASXCode as varchar(100) = 'PLS.AX'
		--declare @pvchMoneyFlowInfo as varchar(100) = '{}'

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempMoneyFlowInfoRaw') is not null
			drop table #TempMoneyFlowInfoRaw

		select
			@pvchASXCode as ASXCode,
			@pvchMoneyFlowInfo as MoneyFlowInfo
		into #TempMoneyFlowInfoRaw
		
		if object_id(N'Tempdb.dbo.#TempMoneyFlowInfoBasic') is not null
			drop table #TempMoneyFlowInfoBasic

		select distinct
			ASXCode, 
			json_value(MoneyFlowInfo, '$.ASXCode') as StockCode, 
			json_value(MoneyFlowInfo, '$.MoneyFlowType') as MoneyFlowType,
			json_value(MoneyFlowInfo, '$.ObservationDate') as ObservationDate,
			json_value(MoneyFlowInfo, '$.MoneyFlowDirection') as MoneyFlowDirection,
			json_value(MoneyFlowInfo, '$.Ranking') as Ranking,
			json_value(MoneyFlowInfo, '$.TotalStocks') as TotalStocks
		into #TempMoneyFlowInfoBasic
		from #TempMoneyFlowInfoRaw as a
		cross apply openjson(MoneyFlowInfo) as b

		delete a
		from [StockData].[MoneyFlowInfo] as a
		inner join #TempMoneyFlowInfoBasic as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into [StockData].[MoneyFlowInfo]
		(
			[ASXCode],
			[StockCode],
			[MoneyFlowType],
			ObservationDate,
			MoneyFlowDirection,
			Ranking,
			TotalStocks,
			[LastValidateDate]
		)
		select
			[ASXCode],
			[StockCode],
			[MoneyFlowType],
			ObservationDate,
			MoneyFlowDirection,
			Ranking,
			TotalStocks,
			getdate() as [LastValidateDate]
		from #TempMoneyFlowInfoBasic as a

		
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
