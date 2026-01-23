-- Stored procedure: [Report].[usp_CheckAnnouncementKeyword]





CREATE PROCEDURE [Report].[usp_CheckAnnouncementKeyword]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchKeyword as varchar(200)
AS
/******************************************************************************
File: usp_CheckAnnouncementKeyword.sql
Stored Procedure Name: usp_CheckAnnouncementKeyword
Overview
-----------------
usp_CheckAnnouncementKeyword

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
Date:		2016-06-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_CheckAnnouncementKeyword'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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

		if object_id(N'Tempdb.dbo.#TempASXCode') is not null
			drop table #TempASXCode

		if object_id(N'Tempdb.dbo.#TempASXCode1') is not null
			drop table #TempASXCode1

		if object_id(N'Tempdb.dbo.#TempASXCode2') is not null
			drop table #TempASXCode2

		declare @vchKeyword as varchar(200) = @pvchKeyword
		declare @vchToken1 as varchar(200) = rtrim(case when charindex(' ', @vchKeyword) > 0 then left(@vchKeyword, charindex(' ', @vchKeyword) -1) else @vchKeyword end)
		declare @vchToken2 as varchar(200) = rtrim(case when charindex(' ', reverse(@vchKeyword)) > 0 then reverse(left(reverse(@vchKeyword), charindex(' ', reverse(@vchKeyword)) -1)) else @vchKeyword end)
		
		if object_id(N'Tempdb.dbo.#TempSaleDateTime') is not null
			drop table #TempSaleDateTime

		if object_id(N'Tempdb.dbo.#TempSalePrice') is not null
			drop table #TempSalePrice

		if object_id(N'Tempdb.dbo.#TempASXAnn') is not null
			drop table #TempASXAnn

		SELECT distinct ASXCode 
		into #TempASXCode1
		FROM StockData.Announcement as a
		WHERE --ASXCode = 'KDR.AX'
		freetext(AnnContent,@vchToken1)

		SELECT distinct ASXCode 
		into #TempASXCode2
		FROM StockData.Announcement as a
		WHERE --ASXCode = 'KDR.AX'
		freetext(AnnContent,@vchToken2)

		select a.ASXCode
		into #TempASXCode
		from #TempASXCode1 as a
		inner join #TempASXCode2 as b
		on a.ASXCode = b.ASXCode

		select ASXCode, Max(SaleDateTime) as SaleDateTime
		into #TempSaleDateTime
		from StockData.CourseOfSale
		group by ASXCode

		select a.ASXCode, max(Price) as Price 
		into #TempSalePrice
		from StockData.CourseOfSale as a
		inner join #TempSaleDateTime as b
		on a.ASXCode = b.ASXCode
		and a.SaleDateTime = b.SaleDateTime
		group by a.ASXCode

		select a.ASXCode, b.Price, c.AnnContent, c.AnnDescr, c.AnnDateTime, c.AnnURL, c.AnnRetriveDateTime
		into #TempASXAnn
		from #TempASXCode as a
		inner join StockData.Announcement as c
		on a.ASXCode = c.ASXCode
		left join #TempSalePrice as b
		on a.ASXCode = b.ASXCode
		and b.Price < 15

		select 
			DA_Utility.dbo.[RegexMatch](AnnContent, '.{80}K.{0,50}'+@vchKeyword+'.{80}') as MatchText, 
			ASXCode, 
			Price,
			AnnDescr,
			AnnDateTime
		from #TempASXAnn as a
		where DA_Utility.dbo.[RegexMatch](AnnContent, '.{80}K.{0,50}'+@vchKeyword+'.{80}') is not null
		order by ASXCode, AnnDateTime desc


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
