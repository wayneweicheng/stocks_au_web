-- Stored procedure: [StockData].[usp_RefeshAppendix3B]







CREATE PROCEDURE [StockData].[usp_RefeshAppendix3B]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshAppendix3B.sql
Stored Procedure Name: usp_RefeshAppendix3B
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
Date:		2018-07-01
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshAppendix3B'
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
		
		if object_id(N'Tempdb.dbo.#TempAppendix3B') is not null
			drop table #TempAppendix3B

		select 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			AnnContent,
			replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' ') as CleansedAnnContent, 
			--DA_Utility.dbo.RegexMatch(replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' '), '(?<=cash.{0,80}\send\s.{0,10}[quarter|period|month].{0,20}\s)[\,0-9]{2,20}') as CashPositionRaw, 
			case when AnnContent like '%A_000%' then 1 else 0 end as ValueInAUDK,
			case when AnnContent like '%USD_000%' then 1 else 0 end as ValueInUSDK,
			cast(null as varchar(50)) as CashPositionVarchar,
			cast(null as bigint) as CashPosition
		into #TempAppendix3B
		from StockData.Announcement as a
		where 
		(
			AnnDescr like '%Appendix 3B%'
			or
			AnnDescr like '%App 3B%'
			or
			AnnDescr like 'App 3B%'
			or
			AnnDescr like '%App 3B'
			or
			AnnDescr like 'Appdix 3B%'
			or
			(AnnDescr like '%Placement%' and freetext(AnnContent,'"Appendix"'))
			or
			AnnDescr like '%Appendix 2A%'
		)
		--and ASXCode = 'RML.AX'
		--and not exists
		--(
		--	select 1
		--	from StockData.CashPosition
		--	where AnnouncementID = a.AnnouncementID
		--)
		order by AnnRetriveDateTime desc

		update a
		set CleansedAnnContent = replace(CleansedAnnContent, '3 P r i n c i p a l t e r m s', '3 Principal terms')
		from #TempAppendix3B as a
		where CleansedAnnContent like '%3 P r i n c i p a l t e r m s%'

		declare @intNum as int = 1

		while @intNum > 0
		begin
			update a
			set CleansedAnnContent = replace(CleansedAnnContent, '  ', ' ')
			from #TempAppendix3B as a
			where charindex('  ', CleansedAnnContent, 0) > 0

			select @intNum = @@ROWCOUNT

			print @intNum
		end

		--if object_id(N'Tempdb.dbo.#TempAppendix3BParsed') is not null
		--	drop table #TempAppendix3BParsed

		--select 
		--	AnnouncementID,
		--	ASXCode,
		--	AnnDateTime,
		--	AnnDescr,
		--	DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=5\s{0,8}Issue\s{0,8}Price\s{0,8}or\s{0,8}consideration).*(?=6\s{0,8}Purpose)') as IssuePriceRaw,
		--	DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=2\s{0,8}Number\s{0,8}of\s{0,8}\+securities\s{0,8}issued\s{0,8}or\s{0,8}.{0,200}which\s{0,8}may\s{0,8}be\s{0,8}issued).*(?=3\s{0,8}Principal\s{0,8}terms)') as SharesIssuedRaw,
		--	DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=6\s{0,8}Purpose\s{0,8}of\s{0,8}the\s{0,8}issue.{0,200}those\s{0,8}assets).*(?=6a\s{0,8}Is\s{0,8}the\s{0,8}entity)') as PurposeOfIssueRaw,
		--	DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=7\s{1,5}\+{0,1}Issue\s{1,5}dates\s{0,5}.{0,500}of\s{1,5}Appendix\s{1,5}3B\.{0,1}\s{1,5}).*(?=8\s{1,5}Number\s{1,5}and\s{1,5}\+{0,1}class)') as IssueDateRaw,
		--	coalesce
		--	(
		--		DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=8\s{1,5}number\s{1,5}and\s{1,5}.{0,500}if\s{1,5}applicable\s{1,5}Number\s{1,5}).*(?=\+{1}Class\s{1,5}(Ord|Ordinary)\s{1,5}Fully)'),
		--		DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=8\s{1,5}number\s{1,5}and\s{1,5}.{0,500}if\s{1,5}applicable\s{1,5}).*(?=Fully\s{1,5}Paid\s{1,5}(Ord|Ordinary)\s{1,5}Share)')
		--	)	 as TotalSharesOnASXRaw,
		--	cast(null as varchar(200)) as IssuePrice,
		--	cast(null as varchar(200)) as SharesIssued,
		--	cast(null as varchar(max)) as PurposeOfIssue,
		--	cast(null as varchar(200)) as IssueDate,
		--	cast(null as varchar(200)) as TotalSharesOnASX,
		--	cast(null as bit) as IsPlacement,
		--	CleansedAnnContent
		--into #TempAppendix3BParsed
		--from #TempAppendix3B

		if object_id(N'Tempdb.dbo.#TempAppendix3BParsed') is not null
			drop table #TempAppendix3BParsed

		select 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			coalesce(
				nullif(nullif(nullif(rtrim(ltrim(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=an\s{0,8}estimate\s{0,80}.{0,500}response\s{0,8}to\s{0,8}Q4\.2\sis\s{0,8}no.\s{0,8}.).*?(?=\s{0,8}4\.3)'))), ''), 'N A'), ' Nil'),
				nullif(nullif(nullif(rtrim(ltrim(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=Q4\.2d\.{0,8}.\s{0,8}).*?(?=\s{0,8}per\s{0,8}share)'))), ''), 'N A'), ' Nil'),
				nullif(nullif(nullif(rtrim(ltrim(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=Q4\.2d\.{0,8}.\s{0,8}).*?(?=\s{0,8}4.2c\s{0,8}Please)'))), ''), 'N A'), ' Nil')
			) as IssuePriceRaw,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=Number\s{0,8}of\s{0,8}\+securities\s{0,8}to\s{0,8}be\s{0,8}quoted).+?(?=\s{0,8}Part\s{0,8}3B)') as SharesIssuedRaw,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=3A\.1\.{0,8}.{0,100}description\s{0,8}).*?(?=\s{0,8}3A.2\s{0,8}Number)') as PurposeOfIssueRaw,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=your\s{0,80}response\s{0,80}to\s{0,80}Q4.1\s{0,8}is\s{0,8}Yes\s{0,10}\.).*?(?=\s{0,8}4.1b\s{0,8}What)') as IssueDateRaw,
			coalesce
			(
				DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=8\s{1,5}number\s{1,5}and\s{1,5}.{0,500}if\s{1,5}applicable\s{1,5}Number\s{1,5}).*(?=\+{1}Class\s{1,5}(Ord|Ordinary)\s{1,5}Fully)'),
				DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=8\s{1,5}number\s{1,5}and\s{1,5}.{0,500}if\s{1,5}applicable\s{1,5}).*(?=Fully\s{1,5}Paid\s{1,5}(Ord|Ordinary)\s{1,5}Share)')
			)	 as TotalSharesOnASXRaw,
			cast(null as varchar(200)) as IssuePrice,
			cast(null as varchar(200)) as SharesIssued,
			cast(null as varchar(max)) as PurposeOfIssue,
			cast(null as varchar(200)) as IssueDate,
			cast(null as varchar(200)) as TotalSharesOnASX,
			cast(null as bit) as IsPlacement,
			CleansedAnnContent
		into #TempAppendix3BParsed
		from #TempAppendix3B
		--where ASXCode = 'MGV.AX'
		order by AnnDateTime
		
		update a
		set IssuePrice = 
			coalesce
			(
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '[0-9.]{1,8}(?=\s{1,5}(per|each)\s{1,5}share)'),
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '[0-9.]{1,8}(?=\s{1,5}(per|each)\s{1,5}(?:common\s)*share)'),
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '[0-9.]{1,8}(?=\s{1,5}(per|each)\s{1,5}fully\s{1,5}paid\s{1,5}.{0,10}share)'),
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '[0-9.]{1,8}(?=\s{1,5}(per|each)\s{1,5}.{0,20}security)'),
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '(?<=Issue\s{1,5}price\s{1,5}.{0,10}\s{1,5})[0-9.]{1,8}(?=\s{1,5})'),
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '[0-9.]{1,8}\s{0,3}(c|cents|cent)*(?=\s{1,5}(?:cash\s)*(per|each)\s{1,5}(?:new\s)*(?:fully\s)*(?:paid\s)*(?:common\s)*(?:ordinary\s)*share)'),
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssuePriceRaw)), '^[0-9.]{1,8}$')
			)
		from #TempAppendix3BParsed as a

		update a
		set IssuePrice = 
			case when IssuePrice like '%cents%' and try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cents', ''), '\s', '') as decimal(20, 4)) >= 1 then cast(try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cents', ''), '\s', '') as decimal(20, 4))*0.01 as varchar(200))
				 when IssuePrice like '%cents%' and try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cents', ''), '\s', '') as decimal(20, 4)) < 1 then cast(try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cents', ''), '\s', '') as decimal(20, 4)) as varchar(200))
				 else IssuePrice
			end
		from #TempAppendix3BParsed as a
		
		update a
		set IssuePrice = 
			case when IssuePrice like '%cent%' and try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cent', ''), '\s', '') as decimal(20, 4)) >= 1 then cast(try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cent', ''), '\s', '') as decimal(20, 4))*0.01 as varchar(200))
				 when IssuePrice like '%cent%' and try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cent', ''), '\s', '') as decimal(20, 4)) < 1 then cast(try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'cent', ''), '\s', '') as decimal(20, 4)) as varchar(200))
				 else IssuePrice
			end
		from #TempAppendix3BParsed as a
		
		update a
		set IssuePrice = 
			case when IssuePrice like '%c%' and try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'c', ''), '\s', '') as decimal(20, 4)) >= 1 then cast(try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'c', ''), '\s', '') as decimal(20, 4))*0.01 as varchar(200))
				 when IssuePrice like '%c%' and try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'c', ''), '\s', '') as decimal(20, 4)) < 1 then cast(try_cast(DA_Utility.dbo.RegexReplace(replace(IssuePrice, 'c', ''), '\s', '') as decimal(20, 4)) as varchar(200))
				 else IssuePrice
			end
		from #TempAppendix3BParsed as a

		update a
		set SharesIssued = 
			coalesce
			(
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(SharesIssuedRaw)), '[0-9]{1,3}(,[0-9]{3})+'), 
				null
			)
		from #TempAppendix3BParsed as a

		update a
		set SharesIssued = 
			try_cast(DA_Utility.dbo.RegexReplace(replace(SharesIssued, ',', ''), '\s', '') as bigint)
		from #TempAppendix3BParsed as a

		update a
		set IssueDate = 
			coalesce
			(
				DA_Utility.dbo.RegexMatch(ltrim(rtrim(IssueDateRaw)), '(([0-9])|([0-2][0-9])|([3][0-1]))\s(Jan|January|Feb|Feburary|Mar|March|Apr|April|May|May|Jun|June|Jul|July|Aug|August|Sep|September|Oct|October|Nov|November|Dec|December)\s\d{4}'), 
				null
			)
		from #TempAppendix3BParsed as a

		set dateformat dmy

		update a
		set IssueDate = 
			try_cast(DA_Utility.dbo.RegexReplace(replace(IssueDate, ',', ''), '\s', '') as date)
		from #TempAppendix3BParsed as a
		where IssueDate is not null
		
		update a
		set IsPlacement = 1
		--select top 100 * 
		from #TempAppendix3BParsed as a
		where 
		(
			PurposeOfIssueRaw like '%Placement%'
			or
			PurposeOfIssueRaw like '%entitlement%'
			or
			PurposeOfIssueRaw like '%plans to use the funds for%'
			or
			PurposeOfIssueRaw like '%will apply the funds to%'		
			or
			PurposeOfIssueRaw like '%funds raised%'
			or
			PurposeOfIssueRaw like '%the issue will be used for%'
			or
			PurposeOfIssueRaw like '%Capital raised%'
			or
			PurposeOfIssueRaw like '%As per ASX release%'
			or
			PurposeOfIssueRaw like '%share purchase plan%'
			or
			PurposeOfIssueRaw like '% SPP %'
			or
			SharesIssuedRaw like '%Placement%'
			or
			SharesIssuedRaw like '%entitlement%'
			or
			SharesIssuedRaw like '%plans to use the funds for%'
			or
			SharesIssuedRaw like '%will apply the funds to%'		
			or
			SharesIssuedRaw like '%funds raised%'
			or
			SharesIssuedRaw like '%the issue will be used for%'
			or
			SharesIssuedRaw like '%Capital raised%'
			or
			SharesIssuedRaw like '%As per ASX release%'
			or
			SharesIssuedRaw like '%share purchase plan%'
			or
			SharesIssuedRaw like '% SPP %'
			or
			AnnDescr like '%Placement%'
			or
			AnnDescr like '%Capital Raise%'
		)

		update a
		set PurposeOfIssue = PurposeOfIssueRaw
		from #TempAppendix3BParsed as a 

		--delete a
		--from StockData.Appendix3B as a
		--inner join #TempAppendix3BParsed as b
		--on a.AnnouncementID = b.AnnouncementID

		insert into StockData.Appendix3B
		(
		   [AnnouncementID]
		  ,[ASXCode]
		  ,[AnnDateTime]
		  ,[AnnDescr]
		  ,[IssuePriceRaw]
		  ,[IssuePrice]
		  ,[SharesIssuedRaw]
		  ,[SharesIssued]
		  ,[PurposeOfIssue]
		  ,[CleansedAnnContent]
		  ,[IssueDateRaw]
		  ,[IssueDate]
		  ,[TotalSharesOnASXRaw]
		  ,[TotalSharesOnASX]
		  ,[IsPlacement]
		)
		select 
		   [AnnouncementID]
		  ,[ASXCode]
		  ,[AnnDateTime]
		  ,[AnnDescr]
		  ,[IssuePriceRaw]
		  ,try_cast([IssuePrice] as decimal(20, 4))
		  ,[SharesIssuedRaw]
		  ,try_cast([SharesIssued] as bigint)
		  ,[PurposeOfIssue]
		  ,[CleansedAnnContent]
		  ,[IssueDateRaw]
		  ,try_cast([IssueDate] as date)
		  ,[TotalSharesOnASXRaw]
		  ,try_cast([TotalSharesOnASX] as bigint)
		  ,[IsPlacement]
		from #TempAppendix3BParsed as a
		where not exists
		(
			select 1
			from StockData.Appendix3B
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

