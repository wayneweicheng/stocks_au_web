-- Stored procedure: [StockData].[usp_RefeshDirectorInterest]







CREATE PROCEDURE [StockData].[usp_RefeshDirectorInterest]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshDirectorInterest.sql
Stored Procedure Name: usp_RefeshDirectorInterest
Overview
-----------------
usp_RefeshAppendix3B

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
Date:		2018-11-14
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshDirectorInterest'
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
		--begin transaction
		if object_id(N'Tempdb.dbo.#TempDirectorInterest') is not null
			drop table #TempDirectorInterest

		select 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			AnnContent,
			replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|\(\)]', ' '))), '  ', ' ') as CleansedAnnContent, 
			--DA_Utility.dbo.RegexMatch(replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' '), '(?<=cash.{0,80}\send\s.{0,10}[quarter|period|month].{0,20}\s)[\,0-9]{2,20}') as CashPositionRaw, 
			--case when AnnContent like '%A_000%' then 1 else 0 end as ValueInAUDK,
			--case when AnnContent like '%USD_000%' then 1 else 0 end as ValueInUSDK,
			cast(null as varchar(50)) as CashPositionVarchar,
			cast(null as bigint) as CashPosition
		into #TempDirectorInterest
		from StockData.Announcement as a
		where 
		(
			AnnDescr like '%Appendix 3Y%'
			or
			AnnDescr like '%director%interest%'
		)
		--and ASXCode = 'KRC.AX'
		order by AnnRetriveDateTime desc

		declare @intNum as int = 1

		while @intNum > 0
		begin
			update a
			set CleansedAnnContent = replace(CleansedAnnContent, '  ', ' ')
			from #TempDirectorInterest as a
			where charindex('  ', CleansedAnnContent, 0) > 0

			select @intNum = @@ROWCOUNT

			print @intNum
		end

		update a
		set CleansedAnnContent = replace(CleansedAnnContent, 'Name of entity', '^Name of entity')
		from #TempDirectorInterest as a

		if object_id(N'Tempdb.dbo.#TempDirectorInterestSplit') is not null
			drop table #TempDirectorInterestSplit
		select 
			a.*, 
			b.StrValue as DirectorAnnContent 
		into #TempDirectorInterestSplit
		from #TempDirectorInterest as a
		cross apply DA_Utility.[dbo].[ufn_ParseStringByDelimiter](a.AnnouncementID, '^', CleansedAnnContent) as b
		where TokenOrder > 1

		if object_id(N'Tempdb.dbo.#TempDirectorInterestParsed') is not null
			drop table #TempDirectorInterestParsed

		select
			identity(int, 1, 1) as UniqueKey, 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Name\s{0,8}of\s{0,8}Director).*(?=Date\s{0,8}of\s{0,8}last)') as DirectorNameRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Date\s{0,8}of\s{0,8}last\s{0,8}notice).*(?=Part\s{0,8}1\s{0,8}Change)') as DateOfLastNoticeRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Direct\s{0,8}or\s{0,8}indirect\s{0,8}interest).*(?=Nature\s{0,8}of\s{0,8}indirect)') as DirectOrIndirectRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Rise\s{0,8}to\s{0,8}the\s{0,8}relevant\s{0,8}interest).*?(?=Date\s{0,8}of\s{0,8}change)') as NatureOfInterestRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Date\s{0,8}of\s{0,8}Change).*?(?=No.\s{0,8}of\s{0,8}securities)') as DateOfChangeRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=No.\s{0,8}of\s{0,8}securities\s{0,8}held\s{0,8}prior\s{0,8}to\s{0,8}change).*?(?=class)') as HeldBeforeChangeRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Class).*?(?=Number\s{0,80}acquired)') as ClassRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Number\s{0,80}acquired).*?(?=Number\s{0,80}disposed)') as NumberAcquiredRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=Number\s{0,80}disposed).*?(?=Value\s{0,80}consideration)') as NumberDisposedRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=estimated\s{0,80}valuation).*?(?=No.\s{0,80}of\s{0,80}securities\s{0,80}held\s{0,80}after)') as ValueConsiderationRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=No.\s{0,80}of\s{0,80}securities\s{0,80}held\s{0,80}after\s{0,80}(change|changes)\s{0,80}).*?(?=Nature\s{0,80}of\s{0,80}(change|changes))') as HeldAfterChangesRaw,
			DA_Utility.dbo.RegexMatch(DirectorAnnContent, '(?<=participation\s{0,80}in\s{0,80}buy\s{0,80}back).*?(?=Part\s{0,80}2\s{0,80}change\s{0,80}of\s{0,80}director)') as NatureOfChangeRaw,
			--coalesce
			--(
			--	DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=8\s{1,5}number\s{1,5}and\s{1,5}.{0,500}if\s{1,5}applicable\s{1,5}Number\s{1,5}).*(?=\+{1}Class\s{1,5}(Ord|Ordinary)\s{1,5}Fully)'),
			--	DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=8\s{1,5}number\s{1,5}and\s{1,5}.{0,500}if\s{1,5}applicable\s{1,5}).*(?=Fully\s{1,5}Paid\s{1,5}(Ord|Ordinary)\s{1,5}Share)')
			--)	 as TotalSharesOnASXRaw,
			cast(null as varchar(200)) as DirectorName,
			cast(null as varchar(200)) as DateOfLastNotice,
			cast(null as varchar(200)) as DirectOrIndirect,
			cast(null as varchar(max)) as NatureOfInterest,
			cast(null as varchar(200)) as DateOfChange,
			cast(null as varchar(max)) as HeldBeforeChange,
			cast(null as varchar(max)) as Class,
			cast(null as varchar(max)) as NumberAcquire,
			cast(null as varchar(max)) as NumberDisposed,
			cast(null as varchar(max)) as ValueConsideration,
			cast(null as varchar(max)) as HeldAfterChange,
			cast(null as varchar(max)) as NatureOfChange,
			DirectorAnnContent
		into #TempDirectorInterestParsed
		from #TempDirectorInterestSplit
		where AnnDescr not like '%Initial Director%'
		and AnnDescr not like '%Final Director%'
		
		update a
		set a.HeldAfterChange = B.NumOrdShare
		from #TempDirectorInterestParsed as a
		inner join
		(
			select 
				UniqueKey,
				--a.AnnDateTime,
				--a.DirectorNameRaw,
				sum(try_cast(replace(replace(b.[Text], ',', ''), ' ', '') as bigint)) as NumOrdShare
			from #TempDirectorInterestParsed as a
			cross apply DA_Utility.dbo.[RegexGroups](HeldAfterChangesRaw, '[0-9,]+(?=\s(?:new\s)*(?:ordinary\s)*(?:fully\s)*(?:paid\s)*(?:common\s)*(?:ordinary\s)*share)') as b
			where len(HeldAfterChangesRaw) > 0
			group by 
				a.UniqueKey
		) as b
		on a.UniqueKey = b.UniqueKey

		update a
		set a.HeldAfterChange = B.NumOrdShare
		from #TempDirectorInterestParsed as a
		inner join
		(
			select 
				UniqueKey,
				--a.AnnDateTime,
				--a.DirectorNameRaw,
				sum(try_cast(replace(replace(b.[Text], ',', ''), ' ', '') as bigint)) as NumOrdShare
			from #TempDirectorInterestParsed as a
			cross apply DA_Utility.dbo.[RegexGroups](HeldAfterChangesRaw, '[0-9,]+(?=\s(?:new\s)*(?:fully\s)*(?:paid\s)*(?:common\s)*ordinary)') as b
			where len(HeldAfterChangesRaw) > 0
			group by 
				a.UniqueKey
		) as b
		on a.UniqueKey = b.UniqueKey
		where a.HeldAfterChange is null

		update a
		set DateOfChange = 
			coalesce
			(
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(DateOfChangeRaw)), '(([0-9])|([0-2][0-9])|([3][0-1]))\s(Jan|January|Feb|Feburary|Mar|March|Apr|April|May|May|Jun|June|Jul|July|Aug|August|Sep|September|Oct|October|Nov|November|Dec|December)\s\d{4}'), 
				null
			)
		from #TempDirectorInterestParsed as a

		update a
		set a.NumberAcquire = a.NumberAcquiredRaw,
			a.NumberDisposed = a.NumberDisposedRaw,
			a.NatureOfChange = a.NatureOfChangeRaw,
			a.DirectorName = left(a.DirectorNameRaw, 200)
		from #TempDirectorInterestParsed as a

		delete a
		from StockData.DirectorInterest as a
		inner join #TempDirectorInterestParsed as b
		on a.AnnouncementID = b.AnnouncementID
		and a.DirectorNameRaw = b.DirectorNameRaw
		and a.HeldAfterChange is null
		and b.HeldAfterChange is not null

		insert into StockData.DirectorInterest
		(
			   [UniqueKey]
			  ,[AnnouncementID]
			  ,[ASXCode]
			  ,[AnnDateTime]
			  ,[AnnDescr]
			  ,[DirectorNameRaw]
			  ,[DateOfLastNoticeRaw]
			  ,[DirectOrIndirectRaw]
			  ,[NatureOfInterestRaw]
			  ,[DateOfChangeRaw]
			  ,[HeldBeforeChangeRaw]
			  ,[ClassRaw]
			  ,[NumberAcquiredRaw]
			  ,[NumberDisposedRaw]
			  ,[ValueConsiderationRaw]
			  ,[HeldAfterChangesRaw]
			  ,[NatureOfChangeRaw]
			  ,[DirectorName]
			  ,[DateOfLastNotice]
			  ,[DirectOrIndirect]
			  ,[NatureOfInterest]
			  ,[DateOfChange]
			  ,[HeldBeforeChange]
			  ,[Class]
			  ,[NumberAcquire]
			  ,[NumberDisposed]
			  ,[ValueConsideration]
			  ,[HeldAfterChange]
			  ,[NatureOfChange]
			  ,[DirectorAnnContent]
		)
		select
			   [UniqueKey]
			  ,[AnnouncementID]
			  ,[ASXCode]
			  ,[AnnDateTime]
			  ,[AnnDescr]
			  ,[DirectorNameRaw]
			  ,[DateOfLastNoticeRaw]
			  ,[DirectOrIndirectRaw]
			  ,[NatureOfInterestRaw]
			  ,[DateOfChangeRaw]
			  ,[HeldBeforeChangeRaw]
			  ,[ClassRaw]
			  ,[NumberAcquiredRaw]
			  ,[NumberDisposedRaw]
			  ,[ValueConsiderationRaw]
			  ,[HeldAfterChangesRaw]
			  ,[NatureOfChangeRaw]
			  ,[DirectorName]
			  ,[DateOfLastNotice]
			  ,[DirectOrIndirect]
			  ,[NatureOfInterest]
			  ,[DateOfChange]
			  ,[HeldBeforeChange]
			  ,[Class]
			  ,[NumberAcquire]
			  ,[NumberDisposed]
			  ,[ValueConsideration]
			  ,[HeldAfterChange]
			  ,[NatureOfChange]
			  ,[DirectorAnnContent]
		from #TempDirectorInterestParsed as a
		where not exists
		(
			select 1
			from StockData.DirectorInterest
			where AnnouncementID = a.AnnouncementID
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
