-- Stored procedure: [StockData].[usp_TokenizeAnnouncement]






CREATE PROCEDURE [StockData].[usp_TokenizeAnnouncement]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
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
		if object_id(N'StockData.AnnouncementSample') is not null
			drop table StockData.AnnouncementSample

		select *
		into StockData.AnnouncementSample
		from StockData.Announcement as a
		where not exists
		(
			select 1
			from StockData.AnnouncementToken
			where AnnouncementID = a.AnnouncementID
		)

		update a
		set AnnContent = DA_Utility.[dbo].[RegexReplace](AnnContent, '[^\w\s]', ' ')
		from StockData.AnnouncementSample as a
		where DA_Utility.[dbo].[RegexMatch](AnnContent, '[^\w\s]') is not null

		update a
		set AnnContent = DA_Utility.[dbo].[RegexReplace](AnnContent, '\s', ' ')
		from StockData.AnnouncementSample as a
		where DA_Utility.[dbo].[RegexMatch](AnnContent, '\s') is not null

		update a
		set AnnContent = replace(AnnContent, '  ', ' ')
		from StockData.AnnouncementSample as a

		if object_id(N'Working.AnnouncementToken') is not null 
			drop table Working.AnnouncementToken

		select 
				PassedID as AnnouncementID,
				b.StrValue as Token
		into Working.AnnouncementToken
		from StockData.AnnouncementSample as a
		cross apply DA_Utility.dbo.ufn_ParseStringByDelimiter(a.AnnouncementID, ' ', ltrim(rtrim(AnnContent))) as b
		where charindex(' ', ltrim(rtrim(a.AnnContent)), 0) > 0

		--REMOVE THE STOP ENGLISH WORDS
		alter table Working.AnnouncementToken
		alter column Token varchar(1000) collate SQL_Latin1_General_CP1_CI_AS

		delete a
		from Working.AnnouncementToken as a
		inner join LookupRef.EnglishStopWord as b
		on a.Token = b.EnglishStopWord

		delete a
		from Working.AnnouncementToken as a
		where Token not like '%[a-z]%'

		update a
		set Token = replace(replace(replace(Token, char(10), ''), char(13), ''), char(9), '')
		from Working.AnnouncementToken as a

		update a
		set Token = rtrim(ltrim(Token))
		from Working.AnnouncementToken as a

		delete a
		from Working.AnnouncementToken as a
		where not len(Token) > 1

		delete a
		from Working.AnnouncementToken as a
		inner join LookupRef.EnglishStopWord as b
		on a.Token = b.EnglishStopWord

		delete a
		from Working.AnnouncementToken as a
		inner join LookupRef.StockStopWord as b
		on a.Token = b.StockStopWord

		delete a
		from Working.AnnouncementToken as a
		where len(Token) > 50

		insert into StockData.AnnouncementToken
		(
			 AnnouncementID
			,[Token]
			,[Cnt]
			,[CreateDate]
		)
		select
			 AnnouncementID
			,Token as [Token]
			,count(Token) as [Cnt]
			,getdate() as [CreateDate]
		from Working.AnnouncementToken
		group by AnnouncementID, Token
		


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
