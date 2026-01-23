-- Stored procedure: [DataMaintenance].[usp_RefreshDirectorBuySignificantHolderChange]





create PROCEDURE [DataMaintenance].[usp_RefreshDirectorBuySignificantHolderChange]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshAlertStatsHistory.sql
Stored Procedure Name: usp_RefreshAlertStatsHistory
Overview
-----------------
usp_RefreshAlertStatsHistory

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
Date:		2019-09-08
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshAlertStatsHistory'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempDirBuy') is not null
			drop table #TempDirBuy

		select distinct
		d.ASXCode,
		e.CleansedMarketCap, 
		DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Value/Consideration.{0,180})[$0-9\,\.]+(?=\s{0,10}(\(.{0,80}\)){0,1}\s{0,10}(Appendix|No\. of securities))') as ValueConsideration, 
		DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Value/Consideration.{0,180})[$0-9\,\.]+(?=\s{0,10}(\(.{0,80}\)){0,1}\s{0,10}(per.{0,20}share|per.{0,20}stock))') as ValueConsiderationPerShare,
		DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Number acquired\s{0,5})[0-9\,]+(?=\s{0,10}.{0,30}Number disposed)') as NumAcquired,
		DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Number disposed\s{0,5})[0-9\,]+(?=\s{0,10}.{0,30}Value/Consideration)') as NumDisposed,
		d.AnnDescr,
		d.AnnDateTime
		into #TempDirBuy
		from StockData.Announcement as d
		left join StockData.CompanyInfo as e
		on d.ASXCode = e.ASXCode
		where d.AnnDescr like ('Change of Director% Notice%')
		and 
		(
			DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<!Example:\s)on[-\s]market (trade|purchase|buy|acquire)') is not null
			or
			DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<!Example:\s)on[-\s]market') is not null
		)
		and datediff(day, d.AnnDateTime, getdate()) < 90
		and DA_Utility.dbo.RegexMatch(d.AnnContent, '(?<=Number disposed\s{0,5})[0-9\,]+(?=\s{0,10}.{0,30}Value/Consideration)') is null
		
		delete a
		from #TempDirBuy as a
		where try_cast(replace(replace(replace(replace(ValueConsideration, '$', ''), ' ', ''), '.', ''), ',', '') as int) < 10000;

		delete a
		from #TempDirBuy as a
		where CleansedMarketCap > 10000

		if object_id(N'Tempdb.dbo.#TempSignificantHolder') is not null
			drop table #TempSignificantHolder

		select distinct
		d.ASXCode,
		e.CleansedMarketCap, 
		d.AnnDescr,
		d.AnnDateTime
		into #TempSignificantHolder
		from StockData.Announcement as d
		left join StockData.CompanyInfo as e
		on d.ASXCode = e.ASXCode
		where 
		(
			d.AnnDescr in ('Becoming a substantial holder')
			or 
			(d.AnnDescr in ('Change in substantial holding') and DA_Utility.dbo.RegexMatch(d.AnnContent, 'acquisition of shares') is not null)
		)
		and datediff(day, d.AnnDateTime, getdate()) < 90

		if object_id(N'StockData.DirectorBuyOnMarket') is not null
			drop table StockData.DirectorBuyOnMarket
		
		select *
		into StockData.DirectorBuyOnMarket
		from #TempDirBuy

		if object_id(N'StockData.SignificantHolder') is not null
			drop table StockData.SignificantHolder
				
		select *
		into StockData.SignificantHolder
		from #TempSignificantHolder

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
