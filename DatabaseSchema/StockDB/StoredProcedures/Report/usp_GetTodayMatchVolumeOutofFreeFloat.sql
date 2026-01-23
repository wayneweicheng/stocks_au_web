-- Stored procedure: [Report].[usp_GetTodayMatchVolumeOutofFreeFloat]


CREATE PROCEDURE [Report].[usp_GetTodayMatchVolumeOutofFreeFloat]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetTodayMatchVolumeOutofFreeFloat.sql
Stored Procedure Name: usp_GetTodayMatchVolumeOutofFreeFloat
Overview
-----------------
usp_GetTodayMatchVolumeOutofFreeFloat

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
Date:		2021-10-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetTodayMatchVolumeOutofFreeFloat'
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
		declare @dtDate as date = getdate()

		if object_id(N'Tempdb.dbo.#TempPriceSummaryMatchVolume') is not null
			drop table #TempPriceSummaryMatchVolume

		select *
		into #TempPriceSummaryMatchVolume
		from [StockData].[v_PriceSummaryToday_MatchVolume]
		where ObservationDate = @dtDate

		if object_id(N'Tempdb.dbo.#TempPriceSummaryIndicativePrice') is not null
			drop table #TempPriceSummaryIndicativePrice

		select *
		into #TempPriceSummaryIndicativePrice
		from
		(
			select *, row_number() over (partition by ASXCode, ObservationDate order by DateFrom desc) as RowNumber
			from StockData.PriceSummaryToday with(nolock)
			where ObservationDate = @dtDate
			and MatchVolume > 0
			and Volume = 0
			and IndicativePrice > 0
		) as a
		where RowNumber = 1

		if object_id(N'Tempdb.dbo.#TempPriceSummaryHighOpen') is not null
			drop table #TempPriceSummaryHighOpen

		select distinct ASXCode, ObservationDate, [High], [Open]
		into #TempPriceSummaryHighOpen
		from StockData.PriceSummaryToday with(nolock)
		where DateTo is null
		and LatestForTheDay = 1
		and ObservationDate = @dtDate

		select 
			a.ASXCode, 
			a.DateFrom as ObservationDateTime,
			c.AnnDateTime,
			a1.IndicativePrice,
			case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end as PriceChange,
			a.PrevClose,
			a.MatchVolume as MatchVolume,
			cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) as IndicativeMatchValue,
			cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) as MatchVolumeOutOfFreeFloat, 
			cast(case when h.[Open] > 0 then (h.[High] - h.[Open])*100.0/h.[Open] else null end as decimal(20, 2)) as MaxPriceIncrease,
			c.AnnDescr, 
			ttsu.FriendlyNameList,
			d.CleansedMarketCap as MarketCap, 
			cast(e.MedianTradeValue as int) as MedianTradeValueWeekly, 
			cast(e.MedianTradeValueDaily as int) as MedianTradeValueDaily, 
			e.MedianPriceChangePerc,
			f.RelativePriceStrength,
			rp.ShortTermRetailParticipationRate,
			rp.MediumTermRetailParticipationRate
		from #TempPriceSummaryMatchVolume as a
		inner join #TempPriceSummaryIndicativePrice as a1
		on a.ASXCode = a1.ASXCode
		inner join StockData.v_CompanyFloatingShare as b
		on a.ASXCode = b.ASXCode
		left join 
		(
			select ASXCode, AnnDescr, AnnDateTime, cast(AnnDateTime as date) as ObservationDate, row_number() over (partition by ASXCode, cast(AnnDateTime as date) order by AnnDateTime asc) as RowNumber
			from StockData.Announcement with(nolock)
			where cast(AnnDateTime as time) < '10:10:00'
		) as c
		on a.ASXCode = c.ASXCode
		and a.ObservationDate = c.ObservationDate
		and c.RowNumber = 1
		left join StockData.CompanyInfo as d
		on a.ASXCode = d.ASXCode
		left join StockData.MedianTradeValue as e
		on a.ASXCode = e.ASXCode
		left join StockData.v_RelativePriceStrength as f
		on a.ASXCode = f.ASXCode
		left join #TempPriceSummaryHighOpen as h
		on a.ASXCode = h.ASXCode
		and a.ObservationDate = h.ObservationDate
		left join Transform.TTSymbolUser as ttsu
		on a.ASXCode = ttsu.ASXCode
		left join StockData.RetailParticipation as rp
		on a.ASXCode = rp.ASXCode
		where b.FloatingShares > 0
		--and a.ASXCode = 'FNP.AX'
		and a.MatchVolume > 0
		and (a1.IndicativePrice is null or cast(a.MatchVolume*a1.IndicativePrice/1000.0 as decimal(20, 2)) >= 50)
		--AND a.ASXCode = 'EM1.AX'
		and cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) > 0.2
		and case when a.PrevClose > 0 and a1.IndicativePrice > 0 then cast((a1.IndicativePrice - a.PrevClose)*100.0/a.PrevClose as decimal(10, 2)) else null end >= 5
		and a.PrevClose > 0.012
		order by cast(a.MatchVolume*1.0/(b.FloatingShares*10000) as decimal(20, 2)) desc, a.MatchVolume*1.0/b.FloatingShares*10000 desc

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
