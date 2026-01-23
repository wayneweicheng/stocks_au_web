-- Stored procedure: [StockData].[usp_AddMoneyFlowLongShortValueInfo_API]



create PROCEDURE [StockData].[usp_AddMoneyFlowLongShortValueInfo_API]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchMoneyFlowInfo as varchar(max),
@pvchDataType as varchar(50),
@pdtLastUpdateDateTime as smalldatetime
AS
/******************************************************************************
File: usp_AddMoneyFlowInfo_API.sql
Stored Procedure Name: usp_AddMoneyFlowInfo_API
Overview
-----------------
usp_AddMoneyFlowInfo_API

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
Date:		2022-07-23
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddMoneyFlowInfo_API'
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
		--if object_id(N'Working.TempMoneyFlowInfoRaw') is not null
		--	drop table Working.TempMoneyFlowInfoRaw

		--select
		--	@pvchASXCode as ASXCode,
		--	@pvchMoneyFlowInfo as MoneyFlowInfo
		--into Working.TempMoneyFlowInfoRaw

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
			json_value([value], '$.xlabel') as ObservationDate, 
			json_value([value], '$.long_short') as LongShort,
			json_value([value], '$.sentiment') as Sentiment,
			null as MFRank,
			null as MFTotal,
			json_value([value], '$.near') as NearScore,
			json_value([value], '$.total') as TotalScore
		into #TempMoneyFlowInfoBasic
		from #TempMoneyFlowInfoRaw as a
		cross apply openjson(MoneyFlowInfo) as b

		update a
		set ObservationDate = left(ObservationDate, 10)
		from #TempMoneyFlowInfoBasic as a
		where @pvchDataType = 'Weekly'

		delete a
		from [StockData].[MoneyFlowInfo] as a
		inner join #TempMoneyFlowInfoBasic as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		and a.MoneyFlowType = @pvchDataType

		insert into [StockData].[MoneyFlowInfo]
		(
			[ASXCode],
			[MoneyFlowType],
			ObservationDate, 
			LongShort,
			Sentiment,
			MFRank,
			MFTotal,
			NearScore,
			TotalScore,
			[LastValidateDate]
		)
		select
			[ASXCode],
			@pvchDataType as [MoneyFlowType],
			ObservationDate, 
			LongShort,
			Sentiment,
			MFRank,
			MFTotal,
			NearScore,
			TotalScore,
			@pdtLastUpdateDateTime as [LastValidateDate]
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
