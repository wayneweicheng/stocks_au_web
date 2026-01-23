-- Stored procedure: [HC].[usp_GetIncreasedMonthlyVisit]


--exec [HC].[usp_GetIncreasedMonthlyVisit]
--@pintMVIncreasePerc = 50,
--@pintPriceRangeStartPerc = 90,
--@pintPriceRangeEndPerc = 120,
--@pintNumDaysStart = 1,
--@pintNumDaysEnd = 20


CREATE PROCEDURE [HC].[usp_GetIncreasedMonthlyVisit]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintMVIncreasePerc int = 50,
@pintPriceRangeStartPerc int = 90,
@pintPriceRangeEndPerc int = 120,
@pintNumDaysStart int = 10,
@pintNumDaysEnd int = 20
AS
/******************************************************************************
File: usp_GetPosterStock.sql
Stored Procedure Name: usp_GetPosterStock
Overview
-----------------
usp_GetPosterStock

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
Date:		2017-09-17
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_GetPosterStock'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'HC'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		select 
					a.ASXCode,
					dateadd(day, -1, cast(DateFrom as date)) as ObservationDate, 
					--replace(MonthlyVisit, ',', ''),
					try_cast(replace(MonthlyVisit, ',', '') as decimal(20, 2))/30 as MA30MonthlyVisit,
					--replace(MonthlyVisit, ',', '')/30.0, 
					CleansedMarketCap,
					b.[close],
					b.[Value]
		INTO #Temp
			from [HC].[StockOverview] as a
			left join StockData.PriceHistory as b
			on a.ASXCode = b.ASXCode
			and dateadd(day, -1, cast(a.DateFrom as date)) = b.ObservationDate
			where 1 = 1
			--and try_cast(replace(MonthlyVisit, ',', '') as decimal(20, 2)) is null
			order by DateFrom desc

		select 
			a.*,
			b.ObservationDate as ObservationDate_B,
			b.MA30MonthlyVisit as MA30MonthlyVisit_B,
			b.CleansedMarketCap as CleansedMarketCap_B,
			row_number() over (partition by a.ASXCode order by a.ObservationDate asc) as RowNumber
		into #Temp2
		from #Temp as a
		inner join #Temp as b
		on a.ASXCode = b.ASXCode
		and datediff(day, a.ObservationDate, b.ObservationDate) between @pintNumDaysStart and @pintNumDaysEnd
		and a.MA30MonthlyVisit*(1 + @pintMVIncreasePerc/100.0) < b.MA30MonthlyVisit
		and a.CleansedMarketCap between b.CleansedMarketCap*@pintPriceRangeStartPerc/100.0 and b.CleansedMarketCap*@pintPriceRangeEndPerc/100.0
		and a.MA30MonthlyVisit > 10

		if object_id(N'Tempdb.dbo.#TempPostRaw') is not null
			drop table #TempPostRaw

		select
			PostRawID,
			ASXCode,
			Poster,
			PostDateTime,
			PosterIsHeart,
			QualityPosterRating,
			Sentiment,
			Disclosure
		into #TempPostRaw
		from HC.TempPostLatest

		if object_id(N'Tempdb.dbo.#TempPoster') is not null
			drop table #TempPoster

		select x.ASXCode, stuff((
			select ',' + [Poster]
			from #TempPostRaw as a
			where x.ASXCode = a.ASXCode
			and (Sentiment in ('Buy') or Disclosure in ('Held'))
			and datediff(day, PostDateTime, getdate()) <= 60
			and exists
			(
				select 1
				from StockData.PriceHistoryCurrent
				where ASXCode = a.ASXCode
			)
			order by PostDateTime desc, isnull(QualityPosterRating, 200) asc
			for xml path('')), 1, 1, ''
		) as [Poster]
		into #TempPoster
		from #TempPostRaw as x
		where (Sentiment in ('Buy') or Disclosure in ('Held'))
		and datediff(day, PostDateTime, getdate()) <= 60
		and exists
		(
			select 1
			from StockData.PriceHistoryCurrent
			where ASXCode = x.ASXCode
		)
		group by x.ASXCode

		select *
		from #Temp2 as a
		left join #TempPoster as b
		on a.ASXCode = b.ASXCode
		where RowNumber = 1
		
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
