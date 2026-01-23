-- Stored procedure: [DataMaintenance].[usp_RefreshAnnouncementSearch]



CREATE PROCEDURE [DataMaintenance].[usp_RefreshAnnouncementSearch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintGoBackNumDays as int = 90
AS
/******************************************************************************
File: usp_RefreshAnnouncementSearch.sql
Stored Procedure Name: usp_RefreshAnnouncementSearch
Overview
-----------------
usp_RefreshAnnouncementSearch

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
Date:		2021-09-30
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshAnnouncementSearch'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		
		declare @intSearchItemID as int
		declare @vchSearchItemName as varchar(100)
		declare @vchFullTextSearch as varchar(200)
		declare @vchRegex1 as varchar(500)
		declare @vchRegex2 as varchar(500)
		declare @dtAnnSearchToDate as date
		declare curSearchItem cursor for
		select SearchItemID, SearchItemName, FullTextSearch, Regex1, Regex2, AnnSearchToDate
		from LookupRef.AnnouncementSearchItem
		--where SearchItemID >= 9

		open curSearchItem 
		fetch curSearchItem into @intSearchItemID, @vchSearchItemName, @vchFullTextSearch, @vchRegex1, @vchRegex2, @dtAnnSearchToDate

		while @@fetch_status = 0
		begin
			select @intSearchItemID, @vchSearchItemName, @vchFullTextSearch, @vchRegex1, @vchRegex2, @dtAnnSearchToDate

			if object_id(N'Tempdb.dbo.#TempAnn') is not null
				drop table #TempAnn

			select *
			into #TempAnn
			from StockData.Announcement as a with(nolock)
			where a.[AnnDateTime] > isnull(@dtAnnSearchToDate, cast(dateadd(day, -1*@pintGoBackNumDays, getdate()) as date))
			and 
			(
				case when len(@vchFullTextSearch) > 0 and contains(a.AnnContent, @vchFullTextSearch) then 1 
					 when not len(@vchFullTextSearch) > 0 then 1
					 else 0
				end = 1
			)
			--and MarketSensitiveIndicator = 0

			delete a
			from #TempAnn as a
			inner join Transform.StockMCAndCashPosition as b
			on a.ASXCode = b.ASXCode
			and b.MC > 2000

			if object_id(N'Tempdb.dbo.#TempSearchCandidate') is not null
				drop table #TempSearchCandidate

			select
				b.SearchItemID as SearchItemID,
				DA_Utility.dbo.RegexMatch(AnnContent, @vchRegex1) as SearchResult,
				ASXCode,
				[AnnRetriveDateTime],
				[AnnDateTime],
				[MarketSensitiveIndicator],
				[AnnDescr],
				AnnContent,
				[AnnouncementID],
				[ObservationDate]
			into #TempSearchCandidate
			from #TempAnn as a with(nolock)
			inner join LookupRef.AnnouncementSearchItem as b
			on b.SearchItemID = @intSearchItemID
			where DA_Utility.dbo.RegexMatch(a.AnnContent, @vchRegex1) is not null

			if object_id(N'Tempdb.dbo.#TempSearchResult') is not null
				drop table #TempSearchResult

			select 
				b.SearchItemID as SearchItemID,
				DA_Utility.dbo.RegexMatch(AnnContent, @vchRegex2) as SearchResult,
				ASXCode,
				[AnnRetriveDateTime],
				[AnnDateTime],
				[MarketSensitiveIndicator],
				[AnnDescr],
				[AnnouncementID],
				[ObservationDate]
			into #TempSearchResult
			from #TempSearchCandidate as a
			inner join LookupRef.AnnouncementSearchItem as b
			on b.SearchItemID = @intSearchItemID
			where DA_Utility.dbo.RegexMatch(a.AnnContent, @vchRegex2) is not null

			insert into StockData.AnnouncementSearchResult
			(
				SearchItemID,
				SearchResult,
				ASXCode,
				[AnnRetriveDateTime],
				[AnnDateTime],
				[MarketSensitiveIndicator],
				[AnnDescr],
				[AnnouncementID],
				[ObservationDate]
			)
			select
				SearchItemID,
				SearchResult,
				ASXCode,
				[AnnRetriveDateTime],
				[AnnDateTime],
				[MarketSensitiveIndicator],
				[AnnDescr],
				[AnnouncementID],
				[ObservationDate]
			from #TempSearchResult as a
			where not exists
			(
				select 1
				from StockData.AnnouncementSearchResult
				where SearchItemID = a.SearchItemID
				and ASXCode = a.ASXCode
				and AnnDateTime = a.AnnDateTime
			)

			update a
			set AnnSearchToDate = ObservationDate
			from LookupRef.AnnouncementSearchItem as a
			inner join
			(
				select max(ObservationDate) as ObservationDate from #TempSearchResult
			) as b
			on 1 = 1
			where SearchItemID = @intSearchItemID

			fetch curSearchItem into @intSearchItemID, @vchSearchItemName, @vchFullTextSearch, @vchRegex1, @vchRegex2, @dtAnnSearchToDate

		end

		close curSearchItem 
		deallocate curSearchItem 


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
