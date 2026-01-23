-- Stored procedure: [StockData].[usp_AddQU100]



CREATE PROCEDURE [StockData].[usp_AddQU100]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchObservationDate as varchar(20),
@pvchMode as varchar(20),
@pvchTimeFrame as varchar(50),
@pvchResponse as varchar(max)
AS
/******************************************************************************
File: usp_AddQU100.sql
Stored Procedure Name: usp_AddQU100
Overview
-----------------
usp_AddQU100

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
Date:		2022-09-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddQU100'
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
		if object_id(N'Tempdb.dbo.##TempMoneyFlowInfoRaw') is not null
			drop table ##TempMoneyFlowInfoRaw

		select
			@pvchObservationDate as ObservationDate,
			@pvchMode as Mode,
			@pvchTimeFrame as TimeFrame,
			@pvchResponse as Response
		into #TempQU100

		if object_id(N'Tempdb.dbo.#TempQU100Parsed') is not null
			drop table #TempQU100Parsed

		select  
			a.ObservationDate,
			a.Mode,
			a.TimeFrame,
			try_cast(json_value(c.value, '$.change') as int) as Change,
			json_value(c.value, '$.industry') as industry,
			json_value(c.value, '$.long_short') as long_short,
			try_cast(json_value(c.value, '$.rank') as int) as [rank],
			json_value(c.value, '$.sector') as sector,
			json_value(c.value, '$.ticker') as ticker
		into #TempQU100Parsed
		from #TempQU100 as a
		cross apply openjson(Response) as b
		cross apply openjson(b.value) as c
		where b.[key] = 'data'

		delete a
		from [StockData].[QU100Parsed] as a
		inner join #TempQU100Parsed as b
		on a.ObservationDate = b.ObservationDate
		and a.Mode = b.Mode
		and a.TimeFrame = b.TimeFrame

		insert into [StockData].[QU100Parsed]
		(
			[ObservationDate],
			[Mode],
			[TimeFrame],
			[Change],
			[Industry],
			[LongShort],
			[QURank],
			[Sector],
			[Ticker],
			ASXCode
		)
		select 
			[ObservationDate],
			[Mode],
			[TimeFrame],
			[Change],
			nullif([Industry], '') as [Industry],
			long_short as [LongShort],
			[rank] as [QURank],
			nullif([Sector], '') as [Sector],
			[Ticker],
			Ticker + '.US' as ASXCode
		from #TempQU100Parsed as a
		
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
