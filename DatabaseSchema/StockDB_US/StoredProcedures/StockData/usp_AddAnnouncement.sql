-- Stored procedure: [StockData].[usp_AddAnnouncement]






CREATE PROCEDURE [StockData].[usp_AddAnnouncement]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchAnnRetriveDateTime as varchar(100),
@pvchAnnDate as varchar(50),
@pvchAnnTime as varchar(50),
@pintMarketSensitiveIndicator as int,
@pvchAnnDescr as varchar(200),
@pvchAnnURL as varchar(1000),
@pvchAnnContent as varchar(max),
@pintAnnNumPage as int
AS
/******************************************************************************
File: usp_AddAnnouncement.sql
Stored Procedure Name: usp_AddAnnouncement
Overview
-----------------
usp_AddAnnouncement

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
Date:		2016-08-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddAnnouncement'
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
		
		--@pxmlMarketDepth

		set dateformat dmy

		--declare @pvchAnnRetriveDateTime as varchar(100) = '10 Aug 11:49:16 PM'
		declare @dtRetriveDate as smalldatetime
		declare @vchModifiedDateTime as varchar(100)
		if try_cast(@pvchAnnRetriveDateTime as smalldatetime) is not null
		begin
			select @dtRetriveDate = try_cast(@pvchAnnRetriveDateTime as smalldatetime)
		end
		else
		begin
			select @vchModifiedDateTime = left(@pvchAnnRetriveDateTime, 7) + cast(year(getdate()) as varchar(4)) + ' ' + parsename(replace(@pvchAnnRetriveDateTime, ' ', '.'), 2) + ' ' + parsename(replace(@pvchAnnRetriveDateTime, ' ', '.'), 1)
		end
		
		--select cast(@vchModifiedDateTime as smalldatetime)

		--declare @pvchDateTime as varchar(100) = '25/08/2016 08:54AM'
		--select cast(@pvchDateTime  as smalldatetime)

		--select convert(smalldatetime, @vchModifiedDateTime, 113)
		declare @intAnnouncementID as int

		if not exists
		(
			select 1
			from StockData.Announcement
			where ASXCode = @pvchASXCode
			and AnnDescr = @pvchAnnDescr
			and AnnDateTime = cast(@pvchAnnDate + ' ' + @pvchAnnTime as smalldatetime)
		)
		begin
			insert into StockData.Announcement
			(
			   [ASXCode]
			  ,[AnnRetriveDateTime]
			  ,[AnnDateTime]
			  ,[MarketSensitiveIndicator]
			  ,[AnnDescr]
			  ,[AnnURL]
			  ,[AnnContent]
			  ,[AnnNumPage]
			  ,[CreateDate]
			)
			select
			   @pvchASXCode as [ASXCode]
			  ,isnull(@dtRetriveDate, cast(@vchModifiedDateTime as smalldatetime)) as [AnnRetriveDateTime]
			  ,cast(@pvchAnnDate + ' ' + @pvchAnnTime as smalldatetime) as [AnnDateTime]
			  ,@pintMarketSensitiveIndicator as [MarketSensitiveIndicator]
			  ,@pvchAnnDescr as [AnnDescr]
			  ,@pvchAnnURL as [AnnURL]
			  ,@pvchAnnContent as [AnnContent]
			  ,@pintAnnNumPage as [AnnNumPage]
			  ,getdate() as [CreateDate]

			select @intAnnouncementID = @@IDENTITY

			declare @vchSearchTerm as varchar(500)
			declare @vchSearchTermRegex as varchar(500)
			declare @vchSearchTermTypeID as varchar(20)
			declare @vchSearchTermNotes as varchar(max)
		    declare @vchRegexIntercept as varchar(500)
		    declare @vchRegexDepth as varchar(500)
		    declare @vchRegexGrade as varchar(500)
		    declare @intDepthMin as int
		    declare @decGradeMin as decimal(20, 5)
		    declare @vchActualIntercept as varchar(500)
		    declare @intActualDepth as int
		    declare @decActualGrade as decimal(20, 5)
			declare @bitSearchAnnDescrOnly as bit

			declare curSearchTerm cursor for
			select 
				SearchTerm,
				SearchTermRegex,
				SearchTermTypeID,
				SearchTermNotes,
			    [RegexIntercept],
			    [RegexDepth],
			    [RegexGrade],
			    [DepthMin],
			    [GradeMin],
				isnull(SearchAnnDescrOnly, 0) as SearchAnnDescrOnly
			from LookupRef.StockAnnSearchTerm
			where IsDisabled = 0

			declare @bitSMSSent as bit = 0

			open curSearchTerm
			fetch curSearchTerm into @vchSearchTerm, @vchSearchTermRegex, @vchSearchTermTypeID, @vchSearchTermNotes, @vchRegexIntercept, @vchRegexDepth, @vchRegexGrade, @intDepthMin, @decGradeMin, @bitSearchAnnDescrOnly

			while @@fetch_status = 0
			begin
				declare @bitIsMatch as bit = 0

				if @bitSearchAnnDescrOnly = 1
				begin
					if DA_Utility.dbo.RegexMatch(@pvchAnnDescr, @vchSearchTermRegex) is not null and @vchRegexIntercept is null
					begin
						select @bitIsMatch = 1
					end
				end
				else
				begin
					if DA_Utility.dbo.RegexMatch(@pvchAnnContent, @vchSearchTermRegex) is not null and @vchRegexIntercept is null
					begin
						select @bitIsMatch = 1
					end

					if DA_Utility.dbo.RegexMatch(@pvchAnnDescr, @vchSearchTermRegex) is not null and @vchRegexIntercept is null
					begin
						select @bitIsMatch = 1
					end
				end

				if @vchRegexIntercept is not null
				begin
					select @vchActualIntercept = DA_Utility.dbo.RegexMatch(@pvchAnnContent, @vchRegexIntercept)
					select @intActualDepth = try_cast(DA_Utility.dbo.RegexMatch(@vchActualIntercept, @vchRegexDepth) as decimal(20, 5))
					select @decActualGrade = try_cast(DA_Utility.dbo.RegexMatch(@vchActualIntercept, @vchRegexGrade) as decimal(20, 5))

					if @intActualDepth * @decActualGrade > @intDepthMin * @decGradeMin
					begin
						select @bitIsMatch = 1
					end
				end

				declare @decMC as decimal(20, 5)
				select @decMC = CleansedMarketCap
				from StockData.StockOverviewCurrent
				where ASXCode = @pvchASXCode

				declare @decClose as decimal(20, 5)
				select @decClose = [Close]
				from [StockData].[PriceHistoryCurrent]
				where ASXCode = @pvchASXCode

				if @decMC > 100
				begin
					select @bitIsMatch = 0
				end 

				if @decMC is null and @decClose > 0.80
				begin
					select @bitIsMatch = 0
				end 

				if 
				(
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Annual Report') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Full Year Statutory') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Notice of General Meeting') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Half Yearly') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Half-year') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Quarterly.{0, 80}Report') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Appendix 4C - quarterly') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Corporate Governance') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Notice of Annual General Meeting') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Quarterly Activities') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Quarterly Cashflow Report') is not null
					or
					DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Quarterly Report') is not null
					--or
					--DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Notice of Annual General Meeting') is not null
					--or
					--DA_Utility.dbo.RegexMatch(@pvchAnnDescr, 'Notice of Annual General Meeting') is not null
				)
				begin
					select @bitIsMatch = 0
				end

				if @bitIsMatch = 1
				begin
					DECLARE @pvchEmailRecipient varchar(200) = 'wayneweicheng@gmail.com'
					DECLARE @pvchEmailSubject varchar(2000) = 'Ann Search Term Match ' + @pvchASXCode
					DECLARE @pvchEmailBody varchar(max) = 
'
Ann Search Term has found matches.

ASX Code: ' + @pvchASXCode + '					
Ann Descr: ' + @pvchAnnDescr + '					
Ann DateTime: ' + @pvchAnnDate + ' ' + @pvchAnnTime + '					
Search Term: ' + @vchSearchTermRegex + '
Search Term Notes: ' + @vchSearchTermNotes + '	
Search Term Type ID: ' 	+ @vchSearchTermTypeID + '	
' + 
case when len(@vchActualIntercept) > 0 then 'Actual Intercept: ' + cast(@vchActualIntercept as varchar(500)) + '
' else '' 
end +
case when @decMC > 0 then 'Market Cap: ' + cast(@decMC as varchar(50)) + '
' else '' 
end +
case when @decClose > 0 then 'Last Close: ' + cast(@decClose as varchar(50)) + '
' else '' 
end 

					insert into StockData.AnnouncementAlert
					(
						AnnouncementID,
						SearchTerm,
						SearchTermNotes,
						SearchTermTypeID,
						MC,
						CreateDate
					)
					select
						@intAnnouncementID as AnnouncementID,
						@vchSearchTerm as SearchTerm,
						@vchSearchTermNotes as SearchTermNotes,
						@vchSearchTermTypeID as SearchTermTypeID,
						@decMC as MC,
						getdate() as CreateDate

					DECLARE @pintEventTypeID tinyint = 1

					-- TODO: Set parameter values here.

					EXECUTE [Utility].[usp_AddEmail] 
					   @pvchEmailRecipient = @pvchEmailRecipient
					  ,@pvchEmailSubject = @pvchEmailSubject
					  ,@pvchEmailBody = @pvchEmailBody
					  ,@pintEventTypeID = @pintEventTypeID

	--				if @bitSMSSent = 0
	--				begin

	--					select @pvchEmailRecipient = '61430710008@sms.messagebird.com'
	--					select @pvchEmailSubject = @pvchASXCode
	--					select @pvchEmailBody = 
	--@pvchASXCode + '					
	--' + @pvchAnnDescr + '					
	--' + @vchSearchTermRegex 

	--					EXECUTE [Utility].[usp_AddEmail] 
	--					   @pvchEmailRecipient = @pvchEmailRecipient
	--					  ,@pvchEmailSubject = @pvchEmailSubject
	--					  ,@pvchEmailBody = @pvchEmailBody
	--					  ,@pintEventTypeID = @pintEventTypeID

	--					select @bitSMSSent = 1

	--				end
					
				end
				
			fetch curSearchTerm into @vchSearchTerm, @vchSearchTermRegex, @vchSearchTermTypeID, @vchSearchTermNotes, @vchRegexIntercept, @vchRegexDepth, @vchRegexGrade, @intDepthMin, @decGradeMin, @bitSearchAnnDescrOnly
	
			end

			close curSearchTerm
			deallocate curSearchTerm

		end

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
