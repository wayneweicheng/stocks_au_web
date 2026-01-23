-- Stored procedure: [HC].[usp_AddPostRaw]

CREATE PROCEDURE [HC].[usp_AddPostRaw]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchPostUrl as varchar(500),
@pvchPostDateTime as varchar(100),
@pvchPoster as varchar(200),
@pintPosterIsHeart bit,
@pvchPostContent varchar(max),
@pvchPostFooter varchar(max)
AS
/******************************************************************************
File: usp_AddPostRaw.sql
Stored Procedure Name: usp_AddPostRaw
Overview
-----------------
usp_AddPostRaw

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
Date:		2017-06-11
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddPostRaw'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'HC'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if len(@pvchPostUrl) > 0 and len(@pvchPostDateTime) > 0 and len(@pvchPoster) > 0 and len(@pvchPostFooter) > 0
		begin
			print 'OK'
		end
		else
		begin
			raiserror('Values not populated', 16, 0)
		end

		set dateformat dmy

		insert into HC.PostScan
		(
			ASXCode,
			CreateDate
		)
		select
			@pvchASXCode as ASXCode,
			getdate() as CreateDate
		
		insert into HC.PostRaw
		(
			ASXCode,
			PostUrl,
			PostDateTime,
			Poster,
			PosterIsHeart,
			PostContent,
			PostFooter,
			CreateDate,
			PriceAtPosting,
			Sentiment,
			Disclosure
		)
		select
			@pvchASXCode as ASXCode,
			@pvchPostUrl as PostUrl,
			cast(@pvchPostDateTime as smalldatetime) as PostDateTime,
			@pvchPoster as Poster,
			cast(@pintPosterIsHeart as bit) as PosterIsHeart,
			case when @pintPosterIsHeart = 1 then @pvchPostContent else null end as PostContent,
			@pvchPostFooter as PostFooter,
			getdate() as CreateDate,
			replace(DA_Utility.dbo.RegexMatch(replace(replace(replace(@pvchPostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Priceatposting:).{0,30}(?=</span>)'), '&cent;', 'c') as PriceAtPosting,
			DA_Utility.dbo.RegexMatch(replace(replace(replace(@pvchPostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Sentiment:).{0,30}(?=</span>)') as Sentiment,
			DA_Utility.dbo.RegexMatch(replace(replace(replace(@pvchPostFooter, ' ', ''), char(13), ''), char(10), ''), '(?<=Disclosure:).{0,30}(?=</span>)') as Disclosure
		where not exists
		(
			select 1
			from HC.PostRaw
			where PostUrl = @pvchPostUrl
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
