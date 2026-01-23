-- Stored procedure: [HC].[usp_GetQualityPosterSearchString]


--exec [HC].[usp_GetQualityPosterSearchString]
--@pvchASXCode = 'EVS.AX'

CREATE PROCEDURE [HC].[usp_GetQualityPosterSearchString]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchHCSearchString as varchar(max) output
AS
/******************************************************************************
File: usp_GetPoster.sql
Stored Procedure Name: usp_GetPoster
Overview
-----------------
usp_GetPoster

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
Date:		2017-12-31
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetQualityPoster'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'HC'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--https://hotcopper.com.au/search/1234/?q=*&t=post&o=date&c[visible]=true&c[user][0]=27174&c[user][1]=206736&c[user][2]=39670&c[user][3]=196368&c[user][4]=22600&c[user][5]=414&c[user][6]=90111&c[user][7]=197607&c[user][8]=495502&c[user][9]=72459&c[user][10]=89692&c[user][11]=79001&c[user][12]=141659&c[user][13]=162696&c[user][14]=113583&c[user][15]=306824&c[user][16]=38728&c[user][17]=230361&c[user][18]=74458&c[user][19]=55655&c[user][20]=8564&c[user][21]=201634&c[user][22]=228823&c[user][23]=56073&c[user][24]=159176&c[user][25]=103952&c[user][26]=125184&c[user][27]=220678&c[user][28]=39254&c[user][29]=154492&c[user][30]=55296&c[user][31]=32945&c[user][32]=122401&c[user][33]=210067&c[user][34]=83792&c[user][35]=18860&c[user][36]=358758&c[user][37]=21297&c[tags][0]=PET (ASX)
		
		--Code goes here 
		declare @vchSearchString as varchar(max) = 'https://hotcopper.com.au/search/9999999/?q=*&t=post&o=date&c[visible]=true'
		declare @intUserID as int
		declare @intNumber as int = 0
		declare curQualityPoster cursor for
		select UserId
		from HC.QualityPoster 
		where UserID is not null
		and Poster not in ('h00ts')
		and Rating <= 30

		open curQualityPoster
		fetch curQualityPoster into @intUserID
		while @@fetch_status = 0
		begin
			print @intUserID
			select @vchSearchString = @vchSearchString + '&c[user][' + cast(@intNumber as varchar(10)) + ']=' + cast(@intUserID as varchar(10))
			select @intNumber = @intNumber + 1
			fetch curQualityPoster into @intUserID
		end

		close curQualityPoster
		deallocate curQualityPoster

		select @vchSearchString = @vchSearchString + '&c[tags][0]=' + left(@pvchASXCode, 3) + ' (ASX)'
		--select @vchSearchString 

		select @pvchHCSearchString = @vchSearchString 

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
