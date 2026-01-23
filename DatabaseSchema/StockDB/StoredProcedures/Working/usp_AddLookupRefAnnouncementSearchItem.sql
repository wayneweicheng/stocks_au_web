-- Stored procedure: [Working].[usp_AddLookupRefAnnouncementSearchItem]


CREATE PROCEDURE [Working].[usp_AddLookupRefAnnouncementSearchItem]
@pbitDebug AS BIT = 0,
@pvchBrokerCode as varchar(20) = '',
@pintLookupNumDay as int = 5,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_SelectPriceReverse.sql
Stored Procedure Name: usp_SelectPriceReverse
Overview
-----------------
usp_SelectPriceReverse

Input Parameters
----------------
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
Date:		2018-08-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_PlaceOrder'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Working'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		create table LookupRef.AnnouncementSearchItem
		(
			SearchItemID int identity(1, 1) not null,
			SearchItemName varchar(100) not null,
			SearchItemDescr varchar(500) null,
			FullTextSearch varchar(200) null,
			Regex1 varchar(500) null,
			Regex2 varchar(500) null,
			AnnSearchToDate date,
			CreateDate smalldatetime
		)

		insert into LookupRef.AnnouncementSearchItem
		(
			SearchItemName,
			SearchItemDescr,
			FullTextSearch,
			Regex1,
			Regex2,
			CreateDate
		)
		select
			'Lead Manager - CPS Capital' as SearchItemName,
			'Lead Manager - CPS Capital' as SearchItemDescr,
			'CPS' as FullTextSearch,
			'Lead\s{1,3}Manager(\s|.){0,80}CPS\s{1,3}Capital(\s|.){0,80}' as Regex1,
			'(.|\s){0,80}Lead\s{1,3}Manager(\s|.){0,80}CPS\s{1,3}Capital(\s|.){0,80}' as Regex2,
			getdate() as CreateDate

		select * from LookupRef.AnnouncementSearchItem

		update a
		set AnnSearchToDate = '2021-04-30'
		from LookupRef.AnnouncementSearchItem as a
		where AnnSearchToDate is not null

		select *
		from StockData.AnnouncementSearchResult as a
		inner join LookupRef.AnnouncementSearchItem as b
		on a.SearchItemID = b.SearchItemID
		where 1 = 1
		ORDER BY a.CreateDate DESC;

		select *
		from StockData.Announcement
		where ASXCode = 'CHR.AX'
		ORDER BY 1 DESC;

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