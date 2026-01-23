-- Stored procedure: [StockData].[usp_AddDarkPoolIndex]



CREATE PROCEDURE [StockData].[usp_AddDarkPoolIndex]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchIndexCode as varchar(10),
@pvchObservationDate as varchar(20),
@pvchPrice as varchar(50),
@pvchDix as varchar(50),
@pvchGex as varchar(50)
AS
/******************************************************************************
File: usp_AddDarkPoolIndex.sql
Stored Procedure Name: usp_AddDarkPoolIndex
Overview
-----------------
usp_AddDarkPoolIndex

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
Date:		2022-05-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddDarkPoolIndex'
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
		--declare @pvchCompanyInfo as varchar(100) = '{}'

		--Code goes here 
		set dateformat ymd

		if object_id(N'Tempdb.dbo.#TempDarkPoolIndex') is not null
			drop table #TempDarkPoolIndex

		select
	       upper(@pvchIndexCode) as IndexCode,
		   cast(@pvchObservationDate as date) as ObservationDate,
		   cast(@pvchPrice as decimal(20, 4)) as Price,
		   cast(@pvchDix as decimal(20, 4))	as Dix,
		   cast(@pvchGex as decimal(20, 4))	as Gex,
		   getdate() as CreateDate
		into #TempDarkPoolIndex

		delete a
		from StockData.DarkPoolIndex as a
		inner join #TempDarkPoolIndex as b
		on a.IndexCode = b.IndexCode
		and a.ObservationDate = b.ObservationDate
		and a.ObservationDate > dateadd(day, -5, getdate())

		insert into StockData.DarkPoolIndex
		(
			IndexCode,
			ObservationDate,
			Price,
			Dix,
			Gex,
			CreateDate
		)
		select
			IndexCode,
			ObservationDate,
			Price,
			Dix,
			Gex,
			CreateDate
		from #TempDarkPoolIndex as a
		where not exists
		(
			select 1
			from StockData.DarkPoolIndex
			where ObservationDate = a.ObservationDate
			and IndexCode = a.IndexCode
		)

		insert into StockDB.StockData.PriceHistory
		(
			   [ASXCode]
			  ,[ObservationDate]
			  ,[Close]
			  ,[Open]
			  ,[Low]
			  ,[High]
			  ,[Volume]
			  ,[Value]
			  ,[Trades]
			  ,[CreateDate]
			  ,[ModifyDate]
		)
		select
			   'SPX' as [ASXCode]
			  ,[ObservationDate]
			  ,Price as [Close]
			  ,-1 as [Open]
			  ,-1 as [Low]
			  ,-1 as [High]
			  ,99 as [Volume]
			  ,null as [Value]
			  ,null as [Trades]
			  ,getdate() as [CreateDate]
			  ,getdate() as [ModifyDate]
		from StockDB.StockData.DarkPoolIndex as a
		where ObservationDate >= '2022-12-16'
		and not exists
		(
			select 1
			from StockDB.StockData.PriceHistory
			where ASXCode = 'SPX'
			and ObservationDate = a.ObservationDate
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
