-- Stored procedure: [HC].[usp_RefreshPosterSummary]

CREATE PROCEDURE [HC].[usp_RefreshPosterSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_GetCommonStock.sql
Stored Procedure Name: usp_GetCommonStock
Overview
-----------------
usp_IsQualityPoster

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshPosterSummary'
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
		if object_id(N'HC.PosterPerf') is not null
			drop table HC.PosterPerf

		select
			Poster,
			ASXCode,
			PostDateTime as StartTime,
			PriceAtPosting,
			cast(null as smalldatetime) as EndTime,
			cast(null as decimal(20, 4)) as StartPrice,
			cast(null as decimal(20, 4)) as EndPrice,
			cast(null as decimal(20, 4)) as ClosePrice,
			cast(null as decimal(20, 4)) as HighPrice,
			cast(null as decimal(20, 4)) as LowPrice,
			cast(null as decimal(10, 2)) as PercGain,
			cast(null as decimal(20, 4)) as OpenPosition,	
			cast(null as decimal(20, 4)) as ClosePosition,	
			cast(null as int) as Duration,
			cast(null as decimal(10, 2)) as PercGainPerYear
		into HC.PosterPerf
		from 
		(
		select 
			Poster,
			ASXCode,
			PostDateTime,
			PriceAtPosting,
			row_number() over (partition by Poster, ASXCode order by PostDateTime asc) as RowNumber
		from [HC].[PostRaw]
		where Sentiment in ('Buy', 'Hold', 'None')
		and Disclosure = 'Held'
		) as x
		where RowNumber = 1

		----UPDATE END PRICE WITH LAST BUY TIP PRICE
		--update a
		--set a.EndTime = b.PostDateTime,
		--	a.EndPrice = case when b.PriceAtPosting like '%c' then cast(replace(b.PriceAtPosting, 'c', '') as decimal(20, 4))
		--					  when b.PriceAtPosting like '$%' then 100*cast(replace(b.PriceAtPosting, '$', '') as decimal(20, 4))
		--					  else null
		--				 end	  	 	 
		--from HC.PosterPerf as a
		--inner join
		--(
		--select 
		--	Poster,
		--	ASXCode,
		--	PostDateTime,
		--	PriceAtPosting,
		--	row_number() over (partition by Poster, ASXCode order by PostDateTime desc) as RowNumber
		--from [HC].[PostRaw]
		--where Sentiment = 'Buy'
		--and Disclosure = 'Held'
		--) as b
		--on a.Poster = b.Poster
		--and a.ASXCode = b.ASXCode
		--and b.RowNumber = 1

		--UPDATE END PRICE WITH ONE MONTH HIGH
		if object_id(N'Tempdb.dbo.#TempHighPrice') is not null
			drop table #TempHighPrice

		select
			Poster, 
			ASXCode, 
			StartTime,
			ObservationDate,
			High
		into #TempHighPrice
		from
		(
			select 
				b.Poster, 
				a.ASXCode, 
				b.StartTime,
				a.ObservationDate,
				a.High,
				row_number() over (partition by b.Poster, a.ASXCode, b.StartTime order by a.High desc, a.[Close] desc, a.ObservationDate asc) as RowNumber
			from StockData.PriceHistory as a
			inner join HC.PosterPerf as b
			on a.ASXCode = b.ASXCode
			and a.ObservationDate > b.StartTime
			and a.ObservationDate <= dateadd(day, 30, b.StartTime)
		) as x
		where RowNumber = 1

		update a
		set a.EndPrice = 100.0*b.High,
			a.EndTime = b.ObservationDate
		from HC.PosterPerf as a
		inner join #TempHighPrice as b
		on a.Poster = b.Poster
		and a.ASXCode = b.ASXCode
		and a.StartTime = b.StartTime

		delete a
		from HC.PosterPerf as a
		where EndPrice is null

		update a
		set StartPrice = case when a.PriceAtPosting like '%c' then cast(replace(a.PriceAtPosting, 'c', '') as decimal(20, 4))
							  when a.PriceAtPosting like '$%' then 100*cast(replace(a.PriceAtPosting, '$', '') as decimal(20, 4))
							  else null
						 end
		from HC.PosterPerf as a

		delete a
		from HC.PosterPerf as a
		where isnull(StartPrice, 0) = 0

		delete a
		from HC.PosterPerf as a
		where EndPrice > 8*StartPrice

		update a
		set PercGain = (EndPrice - StartPrice)*100.0/StartPrice
		from HC.PosterPerf as a

		update a
		set Duration = datediff(day, StartTime, EndTime)
		from HC.PosterPerf as a

		delete a
		from HC.PosterPerf as a
		where Duration = 0

		update a
		set PercGainPerYear = PercGain*365.0/Duration
		from HC.PosterPerf as a

		if object_id(N'HC.PosterSummary') is not null
			drop table HC.PosterSummary

		select
			Poster,
			count(ASXCode) as NumStock,
			cast(10000 as decimal(20, 4)) as OpenBalance,
			cast(null as decimal(20, 4)) as InitialAmountPerStock,
			cast(null as decimal(20, 4)) as CloseBalance,
			cast(null as int) as TotalHeldDays,
			cast(null as int) as SuccessRate,
			cast(null as decimal(10, 2)) as OverallPerf
		into HC.PosterSummary
		from HC.PosterPerf
		group by Poster

		update a
		set InitialAmountPerStock = OpenBalance/NumStock
		from HC.PosterSummary as a

		update a
		set a.OpenPosition = b.InitialAmountPerStock
		from HC.PosterPerf as a
		inner join HC.PosterSummary as b
		on a.Poster = b.Poster

		update a
		set a.ClosePosition = a.OpenPosition*(1.0 + 0.01*PercGain)
		from HC.PosterPerf as a

			select
				a.Poster,
				sum(b.ClosePosition) as CloseBalance,
				sum(b.Duration) as TotalHeldDays,
				sum(case when PercGain > 10 then 1 else 0 end) as NumGain
			into #Temp
			from HC.PosterSummary as a
			inner join HC.PosterPerf as b
			on a.Poster = b.Poster
			group by a.Poster
		
		update x
		set x.CloseBalance = y.CloseBalance,
			x.TotalHeldDays = y.TotalHeldDays/NumStock,
			x.SuccessRate = y.NumGain*100.0/x.NumStock,
			x.OverallPerf = (y.CloseBalance - x.OpenBalance)*365*100/(x.OpenBalance*(y.TotalHeldDays/x.NumStock))
		from HC.PosterSummary as x
		inner join
		(
			select
				a.Poster,
				sum(b.ClosePosition) as CloseBalance,
				sum(b.Duration) as TotalHeldDays,
				sum(case when PercGain > 10 then 1 else 0 end) as NumGain
			from HC.PosterSummary as a
			inner join HC.PosterPerf as b
			on a.Poster = b.Poster
			group by a.Poster
		) as y
		on x.Poster = y.Poster

		
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
