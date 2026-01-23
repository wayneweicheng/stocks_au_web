-- Stored procedure: [StockData].[usp_AddDirector]






CREATE PROCEDURE [StockData].[usp_AddDirector]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchName as varchar(200),
@pintAge as int,
@pintSince as int,
@pvchPosition as varchar(200)
AS
/******************************************************************************
File: usp_AddDirector.sql
Stored Procedure Name: usp_AddDirector
Overview
-----------------
usp_AddDirector

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
Date:		2017-02-25
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddDirector'
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
		if len(@pvchName) > 0
		begin
			print 'OK'
		end
		else
		begin
			raiserror('Values not populated', 16, 0)
		end

		if object_id(N'Tempdb.dbo.#TempDirector') is not null
			drop table #TempDirector

		create table #TempDirector
		(
			DirectorID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			Name varchar(200) not null,
			Age int null,
			Since int null,
			Position varchar(200) not null,
			CreateDate smalldatetime
		)

		insert into #TempDirector
		(
			ASXCode,
			Name,
			Age,
			Since,
			Position,
			CreateDate
		)
		select
			@pvchASXCode as ASXCode,
			@pvchName as Name,
			@pintAge as Age,
			@pintSince as Since,
			@pvchPosition as Position,
			getdate() as CreateDate
		
		update a
		set Name = rtrim(ltrim(replace(replace(replace(replace(Name, char(9), ''), char(10), ''), char(13), ''), '&nbsp;', ' ')))
		from #TempDirector as a

		update a
		set Position = rtrim(ltrim(replace(replace(replace(replace(Position, char(9), ''), char(10), ''), char(13), ''), '&nbsp;', ' ')))
		from #TempDirector as a

		update a
		set Age = nullif(Age, -1)
		from #TempDirector as a

		update a
		set Since = nullif(Since, -1)
		from #TempDirector as a

		update a
		set a.DateTo = getdate()
		from StockData.Director as a
		inner join #TempDirector as c
		on a.ASXCode = c.ASXCode
		and a.Name = c.Name
		left join #TempDirector as b
		on isnull(a.Age, -1) = isnull(b.Age, -1)
		and isnull(a.Since, -1) = isnull(b.Since, -1)
		and isnull(a.Position, '') = isnull(b.Position, '')		
		where b.ASXCode is null
		and a.DateTo is null

		update a
		set a.DateLastSeen = getdate()
		from StockData.Director as a
		inner join #TempDirector as c
		on a.ASXCode = c.ASXCode
		and a.Name = c.Name
		and isnull(a.Age, -1) = isnull(c.Age, -1)
		and isnull(a.Since, -1) = isnull(c.Since, -1)
		and isnull(a.Position, '') = isnull(c.Position, '')	
		and a.DateTo is null

		insert into StockData.Director
		(
		   [ASXCode]
		  ,[Name]
		  ,[Age]
		  ,[Since]
		  ,[Position]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[DateLastSeen]
		)
		select
		   [ASXCode]
		  ,[Name]
		  ,[Age]
		  ,[Since]
		  ,[Position]
		  ,CreateDate as [DateFrom]
		  ,null as [DateTo]
		  ,getdate() as [DateLastSeen]
		from #TempDirector as a
		where not exists
		(
			select 1
			from StockData.Director
			where ASXCode = a.ASXCode
			and Name = a.Name
			and isnull(Age, -1) = isnull(a.Age, -1)
			and isnull(Since, -1) = isnull(a.Since, -1)
			and isnull(Position, '') = isnull(a.Position, '')
			and DateTo is null
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
