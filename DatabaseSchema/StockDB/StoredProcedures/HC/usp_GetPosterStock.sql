-- Stored procedure: [HC].[usp_GetPosterStock]

CREATE PROCEDURE [HC].[usp_GetPosterStock]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintNumDay int = 60,
@pintMaxQualityPosterRating int = 25
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
		from
		(				
			select
				PostRawID,
				ASXCode,
				Poster,
				PostDateTime,
				PosterIsHeart,
				QualityPosterRating,
				Sentiment,
				Disclosure,
				row_number() over (partition by ASXCode, Poster order by PostDateTime desc) as RowNumber
			from HC.PostRaw
		) as a
		where a.RowNumber = 1

		update a
		set a.QualityPosterRating = case when b.Poster is not null then b.Rating else case when a.PosterIsHeart = 1 then 20 else null end end
		from #TempPostRaw as a
		left join HC.QualityPoster as b
		on a.Poster = b.Poster

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

		if object_id(N'Tempdb.dbo.#TempCashVsMC') is not null
			drop table #TempCashVsMC

		select cast((a.CashPosition/1000.0)/(b.CleansedMarketCap * 1.0) as decimal(10, 3)) as CashVsMC, (a.CashPosition/1000.0) as CashPosition, (b.CleansedMarketCap * 1.0) as MC, b.ASXCode
		into #TempCashVsMC
		from #TempCashPosition as a
		right join StockData.StockOverviewCurrent as b
		on a.ASXCode = b.ASXCode
		and b.DateTo is null
		--and a.CashPosition/1000 * 1.0/(b.CleansedMarketCap * 1) >  0.5
		--and a.CashPosition/1000.0 > 1
		order by a.CashPosition/1000.0 * 1.0/(b.CleansedMarketCap * 1) desc

		if object_id(N'Tempdb.dbo.#TempStockNature') is not null
			drop table #TempStockNature

		select a.ASXCode, stuff((
			select ',' + Token
			from StockData.StockNature
			where ASXCode = a.ASXCode
			order by AnnCount desc
			for xml path('')), 1, 1, ''
		) as Nature
		into #TempStockNature
		from StockData.StockNature as a
		group by a.ASXCode

		select 
			left(a.Poster, 20) as Poster,
			left(a.ASXCode, 7) as ASXCode,
			convert(varchar(30), a.PostDateTime, 126) as PostDateTime,
			left(a.Sentiment, 10) as Sentiment,
			left(a.Disclosure, 10) as Disclosure,
			cast(c.MC as decimal(8, 2)) as MC,
			cast(c.CashPosition as decimal(8, 2)) CashPosition,
			cast(d.Nature as varchar(100)) as Nature
		from #TempPostRaw as a
		left join #TempCashVsMC as c
		on a.ASXCode = c.ASXCode
		left join #TempStockNature as d
		on a.ASXCode = d.ASXCode
		where QualityPosterRating < @pintMaxQualityPosterRating
		and datediff(day, PostDateTime, getdate()) < @pintNumDay
		and (Disclosure = 'Held' or Sentiment = 'Buy' or Poster in ('Shinji Ono'))
		order by Poster, a.PostDateTime desc,a.ASXCode	
		
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
