-- Stored procedure: [StockData].[usp_AddQUOptionTrades]


CREATE PROCEDURE [StockData].[usp_AddQUOptionTrades]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchObservationDate varchar(20),
@pvchResponse as varchar(max)
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
		if object_id(N'Tempdb.dbo.#TempQUOptionTrades') is not null
			drop table #TempQUOptionTrades

		select
			@pvchASXCode as ASXCode,
			@pvchResponse as Response,
			@pvchObservationDate as ObservationDate
		into #TempQUOptionTrades
		--into MAWork.dbo.TempTotalGex

		delete a
		from [StockData].[QUOptionTrades] as a
		inner join #TempQUOptionTrades as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into [StockData].[QUOptionTrades]
		(
			ASXCode,
			ObservationDate,
			Response,
			CreateDate
		)
		select
			ASXCode,
			ObservationDate,
			Response,
			getdate() as CreateDate
		from #TempQUOptionTrades

		--if object_id(N'Tempdb.dbo.##TempGexDetailsParsed') is not null
		--	drop table #TempGexDetailsParsed

		--select 
		--	a.ObservationDate,
		--	a.ASXCode,
		--	cast(json_value(e.value, '$.GEX') as decimal(20, 4)) as GEX,	
		--	cast(json_value(e.value, '$.OpenInterest') as decimal(20, 4)) as OpenInterest,	
		--	cast(json_value(e.value, '$.strike') as decimal(20, 4)) as Strike,	
		--	cast(json_value(e.value, '$.type') as varchar(50)) as Type,	
		--	cast(json_value(c.value, '$."exp-date"') as date) as ExpiryDate,
		--	cast(json_value(c.value, '$.ExpDaytotal') as decimal(20, 4)) as ExpiryDateTotal
		--into #TempGexDetailsParsed
		--from #TempGexDetails as a
		--cross apply openjson(Response) as b
		--cross apply openjson(b.value) as c
		--cross apply openjson(c.value) as d
		--cross apply openjson(d.value) as e
		--where 1 = 1
		--and b.[key] = 'breakdowns'
		--and d.[key] = 'Details'

		--delete a
		--from [StockData].[GEXDetailsParsed] as a
		--inner join #TempGexDetails as b
		--on a.ObservationDate = b.ObservationDate
		--and a.ASXCode = b.ASXCode

		--insert into [StockData].[GEXDetailsParsed]
		--(
		--	[ObservationDate],
		--	[ASXCode],
		--	[GEX],
		--	[OpenInterest],
		--	[Strike],
		--	[ExpiryDate],
		--	[ExpiryDateTotal],
		--	CreateDate,
		--	PorC
		--)
		--select
		--	[ObservationDate],
		--	[ASXCode],
		--	[GEX],
		--	[OpenInterest],
		--	[Strike],
		--	[ExpiryDate],
		--	[ExpiryDateTotal],
		--	getdate() as CreateDate,
		--	[Type] as PorC
		--from #TempGexDetailsParsed

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
