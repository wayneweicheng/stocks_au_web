-- Stored procedure: [Report].[usp_GetBatchQuote_V2]



CREATE PROCEDURE [Report].[usp_GetBatchQuote_V2]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchAccountNumber as varchar(10)
AS
/******************************************************************************
File: usp_GetBatchQuote.sql
Stored Procedure Name: usp_GetBatchQuote
Overview
-----------------
usp_GetBatchQuote

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
Date:		2018-06-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetBatchQuote'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		--if object_id(N'Tempdb.dbo.#TempWLLastUpdate') is not null
		--	drop table #TempWLLastUpdate

		--select WatchListName, min(isnull(LastUpdateDate, '2001-10-12')) as LastUpdateDate
		--into #TempWLLastUpdate
		--from StockData.WatchList
		--where 1 = 1
		--and AccountName = @pvchAccountNumber
		--group by WatchListName

		declare @vchWLName as varchar(100)
		begin tran
			if 
			(
				(cast(getdate() as time) > cast('16:00:00' as time) and cast(getdate() as time) < cast('16:11:00' as time))
				or
				(cast(getdate() as time) > cast('09:50:00' as time) and cast(getdate() as time) < cast('10:11:00' as time))
			)
			begin
				select top 1 
					@vchWLName = WatchListName	 
				from 
				(
					select 
						WatchListName, 
						min(isnull(LastUpdateDate, '2001-10-12')) as LastUpdateDate, 
						min(case when WatchListName in ('WL260') and datediff(second, isnull(LastUpdateDate, '2001-10-12'), getdate()) > 10 then 1 else 0 end) as PriorityRank
					from StockData.WatchList with(tablockx)
					where 1 = 1
					and AccountName = @pvchAccountNumber
					group by WatchListName
				) as a
				order by PriorityRank desc, LastUpdateDate asc, WatchListName
			end
			else
			begin
				select top 1 
					@vchWLName = WatchListName	 
				from 
				(
					select 
						WatchListName, 
						min(isnull(LastUpdateDate, '2001-10-12')) as LastUpdateDate, 
						min(case when WatchListName not in ('WL260') and datediff(second, isnull(LastUpdateDate, '2001-10-12'), getdate()) < 55 then 0 else 1 end) as PriorityRank
					from StockData.WatchList with(tablockx)
					where 1 = 1
					and AccountName = @pvchAccountNumber
					group by WatchListName
				) as a
				order by PriorityRank desc, LastUpdateDate asc, WatchListName
			end

			update a
			set LastUpdateDate = getdate()
			from StockData.WatchList as a
			where WatchListName = @vchWLName
		commit tran

		declare @vchStdASXCodeBatch as varchar(max) = ''
		declare @vchStdASXCode as varchar(10) = ''
		declare @intHashValue as bigint = -1
		declare curASXCodeBatch cursor for 
		select distinct StdASXCode, HashValue
		from StockData.WatchListStock as a
		inner join StockData.WatchList as b
		on a.WatchListName = b.WatchListName
		--where b.WatchListName = @vchWLName

		open curASXCodeBatch
		fetch curASXCodeBatch into @vchStdASXCode, @intHashValue

		while @@FETCH_STATUS = 0
		begin
			--print @vchStdASXCode
			select @vchStdASXCodeBatch = @vchStdASXCodeBatch + '"'+ @vchStdASXCode + '",'
			fetch curASXCodeBatch into @vchStdASXCode, @intHashValue
		end

		close curASXCodeBatch
		deallocate curASXCodeBatch

		select @vchStdASXCodeBatch = substring(@vchStdASXCodeBatch, 1, len(@vchStdASXCodeBatch) - 1)

		declare @intRandomNumber as int = ABS(CHECKSUM(NewId())) % 17 + 3

		declare @vchBatchQuery as varchar(max) = '[' + @vchStdASXCodeBatch + ']'

		--if try_cast(replace(@vchWLName, 'WL', '') as int) > 100 and try_cast(replace(@vchWLName, 'WL', '') as int) < 200
		--begin
		--	WAITFOR DELAY '00:00:10';
		--end

		WAITFOR DELAY '00:00:1'
		
		select @vchWLName as WatchListName, @vchBatchQuery as BatchQuery

		
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
