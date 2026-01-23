-- Stored procedure: [StockData].[usp_GetTradingHalt]






CREATE PROCEDURE [StockData].[usp_GetTradingHalt]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetTradingHalt.sql
Stored Procedure Name: usp_GetTradingHalt
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTradingHalt'
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
		select top 500
			identity(int, 1, 1) as UniqueKey,
			ASXCode,
			AnnDescr,
			AnnDateTime,
			--AnnContent,
			coalesce(
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=makes\s{0,3}an\s{0,3}announcement.{0,30}market.{0,80}to).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=reason\s{0,3}for\s{0,3}the\s{0,3}request\s{0,3}.{0,80}announcement).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=announcement.{0,30}market.{0,80}(involving|regarding)).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=pending.{0,50}announcement.{0,80}(relating to|involving|regarding|concerning|of)).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=announcement.{0,30}(|market|asx).{0,80}in\s{0,3}relation\s{0,3}to\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=announcement.{0,30}(|market|asx).{0,80}in\s{0,3}connection\s{0,3}with\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=announcement.{0,30}with\s{0,3}regard\s{0,3}to\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=into.{0,30}trading\s{0,3}halt\s{0,3}pending\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=pending.{0,30}announcement\s{0,3}on\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=(pending|regarding|).{0,30}announcement\s{0,3}(on|regarding)\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=(pending|regarding|).{0,30}the\s{0,3}release\s{0,3}(of|on|regarding)\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=(pending|regarding|).{0,30}an\s{0,3}announcement.{0,30}in\s{0,30}connection\s{0,30}to\s{0,3}).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=reason\s{0,3}for\s{0,3}the\s{0,3}trading\s{0,3}halt\s{0,3}request\s{0,3}.is).{0,80}'),
			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=trading\s{0,3}halt\s{0,3}to\s{0,3}provide).{0,80}'),

			DA_Utility.dbo.RegexMatch(AnnContent, '(?<=trading\s{0,3}halt\s{0,3}to\s{0,3}provide).{0,80}'),
			null) as TradingHaltReason
		into #TempStockAnn
		from StockData.Announcement as a
		where AnnDescr like '%Trading halt%'
		order by AnnDateTime desc

		select a.ASXCode, a.UniqueKey, min(b.ObservationDate) as NextObservationDate
		into #TempStockNextDate
		from #TempStockAnn as a
		inner join StockData.StockStatsHistoryPlus as b
		on a.ASXCode = b.ASXCode
		and cast(a.AnnDateTime as date) < b.ObservationDate
		and b.Volume > 1
		group by a.ASXCode, a.UniqueKey

		select 
			a.*, c.ObservationDate, 
			case when c.PrevClose = 0 then null else cast((c.[Close] - c.PrevClose)*100.0/c.PrevClose as decimal(10,2)) end as PriceChangeClose,
			case when c.PrevClose = 0 then null else cast((c.[Open] - c.PrevClose)*100.0/c.PrevClose as decimal(10,2)) end as PriceChangeOpen,
			case when c.PrevClose = 0 then null else cast((c.[High] - c.PrevClose)*100.0/c.PrevClose as decimal(10,2)) end as PriceChangeHigh,
			case when c.PrevClose = 0 then null else cast((c.[Low] - c.PrevClose)*100.0/c.PrevClose as decimal(10,2)) end as PriceChangeLow,
			cast(c.Volume*c.[Close] as decimal(20, 2)) as TradeValue,
			cast(case when c.MovingAverage120dVol > 0 then c.Volume*100.0/c.MovingAverage120dVol else null end as decimal(20, 2)) as VolumeIndex
		from #TempStockAnn as a
		left join #TempStockNextDate as b
		on a.ASXCode = b.ASXCode
		and a.UniqueKey = b.UniqueKey
		left join StockData.StockStatsHistoryPlus as c
		on b.ASXCode = c.ASXCode
		and b.NextObservationDate = c.ObservationDate
		order by a.AnnDateTime desc

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
