-- Stored procedure: [Transform].[usp_RefresTransformStockPreMarketMatchVolume]



CREATE PROCEDURE [Transform].[usp_RefresTransformStockPreMarketMatchVolume]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefresTransformStockPreMarketMatchVolume.sql
Stored Procedure Name: usp_RefresTransformStockPreMarketMatchVolume
Overview
-----------------
usp_RefresTransformStockPreMarketMatchVolume

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
Date:		2022-05-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefresTransformStockPreMarketMatchVolume'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Transform'
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
		if object_id(N'Tempdb.dbo.#TempPriceSummaryMatchVolume') is not null
			drop table #TempPriceSummaryMatchVolume

		select *
		into #TempPriceSummaryMatchVolume
		from [StockData].[v_PriceSummary_MatchVolume]

		if object_id(N'Tempdb.dbo.#TempMatchVolume') is not null
			drop table #TempMatchVolume

		select 
			a.ASXCode,
			a.ObservationDate, 
			cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as MatchVolumeOutOfFreeFloat, 
			a.MatchVolume, 
			b.FloatingShares,
			a.IndicativePrice, 
			a.[Close] as PrevClose,
			cast(a.MatchVolume*a.IndicativePrice as int) as MatchValue,
			cast(case when a.PrevClose > 0 and a.IndicativePrice > 0 then (a.IndicativePrice - a.PrevClose)*100.0/a.PrevClose else null end as decimal(10, 2)) as MatchPriceIncrease,
			cast(case when a.PrevClose > 0 and c.[Open] > 0 then (c.[Open] - a.PrevClose)*100.0/a.PrevClose else null end as decimal(10, 2)) as OpenIncrease,
			cast(case when a.PrevClose > 0 and c.[Close] > 0 then (c.[Close] - a.PrevClose)*100.0/a.PrevClose else null end as decimal(10, 2)) as CloseIncrease,
			cast(case when a.PrevClose > 0 and c.[High] > 0 then (c.[High] - a.PrevClose)*100.0/a.PrevClose else null end as decimal(10, 2)) as HighIncrease,
			cast(case when a.PrevClose > 0 and c.[Low] > 0 then (c.[Low] - a.PrevClose)*100.0/a.PrevClose else null end as decimal(10, 2)) as LowIncrease
		into #TempMatchVolume
		from #TempPriceSummaryMatchVolume as a
		inner join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode
		left join [StockData].[v_PriceSummary_Latest] as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and c.Volume > 0
		where 1 = 1 
		order by ObservationDate desc;

		insert into [Transform].[StockPreMarketMatchVolume]
		(
			ASXCode,
			[ObservationDate],
			[MatchVolumeOutOfFreeFloat],
			[MatchVolume],
			[FloatingShares],
			[IndicativePrice],
			[PrevClose],
			[MatchValue],
			[MatchPriceIncrease],
			[OpenIncrease],
			[CloseIncrease],
			[HighIncrease],
			[LowIncrease]
		)
		select 
			ASXCode,
			[ObservationDate],
			[MatchVolumeOutOfFreeFloat],
			[MatchVolume],
			[FloatingShares],
			[IndicativePrice],
			[PrevClose],
			[MatchValue],
			[MatchPriceIncrease],
			[OpenIncrease],
			[CloseIncrease],
			[HighIncrease],
			[LowIncrease]
		from #TempMatchVolume as a
		where not exists
		(
			select 1
			from [Transform].[StockPreMarketMatchVolume]
			where ASXCode = a.ASXCode
			and ObservationDate = a.ObservationDate
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
