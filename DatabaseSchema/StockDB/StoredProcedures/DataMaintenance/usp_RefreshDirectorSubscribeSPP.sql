-- Stored procedure: [DataMaintenance].[usp_RefreshDirectorSubscribeSPP]



CREATE PROCEDURE [DataMaintenance].[usp_RefreshDirectorSubscribeSPP]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshDirectorSubscribeSPP.sql
Stored Procedure Name: usp_RefreshDirectorSubscribeSPP
Overview
-----------------
usp_RefreshDirectorSubscribeSPP

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
Date:		2020-06-29
Author:		WAYNE CHENG
Description: usp_Get_Strategy_BreakoutRetrace
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshDirectorSubscribeSPP'
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
		--begin transaction
		--declare @pintNumPrevDay as int = 3
		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select *
		into #TempCashPosition
		from 
		(
		select 
			*, 
			row_number() over (partition by ASXCode order by AnnDateTime desc) as RowNumber
		from StockData.CashPosition
		) as x
		where RowNumber = 1

		delete a
		from #TempCashPosition as a
		where datediff(day, AnnDateTime, getdate()) > 105

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempDirectorSubscribeSPP') is not null
			drop table #TempDirectorSubscribeSPP

		select cast(getdate() as date) as ObservationDate, 'DirectorInSPP' as ReportType, a.ASXCode, cast(getdate() as date) as MarketDate, a.AnnDescr, a.AnnDateTime, b.MC, b.CashPosition, DA_Utility.dbo.RegexMatch(AnnContent, '(?i)(director|directors)\s{0,3}.{0,50}(subscribe|participate)\s{0,3}.{0,80}Placement') as MatchText
		into #TempDirectorSubscribeSPP
		from StockData.Announcement as a
		left join #TempCashVsMC as b
		on a.ASXCode = b.ASXCode
		where DA_Utility.dbo.RegexMatch(AnnContent, '(?i)(director|directors)\s{0,3}.{0,50}(subscribe|participate)\s{0,3}.{0,80}Placement') is not null
		--and a.ASXCode = 'AUT.AX'
		order by a.AnnDateTime desc;		

		delete a
		from StockData.DirectorSubscribeSPP as a

		dbcc checkident('StockData.DirectorSubscribeSPP', reseed, 1);

		insert into [StockData].[DirectorSubscribeSPP]
		(
			[ObservationDate],
			[ReportType],
			[ASXCode],
			[MarketDate],
			[AnnDescr],
			[AnnDateTime],
			[MC],
			[CashPosition],
			[MatchText]
		)
		select
			[ObservationDate],
			[ReportType],
			[ASXCode],
			[MarketDate],
			[AnnDescr],
			[AnnDateTime],
			[MC],
			[CashPosition],
			[MatchText]
		from #TempDirectorSubscribeSPP

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
