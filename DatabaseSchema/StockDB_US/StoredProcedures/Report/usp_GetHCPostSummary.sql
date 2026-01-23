-- Stored procedure: [Report].[usp_GetHCPostSummary]


CREATE PROCEDURE [Report].[usp_GetHCPostSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchStockCode as varchar(10)
AS
/******************************************************************************
File: usp_GetSectorList.sql
Stored Procedure Name: usp_GetSectorList
Overview
-----------------
usp_GetHCPostSummary

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
Date:		2017-03-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetHCPostSummary'
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
		--declare @pvchStockCode as varchar(10) = 'AGY.AX'

		declare @dtStartDate as date
		declare @dtEndDate as date

		select 
			@dtStartDate = min(cast(PostDateTime as date)),
			@dtEndDate = max(cast(PostDateTime as date))
		FROM [HC].[HeadPost]
		where ASXCode = @pvchStockCode

		--select @dtStartDate, @dtEndDate

		if object_id(N'Tempdb.dbo.#TempPriceHistory') is not null
			drop table #TempPriceHistory

		select identity(int, 1, 1) as SeqNo, cast(null as decimal(10, 4)) as PreviousPrice, cast(null as decimal(10, 2)) as PriceIncrease, * 
		into #TempPriceHistory
		from LookupRef.CalendarDate as a
		left join StockData.PriceHistory as b
		on a.CalendarDate = b.ObservationDate
		and ASXCode = @pvchStockCode
		where 1 = 1
		and a.CalendarDate >= @dtStartDate
		and a.CalendarDate <= @dtEndDate
		order by a.CalendarDate

		declare @intRowCount as int = 1

		while @intRowCount > 0
		begin

			select @intRowCount = 1

			update a
			set a.ASXCode = b.ASXCode,
				a.ObservationDate = a.CalendarDate,
				a.[Close] = b.[Close],
				a.[Open] = b.[Open],
				a.Low = b.Low,
				a.High = b.High,
				a.Volume = b.Volume,
				a.Value = b.Value,
				a.Trades = b.Trades
			from #TempPriceHistory as a
			inner join #TempPriceHistory as b
			on a.SeqNo = b.SeqNo + 1
			and a.ASXCode is null
			and b.ASXCode is not null

			select @intRowCount = @@Rowcount

		end 

		update a
		set a.PreviousPrice = b.[Close]
		from #TempPriceHistory as a
		inner join #TempPriceHistory as b
		on a.SeqNo = b.SeqNo + 1
		
		update a
		set a.PriceIncrease = case when a.PreviousPrice > 0 then (a.[Close] - a.PreviousPrice)*100.0/a.PreviousPrice else 0 end 
		from #TempPriceHistory as a
		
		select 
			a.CalendarDate, 
			isnull(b.NumPost, 0) as NumPost, 
			avg(isnull(b.NumPost, 0)) OVER (ORDER BY a.CalendarDate ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) as MA3NumPost,
			avg(isnull(b.NumPost, 0)) OVER (ORDER BY a.CalendarDate ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as MA30NumPost,
			isnull(b.NumPoster, 0) as NumPoster, 
			isnull(d.NumPost, 0) as NumHeartPost, 
			isnull(d.NumPoster, 0) as NumHeartPoster, 
			c.[Close], 
			c.Volume,
			c.PriceIncrease
		from LookupRef.CalendarDate as a
		left join
		(
			select cast(PostDateTime as date) as CalendarDate, count(*) as NumPost, count(distinct Poster) as NumPoster
			FROM [HC].[HeadPost]
			where ASXCode = @pvchStockCode
			group by cast(PostDateTime as date)
		) as b
		on a.CalendarDate = b.CalendarDate
		left join
		(
			select cast(PostDateTime as date) as CalendarDate, count(*) as NumPost, count(distinct Poster) as NumPoster
			FROM [HC].[HeadPost]
			where ASXCode = @pvchStockCode
			and PosterIsHeart = 1
			group by cast(PostDateTime as date)
		) as d
		on a.CalendarDate = d.CalendarDate
		left join #TempPriceHistory as c
		on a.CalendarDate = c.ObservationDate
		where a.CalendarDate >= @dtStartDate
		and a.CalendarDate <= @dtEndDate
		order by a.CalendarDate desc		


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
