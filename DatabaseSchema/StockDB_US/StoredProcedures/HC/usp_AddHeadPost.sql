-- Stored procedure: [HC].[usp_AddHeadPost]

create PROCEDURE [HC].[usp_AddHeadPost]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchPostUrl as varchar(500),
@pvchPostDateTime as varchar(100),
@pvchPoster as varchar(200),
@pintPosterIsHeart bit,
@pvchPostSubject varchar(500),
@pvchRating varchar(100),
@pvchPostStats varchar(100)
AS
/******************************************************************************
File: usp_AddHeadPost.sql
Stored Procedure Name: usp_AddHeadPost
Overview
-----------------
usp_AddHeadPost

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
Date:		2017-11-17
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddHeadPost'
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
		if len(@pvchPostUrl) > 0 and len(@pvchPostDateTime) > 0 and len(@pvchPoster) > 0 and len(@pvchPostSubject) > 0
		begin
			print 'OK'
		end
		else
		begin
			raiserror('Values not populated', 16, 0)
		end

		set dateformat dmy
		
		insert into HC.HeadPost
		(
		   [ASXCode]
		  ,[PostUrl]
		  ,[PostDateTime]
		  ,[PostSubject]
		  ,[Poster]
		  ,[PosterIsHeart]
		  ,[Rating]
		  ,[PostStats]
		  ,[CreateDate]
		)
		select
			@pvchASXCode as ASXCode,
			@pvchPostUrl as PostUrl,
			cast(@pvchPostDateTime as smalldatetime) as PostDateTime,
			rtrim(ltrim(@pvchPostSubject)) as [PostSubject],
			rtrim(ltrim(@pvchPoster)) as Poster,
			cast(@pintPosterIsHeart as bit) as PosterIsHeart,
			rtrim(ltrim(@pvchRating)) as Rating,
			rtrim(ltrim(@pvchPostStats)) as [PostStats],
			getdate() as CreateDate
		where not exists
		(
			select 1
			from HC.HeadPost
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
