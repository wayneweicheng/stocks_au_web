-- Stored procedure: [StockData].[usp_RefeshStockSectorList]






CREATE PROCEDURE [StockData].[usp_RefeshStockSectorList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshStockSectorList.sql
Stored Procedure Name: usp_RefeshStockSectorList
Overview
-----------------
usp_EndUpdate

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
Date:		2016-06-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshStockSectorList'
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
		exec [StockData].[usp_TokenizeAnnouncement]

		declare @nvchGenericQuery as nvarchar(max) = ''
		declare @vchToken as varchar(100)
		declare @decCutOffThreshold as decimal(10, 2)
		declare @vchTokenSearchTerm as varchar(200)
		declare @vchTokenSearchRegex as varchar(500)
		declare curKeyToken cursor for
		select a.Token, CutOffThreshold, b.TokenSearchTerm, b.TokenSearchRegex
		from LookupRef.KeyToken as a
		inner join LookupRef.KeyTokenSearchTerm as b
		on a.Token = b.Token
		where TokenType = 'Sector'

		if object_id(N'Working.StockKeyToken') is not null
			drop table Working.StockKeyToken
		
		select *
		into Working.StockKeyToken
		from StockData.StockKeyToken
		where 1 > 1

		open curKeyToken
		fetch curKeyToken into @vchToken, @decCutOffThreshold, @vchTokenSearchTerm, @vchTokenSearchRegex

		while @@fetch_status = 0
		begin
			print @vchToken
			declare @vchTokenPart1 as varchar(100) = case when charindex(' ', @vchTokenSearchTerm, 0) > 0 then left(@vchTokenSearchTerm, charindex(' ', @vchTokenSearchTerm, 0) - 1) else @vchTokenSearchTerm end
			declare @vchTokenPart2 as varchar(100) = case when charindex(' ', @vchTokenSearchTerm, 0) > 0 then reverse(left(reverse(@vchTokenSearchTerm), charindex(' ', reverse(@vchTokenSearchTerm), 0) - 1)) else @vchTokenSearchTerm end

			--select @vchTokenPart1
			--select @vchTokenPart2

			select @nvchGenericQuery = ''

			insert into Working.StockKeyToken
			(
				Token,
				ASXCode,
				TokenCount,
				AnnCount,
				TokenPerAnn,
				CreateDate,
				AnnWithTokenPerc
			)
			select 
				@vchToken,
				x.ASXCode, 
				null as TokenCount,
				x.Num as AnnCount,
				null as TokenPerAnn,
				getdate() as CreateDate,
				x.Num*1.0/y.Num as AnnWithTokenPerc
			from
			(
				SELECT a.ASXCode, count(*) as Num
				FROM StockData.Announcement as a
				inner join Stock.ASXCompany as b
				on a.ASXCode = b.ASXCode
				WHERE freetext(AnnContent, @vchTokenPart1)
				and 
				(
					DA_Utility.dbo.RegexMatch(AnnContent, @vchTokenSearchRegex) is not null
					--replace(AnnContent, b.ASXCompanyName, '') like '% ' + @vchToken + ' %'
					--or
					--AnnContent like '%results are expected%'
					--or
					--AnnContent like '%result is expected%'
					--or
					--AnnContent like '%expected in October%'

				)
				and datediff(day, AnnDateTime, getdate()) < 180
				and AnnDescr not in ('Trading Halt', 'Response to ASX Price Query', 'Appendix 4C - quarterly', 'Company Update')
				and exists
				(
					select 1
					from StockData.AnnouncementToken
					where AnnouncementID = a.AnnouncementID
					and Token = @vchTokenPart1
					and Cnt >= 2
				)
				group by a.ASXCode
			) as x
			inner join
			(
				SELECT distinct ASXCode, count(*) as Num
				FROM StockData.Announcement 
				where datediff(day, AnnDateTime, getdate()) < 180
				and AnnDescr not in ('Trading Halt', 'Response to ASX Price Query', 'Appendix 4C - quarterly', 'Company Update')
				group by ASXCode
			) as y
			on x.ASXCode = y.ASXCode
			--where x.Num*1.0/y.Num > @decCutOffThreshold		

			fetch curKeyToken into @vchToken, @decCutOffThreshold, @vchTokenSearchTerm, @vchTokenSearchRegex
		end

		close curKeyToken
		deallocate curKeyToken

		delete a
		from Working.StockKeyToken as a
		inner join StockData.v_StockStatsHistoryLatest as b
		on a.ASXCode = b.ASXCode
		where b.[Close] > 2.0

		if object_id(N'Tempdb.dbo.#TempToRemove') is not null
			drop table #TempToRemove

		select c.ASXCode, a.Token, count(*) as Num
		into #TempToRemove
		from StockData.AnnouncementToken as a
		inner join LookupRef.KeyToken as b
		on a.Token = b.Token
		and b.TokenType = 'Sector'
		inner join StockData.Announcement as c
		on a.AnnouncementID = c.AnnouncementID
		group by a.Token, c.ASXCode

		delete a
		from Working.StockKeyToken as a
		inner join #TempToRemove as b
		on a.ASXCode = b.ASXCode
		and a.Token = b.Token
		and b.Num < 3 

		delete a
		from Working.StockKeyToken as a
		inner join
		(
			select
				ASXCode, Token, Num, RowNumber
			from
			(
				select
					ASXCode, Token, Num, row_number() over (partition by ASXCode order by Num desc) as RowNumber
				from #TempToRemove
			) as a
			where RowNumber > 3
		) as b
		on a.ASXCode = b.ASXCode
		and a.Token = b.Token

		if object_id(N'StockData.StockNature') is not null
			drop table StockData.StockNature

		select 
		   min([StockKeyTokenID]) as [StockKeyTokenID]
		  ,[Token]
		  ,[ASXCode]
		  ,sum([TokenCount]) as [TokenCount]
		  ,sum([AnnCount]) as [AnnCount]
		  ,max([TokenPerAnn]) as [TokenPerAnn]
		  ,min([CreateDate]) as [CreateDate]
		  ,max([AnnWithTokenPerc]) as [AnnWithTokenPerc]
		into StockData.StockNature
		from Working.StockKeyToken
		group by 
		   [Token]
		  ,[ASXCode]

		--delete a
		--from Working.StockKeyToken as a
		--inner join LookupRef.StockKeyToken as b
		--on a.Token = b.Token

		insert into Working.StockKeyToken
		(
		   [Token]
		  ,[ASXCode]
		  ,[TokenCount]
		  ,[AnnCount]
		  ,[TokenPerAnn]
		  ,[CreateDate]
		  ,[AnnWithTokenPerc]
		)
		select 
		   [Token]
		  ,[ASXCode]
		  ,null as [TokenCount]
		  ,null as [AnnCount]
		  ,null as [TokenPerAnn]
		  ,getdate() as [CreateDate]
		  ,null as [AnnWithTokenPerc]
		from LookupRef.StockKeyToken as a
		where not exists
		(
			select 1
			from Working.StockKeyToken
			where Token = a.Token
			and ASXCode = a.ASXCode
		)

		if object_id(N'Tempdb.dbo.#TempStockKeyToken2') is not null
			drop table #TempStockKeyToken

		select
		   [Token]
		  ,[ASXCode]
		  ,max([TokenCount]) as [TokenCount]
		  ,max([AnnCount]) as [AnnCount]
		  ,max([TokenPerAnn]) as [TokenPerAnn]
		  ,max([CreateDate]) as [CreateDate] 
		  ,max([AnnWithTokenPerc]) as [AnnWithTokenPerc]
		into #TempStockKeyToken2
		from Working.StockKeyToken
		group by
		   [Token]
		  ,[ASXCode]

		delete a
		from StockData.StockKeyToken as a
		inner join LookupRef.KeyToken as c
		on a.Token = c.Token
		left join #TempStockKeyToken2 as b
		on a.Token = b.Token
		and a.ASXCode = b.ASXCode
		where b.ASXCode is null
		and c.TokenType = 'Sector'

		insert into StockData.StockKeyToken
		(
		   [Token]
		  ,[ASXCode]
		  ,[TokenCount]
		  ,[AnnCount]
		  ,[TokenPerAnn]
		  ,[CreateDate]
		  ,[AnnWithTokenPerc]
		)
		select
		   [Token]
		  ,[ASXCode]
		  ,[TokenCount]
		  ,[AnnCount]
		  ,[TokenPerAnn]
		  ,[CreateDate]
		  ,[AnnWithTokenPerc]
		from #TempStockKeyToken2 as a
		where not exists
		(
			select 1
			from StockData.StockKeyToken as x
			inner join LookupRef.KeyToken as y
			on x.Token = y.Token
			and y.TokenType = 'Sector'
			and x.Token = a.Token
			and x.ASXCode = a.ASXCode
		)

		if object_id(N'Tempdb.dbo.#TempStockKeyToken') is not null
			drop table #TempStockKeyToken

		select distinct
			upper(a.Token) as Token,
			a.ASXCode,
			a.AnnWithTokenPerc,
			case when b.ASXCode is not null then 1 else 0 end ListVerified
		into #TempStockKeyToken
		from StockData.StockKeyToken as a
		left join LookupRef.StockKeyToken as b
		on a.Token = b.Token
		and a.ASXCode = b.ASXCode

		delete x
		from StockData.StockKeyToken as x
		inner join LookupRef.KeyToken as z
		on x.Token = z.Token
		and z.TokenType = 'Sector'
		inner join
		(
			select a.ASXCode, a.Token
			from #TempStockKeyToken as a
			where exists
			(
				select 1
				from #TempStockKeyToken
				where 1.5 * a.AnnWithTokenPerc < AnnWithTokenPerc
				and a.ASXCode = ASXCode
			)
			and a.ListVerified = 0
		) as y
		on x.ASXCode = y.ASXCode
		and x.Token = y.Token

		delete x
		from #TempStockKeyToken as x
		inner join LookupRef.KeyToken as z
		on x.Token = z.Token
		and z.TokenType = 'Sector'
		inner join
		(
			select a.ASXCode, a.Token
			from #TempStockKeyToken as a
			where exists
			(
				select 1
				from #TempStockKeyToken
				where 1.5 * a.AnnWithTokenPerc < AnnWithTokenPerc
				and a.ASXCode = ASXCode
			)
			and a.ListVerified = 0
		) as y
		on x.ASXCode = y.ASXCode
		and x.Token = y.Token

		delete x
		from StockData.StockKeyToken as x
		inner join LookupRef.KeyToken as z
		on x.Token = z.Token
		and z.TokenType = 'Sector'
		inner join
		(
			select a.ASXCode, a.Token
			from #TempStockKeyToken as a
			where exists
			(
				select 1
				from #TempStockKeyToken
				where 
				(
					a.Token != Token
					and
					a.Token not like '%' + Token + '%'
					and
					Token not like '%' + a.Token + '%'
				)
				and a.ASXCode = ASXCode
			)
			and a.ListVerified = 0
		) as y
		on x.ASXCode = y.ASXCode
		and x.Token = y.Token
		
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
