-- Stored procedure: [Report].[usp_GetQualityHCPost]


--exec [StockData].[usp_GetLargetSale]
--@intNumPrevDay = 7


CREATE PROCEDURE [Report].[usp_GetQualityHCPost]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetQualityHCPost.sql
Stored Procedure Name: usp_GetQualityHCPost
Overview
-----------------
usp_GetQualityHCPost

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
Date:		2018-08-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetQualityHCPost'
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
		declare @pintNumPrevDay as int = 0

		declare @dtDate as date = cast(Common.DateAddBusinessDay(-1 * @pintNumPrevDay, getdate()) as date)

		declare @dtMaxHistory as date
		select @dtMaxHistory = max(ObservationDate) from StockData.PriceHistoryCurrent

		;with TodayTrade as
		(
		select 
			ASXCode, 
			cast(DateFrom as date) as CurrentDate,
			isnull(BuySellInd, 'U') as BuySellInd, 
			sum(case when ValueDelta > 0 then ValueDelta else 0 end) as TradeValue,
			sum(case when VolumeDelta > 0 then VolumeDelta else 0 end) as TradeVolume,
			avg(VWAP)*100.0 as VWAP 
		from StockData.PriceSummary
		where cast(DateFrom as date) = @dtDate
		and VWAP > 0
		group by ASXCode, cast(DateFrom as date), BuySellInd
		),
		
		Announcement as
		(
		select 
			AnnouncementID,
			ASXCode,
			AnnDescr,
			AnnDateTime,
			stuff((
			select ',' + [SearchTerm]
			from StockData.AnnouncementAlert as a
			where x.AnnouncementID = a.AnnouncementID
			order by CreateDate desc
			for xml path('')), 1, 1, ''
			) as [SearchTerm]
		from StockData.Announcement as x
		where cast(AnnDateTime as date) = @dtDate
		)

		select 
			a.Poster, 
			b.ASXCode, 
			b.PostDateTime, 
			b.PostUrl, 
			b.PriceAtPosting, 
			b.Sentiment, 
			b.Disclosure, 
			a.Rating,
			c.MC,
			c.CashPosition,
			d.Poster as PosterList,
			f.AnnDescr,
			e.Nature,
			h.[Close] as LastClose,
			row_number() over (order by cast(b.PostDateTime as date) desc, a.Rating asc, b.PostDateTime desc) as RankOverall
		from HC.QualityPoster as a
		inner join HC.PostRaw as b
		on a.Poster = b.Poster
		and datediff(day, b.PostDateTime, getdate()) < 3
		left join Transform.CashVsMC as c
		on b.ASXCode = c.ASXCode
		left join Transform.PosterList as d
		on b.ASXCode = d.ASXCode
		left join Transform.TempStockNature as e
		on b.ASXCode = e.ASXCode
		left join Announcement as f
		on b.ASXCode = f.ASXCode
		left join StockData.StockStatsHistoryPlusCurrent as g
		on b.ASXCode = g.ASXCode
		left join StockData.PriceHistoryCurrent as h
		on b.ASXCode = h.ASXCode
		where 1 = 1
		order by cast(b.PostDateTime as date) desc, a.Rating asc, b.PostDateTime desc

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
