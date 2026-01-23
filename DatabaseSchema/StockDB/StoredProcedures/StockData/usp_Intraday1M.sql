-- Stored procedure: [StockData].[usp_Intraday1M]






CREATE PROCEDURE [StockData].[usp_Intraday1M]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchObservationDate date = '2050-12-12',
@pvchStockCode varchar(20)
AS
/******************************************************************************
File: usp_GetCourseOfSale.sql
Stored Procedure Name: usp_GetCourseOfSale
Overview
-----------------
usp_GetCourseOfSale

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
Date:		2020-06-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_Intraday1M'
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
		declare @dtEnqDate as date 
		if @pvchObservationDate = '2050-12-12'
		begin
			select @dtEnqDate = dateadd(day, 0, cast(getdate() as date))
		end
		else
		begin
			select @dtEnqDate = cast(@pvchObservationDate as date)	
		end

		if object_id(N'Tempdb.dbo.#TempIntraDay') is not null
			drop table #TempIntraDay

		select 
			a.TimeLabel, 
			b.*, row_number() over (order by TimeLabel asc) as RowNumber, 
			cast(null as decimal(20, 4)) as PrevClose,
			cast([Close] as decimal(20, 4)) as CumulativeClose,
			cast(null as decimal(20, 4)) as TodayOpen
		into #TempIntraDay
		from LookupRef.TimePeriod1Min as a
		left join StockData.PriceHistoryTimeFrame as b
		on dateadd(day, datediff(day, a.TimeStart, b.ObservationDate), a.TimeStart) = b.TimeIntervalStart
		and TimeFrame = '1M'
		and ASXCode = @pvchStockCode
		and ObservationDate = @dtEnqDate
		order by a.TimeLabel

		if object_id(N'Tempdb.dbo.#TempPrevClose') is not null
			drop table #TempPrevClose

		select top 1 *
		into #TempPrevClose
		from StockData.PriceHistory
		where ASXCode = @pvchStockCode
		and dateadd(day, -90, @dtEnqDate) < ObservationDate
		and ObservationDate < @dtEnqDate
		order by ObservationDate desc

		update a
		set a.[PrevClose] = b.[Close]
		from #TempIntraDay as a
		inner join #TempPrevClose as b
		on 1 = 1

		declare @intIsUpdate as int = 1

		while @intIsUpdate > 0
		begin
			select @intIsUpdate = 0

			update a
			set 
				a.CumulativeClose = b.CumulativeClose
			from #TempIntraDay as a
			inner join #TempIntraDay as b
			on a.RowNumber = b.RowNumber + 1
			where a.CumulativeClose is null
			and b.CumulativeClose is not null

			select @intIsUpdate = @intIsUpdate + @@ROWCOUNT

			update a
			set a.VWAP = b.VWAP
			from #TempIntraDay as a
			inner join #TempIntraDay as b
			on a.RowNumber = b.RowNumber + 1
			where nullif(a.VWAP, 0) is null
			and nullif(b.VWAP, 0) is not null

			select @intIsUpdate = @intIsUpdate + @@ROWCOUNT
		end

		update a
		set 
			ASXCode = @pvchStockCode,
			TimeFrame = '1M',
			[Open] = 0,
			[High] = 0,
			[Low] = 0,
			[Close] = 0,
			[Volume] = 0,
			SaleValue = 0,
			NumOfSale = 0
		from #TempIntraDay as a
		where TimeFrame is null

		delete a
		from #TempIntraDay as a
		where CumulativeClose is null

		update a
		set 
			TodayOpen = (select [Open] from #TempIntraDay where [Open] > 0 and RowNumber = (select min(RowNumber) from #TempIntraDay))
		from #TempIntraDay as a

		select 
			right(convert(varchar(50), TimeLabel, 120), 8) as TimeLabel,
			ASXCode,
			TimeFrame,
			[Close],
			[Open],
			[TodayOpen],
			[CumulativeClose],
			[PrevClose],
			Volume,
			SaleValue,
			VWAP,
			ObservationDate,
			RowNumber
		from #TempIntraDay
		order by TimeLabel


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