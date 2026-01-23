-- Stored procedure: [StockData].[usp_RefeshCashPosition]







CREATE PROCEDURE [StockData].[usp_RefeshCashPosition]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshCashPosition.sql
Stored Procedure Name: usp_RefeshCashPosition
Overview
-----------------
usp_RefeshCashPosition

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshCashPosition'
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
		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			AnnContent,
			replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' ') as CleansedAnnContent, 
			DA_Utility.dbo.RegexMatch(replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' '), '(?<=cash.{0,80}\send\s.{0,10}[quarter|period|month].{0,20}\s)[\,0-9]{2,20}') as CashPositionRaw, 
			case when AnnContent like '%A_000%' then 1 else 0 end as ValueInAUDK,
			case when AnnContent like '%USD_000%' then 1 else 0 end as ValueInUSDK,
			cast(null as varchar(50)) as CashPositionVarchar,
			cast(null as bigint) as CashPosition
		into #TempCashPosition
		from StockData.Announcement as a
		where 
		(
			AnnDescr like '%Cash Flow%'
			or
			AnnDescr like '%CashFlow%'
			or
			' ' + AnnDescr + ' ' like '% 4C %'
			or
			AnnDescr like '%Appendix 4C%'
			or
			AnnDescr like '%Quarterly Activities Report%'
			or
			AnnDescr like '%Quarter%Statement%'
		)
		--and ASXCode = 'ICI.AX'
		--and not exists
		--(
		--	select 1
		--	from StockData.CashPosition
		--	where AnnouncementID = a.AnnouncementID
		--)
		order by AnnRetriveDateTime desc

		update a
		set CashPositionRaw = DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=4.6.{0,80})[\,0-9]{2,20}')
		from #TempCashPosition as a
		where CashPositionRaw is null
		and len(CleansedAnnContent) > 0
		and DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=4.6.{0,80})[\,0-9]{2,20}') is not null

		update a
		set CashPositionVarchar = replace(replace(CashPositionRaw, ',', ''), ' ', '')
		from #TempCashPosition as a

		update a
		set CashPosition = try_cast(CashPositionVarchar as int)
		from #TempCashPosition as a

		update a
		set CashPosition = case when ValueInAUDK = 1 then 1*CashPosition
								when ValueInUSDK = 1 then 1.38*1*CashPosition
								else CashPosition
						   end
		from #TempCashPosition as a

		update a
		set a.CashPosition = case when a.CashPosition/1000.0 > b.MC*3 then a.CashPosition/1000.0 
								  else a.CashPosition
							 end
		from #TempCashPosition as a
		inner join [StockData].[v_CompanyFloatingShare] as b
		on a.ASXCode = b.ASXCode

		--update a
		--set a.CashPosition = case when a.CashPosition > b.CashPosition*100 then a.CashPosition/1000.0 
		--						  when b.CashPosition > a.CashPosition*100 then a.CashPosition*1000.0 
		--						  else a.CashPosition
		--					 end
		--from #TempCashPosition as a
		--inner join 
		--(
		--	select
		--		ASXCode,
		--		avg(CashPosition) as CashPosition
		--	from StockData.CashPosition
		--	group by ASXCode
		--) as b
		--on a.ASXCode = b.ASXCode

		delete a
		from StockData.CashPosition as a
		inner join #TempCashPosition as b
		on a.AnnouncementID = b.AnnouncementID

		insert into StockData.CashPosition
		(
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			ValueInAUDK,
			ValueInUSDK,
			CashPosition
		)
		select
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			ValueInAUDK,
			ValueInUSDK,
			CashPosition
		from #TempCashPosition as a
		where not exists
		(
			select 1
			from StockData.CashPosition
			where AnnouncementID = a.AnnouncementID
		)
		and CashPosition is not null

		delete a
		from StockData.CashPosition as a
		where AnnDescr like '%Activities%'
		and AnnDescr not like '%cashflow%'
		and exists
		(
			select 1
			from StockData.CashPosition
			where ASXCode = a.ASXCode
			and cast(AnnDateTime as date) = cast(a.AnnDateTime as date)
			and AnnDescr like '%cashflow%'
			and AnnouncementID != a.AnnouncementID
		)

		update a
		set a.CashPosition = b.CashPosition
		from StockData.CashPosition as a
		inner join #TempCashPosition as b
		on a.AnnouncementID = b.AnnouncementID
		and a.CashPosition != b.CashPosition

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

